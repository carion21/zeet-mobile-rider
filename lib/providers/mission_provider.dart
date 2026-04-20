import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/models/queued_action.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/location_tracking_service.dart';
import 'package:rider/services/mission_local_cache.dart';
import 'package:rider/services/mission_service.dart';
import 'package:rider/services/offline_queue_service.dart';

// ---------------------------------------------------------------------------
// Service Provider
// ---------------------------------------------------------------------------
final missionServiceProvider = Provider<MissionService>((ref) {
  return MissionService();
});

// ---------------------------------------------------------------------------
// Missions List State
// ---------------------------------------------------------------------------
class MissionsListState {
  final List<Mission> missions;
  final bool isLoading;
  final String? errorMessage;

  const MissionsListState({
    this.missions = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  MissionsListState copyWith({
    List<Mission>? missions,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MissionsListState(
      missions: missions ?? this.missions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Missions disponibles (pas encore acceptees).
  List<Mission> get available =>
      missions.where((m) => m.status == 'assigned' || m.status == 'pending').toList();

  /// Missions en cours (acceptees, en collecte, en livraison).
  List<Mission> get ongoing => missions
      .where((m) =>
          m.status == 'accepted' ||
          m.status == 'collecting' ||
          m.status == 'collected' ||
          m.status == 'delivering' ||
          m.status == 'picked_up')
      .toList();

  /// Missions terminees (livrees, non-livrees, annulees).
  List<Mission> get completed => missions
      .where((m) =>
          m.status == 'delivered' ||
          m.status == 'not_delivered' ||
          m.status == 'not-delivered' ||
          m.status == 'cancelled' ||
          m.status == 'canceled')
      .toList();
}

// ---------------------------------------------------------------------------
// Missions List Notifier
// ---------------------------------------------------------------------------
class MissionsListNotifier extends StateNotifier<MissionsListState> {
  final MissionService _missionService;

  MissionsListNotifier(this._missionService) : super(const MissionsListState());

  /// Charge la liste des missions.
  /// Pattern offline-first : hydrate immédiatement depuis le cache local
  /// si state vide, puis tente l'API et persiste le résultat. En cas
  /// d'échec API, le cache reste affiché (skill `zeet-offline-first` §10).
  Future<void> load() async {
    // Hydrate cache si on n'a rien (évite l'écran vide en zone blanche).
    if (state.missions.isEmpty) {
      final List<Map<String, dynamic>> cached =
          await MissionLocalCache.instance.loadListRaw();
      if (cached.isNotEmpty) {
        try {
          final List<Mission> hydrated =
              cached.map((e) => Mission.fromJson(e)).toList();
          state = state.copyWith(missions: hydrated);
        } catch (_) {/* cache corrompu : on ignore, fresh load suit */}
      }
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _missionService.listMissions();
      final dataRaw = response['data'];

      List<Map<String, dynamic>> rawItems = const <Map<String, dynamic>>[];
      if (dataRaw is List) {
        rawItems = dataRaw.whereType<Map<String, dynamic>>().toList();
      } else if (dataRaw is Map<String, dynamic> && dataRaw['items'] is List) {
        rawItems = (dataRaw['items'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      final List<Mission> missions =
          rawItems.map((e) => Mission.fromJson(e)).toList();

      state = state.copyWith(missions: missions, isLoading: false);

      // Persist en arrière-plan (best-effort).
      unawaited(MissionLocalCache.instance.saveListRaw(rawItems));
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      // Si on a déjà du cache visible, ne pas écraser avec erreur bloquante.
      state = state.copyWith(
        isLoading: false,
        errorMessage: state.missions.isEmpty
            ? 'Impossible de charger les missions'
            : null,
      );
    }
  }

  /// Rafraichit la liste des missions.
  Future<void> refresh() => load();

  /// Met a jour le statut d'une mission localement (apres une action).
  /// Re-persiste le cache pour que le cold-start ne reaffiche pas un statut
  /// perime (skill `zeet-offline-first` §10).
  void updateMissionStatus(int missionId, String newStatus) {
    final updated = state.missions.map((m) {
      if (m.id == missionId) {
        return m.copyWith(status: newStatus);
      }
      return m;
    }).toList();
    state = state.copyWith(missions: updated);
    _persistCache();
  }

  /// Supprime une mission de la liste locale (apres reject par ex.).
  void removeMission(int missionId) {
    final updated = state.missions.where((m) => m.id != missionId).toList();
    state = state.copyWith(missions: updated);
    _persistCache();
  }

  /// Re-serialise la liste actuelle dans le cache local. Best-effort,
  /// ne bloque pas l'UI.
  void _persistCache() {
    final List<Map<String, dynamic>> raw = state.missions
        .map((m) => <String, dynamic>{
              'id': m.id,
              'status': m.status,
              // Champs minimum pour reconstituer la liste au cold-start.
              // La sync API rapatrie les details exhaustifs au prochain load().
              'order_reference': m.orderReference,
              'distance': m.distance,
            })
        .toList(growable: false);
    unawaited(MissionLocalCache.instance.saveListRaw(raw));
  }
}

// ---------------------------------------------------------------------------
// Mission Detail State
// ---------------------------------------------------------------------------
class MissionDetailState {
  final Mission? mission;
  final bool isLoading;
  final bool isActionLoading;
  final String? errorMessage;
  final String? actionError;

  const MissionDetailState({
    this.mission,
    this.isLoading = false,
    this.isActionLoading = false,
    this.errorMessage,
    this.actionError,
  });

  MissionDetailState copyWith({
    Mission? mission,
    bool? isLoading,
    bool? isActionLoading,
    String? errorMessage,
    String? actionError,
    bool clearMission = false,
    bool clearError = false,
    bool clearActionError = false,
  }) {
    return MissionDetailState(
      mission: clearMission ? null : (mission ?? this.mission),
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}

// ---------------------------------------------------------------------------
// Mission Detail Notifier
// ---------------------------------------------------------------------------
class MissionDetailNotifier extends StateNotifier<MissionDetailState> {
  final MissionService _missionService;

  MissionDetailNotifier(this._missionService) : super(const MissionDetailState());

  /// Charge le detail d'une mission.
  /// Offline-first : hydrate cache → tente API → persiste.
  Future<void> load(String id) async {
    // Hydrate depuis cache si on n'a rien.
    if (state.mission == null) {
      final Map<String, dynamic>? cached =
          await MissionLocalCache.instance.loadDetailRaw(id);
      if (cached != null) {
        try {
          state = state.copyWith(mission: Mission.fromJson(cached));
        } catch (_) {/* cache corrompu */}
      }
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _missionService.getMission(id);
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final mission = Mission.fromJson(data);

      state = state.copyWith(mission: mission, isLoading: false);
      unawaited(MissionLocalCache.instance.saveDetailRaw(id, data));
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: state.mission == null
            ? 'Impossible de charger la mission'
            : null,
      );
    }
  }

  /// Accepte la mission en cours (optimistic + enqueue + best-effort sync).
  /// Skill `zeet-offline-first` §6 : update local immédiat, sync server
  /// en arrière-plan via [OfflineQueueService].
  Future<Map<String, dynamic>> accept() async {
    return _runOptimistic(
      type: QueuedActionType.acceptMission,
      optimisticStatus: 'accepted',
      successMessage: 'Mission acceptee',
    );
  }

  /// Rejette la mission en cours (optimistic + enqueue).
  Future<Map<String, dynamic>> reject({required String reason}) async {
    return _runOptimistic(
      type: QueuedActionType.rejectMission,
      optimisticStatus: 'rejected',
      successMessage: 'Mission refusee',
      payload: <String, dynamic>{'reason': reason},
    );
  }

  /// Confirme la collecte de la commande (optimistic + enqueue).
  Future<Map<String, dynamic>> collect({required String otpCode}) async {
    return _runOptimistic(
      type: QueuedActionType.collectMission,
      optimisticStatus: 'collected',
      successMessage: 'Commande collectee',
      payload: <String, dynamic>{'otp_code': otpCode},
    );
  }

  /// Confirme la livraison au client (optimistic + enqueue).
  Future<Map<String, dynamic>> deliver({required String otpCode}) async {
    return _runOptimistic(
      type: QueuedActionType.deliverMission,
      optimisticStatus: 'delivered',
      successMessage: 'Livraison effectuee',
      payload: <String, dynamic>{'otp_code': otpCode},
    );
  }

  /// Signale que la livraison n'a pas pu etre effectuee (optimistic + enqueue).
  Future<Map<String, dynamic>> notDelivered({
    required String reason,
    double? lat,
    double? lng,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{'reason': reason};
    if (lat != null) payload['geo_lat'] = lat.toString();
    if (lng != null) payload['geo_lng'] = lng.toString();
    return _runOptimistic(
      type: QueuedActionType.markNotDelivered,
      optimisticStatus: 'not-delivered',
      successMessage: 'Signalement enregistre',
      payload: payload,
    );
  }

  // ---------------------------------------------------------------------------
  // Implémentation commune optimistic + enqueue
  // ---------------------------------------------------------------------------

  /// Pattern unifié : update local immédiat, persiste l'action dans la
  /// queue offline, puis lance une sync best-effort (fire-and-forget).
  /// Le retour est toujours `success: true` côté UI tant qu'une mission
  /// est chargée — l'éventuel échec sync sera signalé via le banner
  /// global ("X actions en attente").
  Future<Map<String, dynamic>> _runOptimistic({
    required QueuedActionType type,
    required String optimisticStatus,
    required String successMessage,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final Mission? current = state.mission;
    if (current == null) {
      return <String, dynamic>{
        'success': false,
        'message': 'Aucune mission chargee',
      };
    }

    // 1. Update optimiste immédiat (UI réactive sans spinner).
    state = state.copyWith(
      mission: current.copyWith(status: optimisticStatus),
      clearActionError: true,
    );

    // 2. Tracking GPS : start au accept/collect, stop au deliver/notDelivered.
    //    Voir `LocationTrackingService` pour le binding foreground.
    _toggleTrackingForAction(type, current.id.toString());

    // 3. Enqueue pour persister l'intention (survit au kill app).
    await OfflineQueueService.instance.enqueue(
      type: type,
      missionId: current.id.toString(),
      payload: payload,
    );

    // 4. Best-effort sync (fire-and-forget). Si le réseau est dispo
    //    l'action partira immédiatement ; sinon elle sera retentée
    //    par les triggers de sync (connectivity restored, app resumed).
    unawaited(OfflineQueueService.instance.sync());

    return <String, dynamic>{
      'success': true,
      'message': successMessage,
    };
  }

  void _toggleTrackingForAction(QueuedActionType type, String missionId) {
    switch (type) {
      case QueuedActionType.acceptMission:
      case QueuedActionType.collectMission:
        unawaited(LocationTrackingService.instance.startTracking(
          missionId: missionId,
        ));
        break;
      case QueuedActionType.deliverMission:
      case QueuedActionType.markNotDelivered:
      case QueuedActionType.rejectMission:
        unawaited(LocationTrackingService.instance.stopTracking());
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Providers Riverpod
// ---------------------------------------------------------------------------

final missionsListProvider =
    StateNotifierProvider<MissionsListNotifier, MissionsListState>((ref) {
  final missionService = ref.watch(missionServiceProvider);
  return MissionsListNotifier(missionService);
});

/// `autoDispose` : le state est libéré quand plus aucun widget ne le watch
/// (typiquement au pop de DeliveryDetailsScreen). Évite le flash de
/// données ancienne mission au push d'une nouvelle. Skill `zeet-offline-first`
/// §4 + `zeet-performance-budget` §8 (pas de fuite memoire).
final missionDetailProvider = StateNotifierProvider.autoDispose<
    MissionDetailNotifier, MissionDetailState>((ref) {
  final missionService = ref.watch(missionServiceProvider);
  return MissionDetailNotifier(missionService);
});

/// Provider pratique : missions disponibles.
final availableMissionsProvider = Provider<List<Mission>>((ref) {
  return ref.watch(missionsListProvider).available;
});

/// Provider pratique : missions en cours.
final ongoingMissionsProvider = Provider<List<Mission>>((ref) {
  return ref.watch(missionsListProvider).ongoing;
});

/// Provider pratique : missions terminees.
final completedMissionsProvider = Provider<List<Mission>>((ref) {
  return ref.watch(missionsListProvider).completed;
});
