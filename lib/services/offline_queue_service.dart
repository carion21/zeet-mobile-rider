// lib/services/offline_queue_service.dart
//
// Queue offline + worker de synchronisation pour les actions critiques
// rider (accept/reject/collect/deliver/notDelivered). Skill source :
// `zeet-offline-first` §5 (Sync Queue) et §6 (Optimistic UI).
//
// Architecture :
// - Queue persistée en SharedPreferences (clé `rider_offline_queue_v1`)
//   sous forme de JSON list. Volume cible faible (< 100 actions max).
// - Stream broadcast émet la liste à chaque mutation pour alimenter
//   l'UI (banner "X actions en attente", écran de la queue).
// - Worker `sync()` réentrant (lock interne) qui itère les actions
//   `pending`, applique le backoff, exécute via `MissionService`, met
//   à jour le statut.
// - Backoff exponentiel : 1, 2, 4, 8, 16, 30, 60s (cap).
// - Dead letter après 10 échecs (status `failed`, ne retente plus auto).

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rider/models/queued_action.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/mission_service.dart';

class OfflineQueueService {
  OfflineQueueService._();

  static final OfflineQueueService instance = OfflineQueueService._();

  static const String _kStorageKey = 'rider_offline_queue_v1';
  static const int _kMaxAttempts = 10;

  final StreamController<List<QueuedAction>> _controller =
      StreamController<List<QueuedAction>>.broadcast();
  final List<QueuedAction> _cache = <QueuedAction>[];

  final MissionService _missionService = MissionService();

  bool _initialized = false;
  bool _syncing = false;
  int _seq = 0;

  // ─── Lifecycle ────────────────────────────────────────────────────

  /// Charge la queue persistée. Idempotent. À appeler une fois au boot
  /// (avant `runApp`).
  Future<void> init() async {
    if (_initialized) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is List) {
          _cache.clear();
          for (final dynamic e in decoded) {
            if (e is Map<String, dynamic>) {
              try {
                _cache.add(QueuedAction.fromJson(e));
              } catch (err) {
                debugPrint('[OfflineQueue] skip invalid entry: $err');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OfflineQueue] init error: $e');
    }
    _initialized = true;
    _emit();
  }

  // ─── Reads ────────────────────────────────────────────────────────

  /// Stream broadcast de l'ensemble de la queue (toutes statuts).
  Stream<List<QueuedAction>> get stream => _controller.stream;

  /// Snapshot immédiat.
  List<QueuedAction> get all => List<QueuedAction>.unmodifiable(_cache);

  /// Sous-ensemble `pending` (à retenter).
  List<QueuedAction> get pending => _cache
      .where((QueuedAction a) => a.status == QueuedActionStatus.pending)
      .toList(growable: false);

  /// Sous-ensemble `failed` (dead letter).
  List<QueuedAction> get failed => _cache
      .where((QueuedAction a) => a.status == QueuedActionStatus.failed)
      .toList(growable: false);

  // ─── Mutations ────────────────────────────────────────────────────

  /// Construit et insère une action. Émet immédiatement le stream.
  /// Le caller peut ensuite déclencher [sync] s'il sait être online.
  Future<QueuedAction> enqueue({
    required QueuedActionType type,
    required String missionId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final QueuedAction action = QueuedAction(
      id: _newId(),
      type: type,
      missionId: missionId,
      payload: payload,
      enqueuedAt: DateTime.now(),
    );
    // Coalesce : si déjà une action `pending` du même type/missionId,
    // on remplace son payload (la dernière intention gagne).
    final int existing = _cache.indexWhere((QueuedAction a) =>
        a.type == type &&
        a.missionId == missionId &&
        a.status != QueuedActionStatus.failed);
    if (existing >= 0) {
      _cache[existing] = action;
    } else {
      _cache.add(action);
    }
    await _persist();
    _emit();
    return action;
  }

  /// Retire une action de la queue (quel que soit son statut).
  Future<void> remove(String id) async {
    _cache.removeWhere((QueuedAction a) => a.id == id);
    await _persist();
    _emit();
  }

  /// Vide les actions en `failed` (dead letter cleanup utilisateur).
  Future<void> clearFailed() async {
    _cache.removeWhere(
        (QueuedAction a) => a.status == QueuedActionStatus.failed);
    await _persist();
    _emit();
  }

  /// Repasse les actions `failed` en `pending` pour les rejouer.
  Future<void> retryFailed() async {
    for (int i = 0; i < _cache.length; i++) {
      if (_cache[i].status == QueuedActionStatus.failed) {
        _cache[i] = _cache[i].copyWith(
          status: QueuedActionStatus.pending,
          attempts: 0,
          lastAttemptAt: null,
          clearLastError: true,
        );
      }
    }
    await _persist();
    _emit();
  }

  // ─── Worker ───────────────────────────────────────────────────────

  /// Synchronise les actions `pending` avec le serveur. Réentrant : si
  /// déjà en cours, retourne immédiatement. Respecte le backoff par
  /// action (skip si pas encore l'heure de retenter).
  Future<void> sync() async {
    if (!_initialized) await init();
    if (_syncing) return;
    _syncing = true;
    try {
      final List<QueuedAction> snapshot =
          List<QueuedAction>.from(pending, growable: false);
      for (final QueuedAction action in snapshot) {
        if (!_isReady(action)) continue;
        await _attempt(action);
      }
    } finally {
      _syncing = false;
    }
  }

  bool _isReady(QueuedAction a) {
    if (a.lastAttemptAt == null) return true;
    final Duration wait = _backoff(a.attempts);
    return DateTime.now().difference(a.lastAttemptAt!) >= wait;
  }

  Future<void> _attempt(QueuedAction action) async {
    // Lock optimiste
    _replace(action.copyWith(status: QueuedActionStatus.syncing));
    _emit();

    try {
      await _execute(action);
      // Succès → retire de la queue.
      _cache.removeWhere((QueuedAction a) => a.id == action.id);
      await _persist();
      _emit();
    } on ApiException catch (e) {
      // Erreur API : si 4xx ≠ 408/409/429, c'est probablement permanent
      // (validation, état serveur incompatible). On marque failed
      // immédiatement pour ne pas spammer.
      final bool transient = _isTransient(e.statusCode);
      final QueuedAction updated = action.copyWith(
        status: transient && action.attempts + 1 < _kMaxAttempts
            ? QueuedActionStatus.pending
            : QueuedActionStatus.failed,
        attempts: action.attempts + 1,
        lastAttemptAt: DateTime.now(),
        lastError: e.message,
      );
      _replace(updated);
      await _persist();
      _emit();
    } catch (e) {
      // Erreur réseau / parsing : transient.
      final QueuedAction updated = action.copyWith(
        status: action.attempts + 1 >= _kMaxAttempts
            ? QueuedActionStatus.failed
            : QueuedActionStatus.pending,
        attempts: action.attempts + 1,
        lastAttemptAt: DateTime.now(),
        lastError: e.toString(),
      );
      _replace(updated);
      await _persist();
      _emit();
    }
  }

  Future<void> _execute(QueuedAction a) async {
    switch (a.type) {
      case QueuedActionType.acceptMission:
        await _missionService.acceptMission(a.missionId);
        break;
      case QueuedActionType.rejectMission:
        await _missionService.rejectMission(
          a.missionId,
          reason: (a.payload['reason'] as String?) ?? '',
        );
        break;
      case QueuedActionType.collectMission:
        await _missionService.collectMission(
          a.missionId,
          otpCode: (a.payload['otp_code'] as String?) ?? '',
        );
        break;
      case QueuedActionType.deliverMission:
        await _missionService.deliverMission(
          a.missionId,
          otpCode: (a.payload['otp_code'] as String?) ?? '',
        );
        break;
      case QueuedActionType.markNotDelivered:
        await _missionService.notDelivered(
          a.missionId,
          reason: (a.payload['reason'] as String?) ?? '',
          geoLat: a.payload['geo_lat'] as String?,
          geoLng: a.payload['geo_lng'] as String?,
        );
        break;
    }
  }

  bool _isTransient(int? code) {
    if (code == null) return true; // pas de code = network → transient
    if (code >= 500) return true;
    if (code == 408 || code == 409 || code == 425 || code == 429) return true;
    return false;
  }

  Duration _backoff(int attempts) {
    // 1, 2, 4, 8, 16, 32, 60s (cap)
    final int seconds = math.min(60, math.pow(2, attempts).toInt());
    return Duration(seconds: seconds);
  }

  // ─── Internals ────────────────────────────────────────────────────

  void _replace(QueuedAction updated) {
    final int idx = _cache.indexWhere((QueuedAction a) => a.id == updated.id);
    if (idx >= 0) _cache[idx] = updated;
  }

  String _newId() {
    final int micros = DateTime.now().microsecondsSinceEpoch;
    _seq = (_seq + 1) & 0xFFFF;
    return '$micros-$_seq';
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _cache.map((QueuedAction a) => a.toJson()).toList(growable: false),
      );
      await prefs.setString(_kStorageKey, encoded);
    } catch (e) {
      debugPrint('[OfflineQueue] persist error: $e');
    }
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List<QueuedAction>.unmodifiable(_cache));
    }
  }

  /// Pour tests / hot reload.
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}
