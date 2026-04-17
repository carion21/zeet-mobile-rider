// Provider Riverpod qui pilote l'ecran "nouvelle livraison" (Incoming Delivery).
//
// Responsabilites :
//  - Detenir le payload courant (ou null si inactif)
//  - Gerer le compte a rebours d'acceptation — DIFFERENT DU PARTNER : ici
//    le backend envoie un `accept_deadline`, on l'utilise comme reference.
//    Le rider est sur le velo avec le tel sous les yeux, la deadline est
//    legitime (au-dela, le backend re-dispatche la mission a un autre rider).
//  - Declencher accept cote API sur acceptation
//  - Declencher reject cote API sur refus ou expiration du deadline
//  - Exposer les etats transitoires (accepting / rejecting) pour l'UI
//
// Hors-scope Phase 2 :
//  - Lecture du ringtone en boucle est gere par l'ecran (flutter_ringtone_player)
//  - File d'attente offline (Phase 5)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rider/models/incoming_delivery_payload.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/mission_service.dart';
import 'package:rider/services/notification_service.dart';

/// Duree de fallback si le payload n'a pas d'accept_deadline.
const Duration kIncomingDeliveryFallbackTimeout = Duration(seconds: 30);

enum IncomingDeliveryPhase {
  idle,
  ringing,
  accepting,
  rejecting,
  accepted,
  rejected,
  error,
}

@immutable
class IncomingDeliveryState {
  final IncomingDeliveryPhase phase;
  final IncomingDeliveryPayload? payload;

  /// Secondes restantes avant auto-refus (derivees de accept_deadline).
  final int secondsRemaining;

  /// Secondes initiales (total) pour calculer la progression circulaire.
  final int totalSeconds;

  /// Dernier message d'erreur utilisateur (affiche inline sur l'ecran).
  final String? errorMessage;

  const IncomingDeliveryState({
    this.phase = IncomingDeliveryPhase.idle,
    this.payload,
    this.secondsRemaining = 0,
    this.totalSeconds = 0,
    this.errorMessage,
  });

  bool get isActive =>
      phase == IncomingDeliveryPhase.ringing ||
      phase == IncomingDeliveryPhase.accepting ||
      phase == IncomingDeliveryPhase.rejecting;

  bool get isBusy =>
      phase == IncomingDeliveryPhase.accepting ||
      phase == IncomingDeliveryPhase.rejecting;

  /// Progression 0.0 → 1.0 pour le minuteur circulaire (1.0 = plein temps).
  double get progress {
    if (totalSeconds <= 0) return 0;
    return (secondsRemaining / totalSeconds).clamp(0.0, 1.0);
  }

  IncomingDeliveryState copyWith({
    IncomingDeliveryPhase? phase,
    IncomingDeliveryPayload? payload,
    int? secondsRemaining,
    int? totalSeconds,
    String? errorMessage,
    bool clearError = false,
    bool clearPayload = false,
  }) {
    return IncomingDeliveryState(
      phase: phase ?? this.phase,
      payload: clearPayload ? null : (payload ?? this.payload),
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class IncomingDeliveryNotifier extends StateNotifier<IncomingDeliveryState> {
  final MissionService _missionService;
  final NotificationService _notificationService;

  Timer? _ticker;

  IncomingDeliveryNotifier({
    MissionService? missionService,
    NotificationService? notificationService,
  })  : _missionService = missionService ?? MissionService(),
        _notificationService = notificationService ?? NotificationService(),
        super(const IncomingDeliveryState());

  // ---------------------------------------------------------------------------
  // Entry point
  // ---------------------------------------------------------------------------

  void show(IncomingDeliveryPayload payload) {
    // Idempotence : meme delivery deja affichee → on ignore.
    if (state.isActive && state.payload?.deliveryId == payload.deliveryId) {
      debugPrint(
        '[IncomingDelivery] duplicate push for delivery ${payload.deliveryId} — ignored',
      );
      return;
    }

    // Calcule le temps restant depuis le deadline backend. Fallback sur 30s
    // si pas de deadline fournie (ou deja expire).
    final fromDeadline = payload.secondsUntilDeadline;
    final remaining = fromDeadline > 0
        ? fromDeadline
        : kIncomingDeliveryFallbackTimeout.inSeconds;

    _stopTicker();
    state = IncomingDeliveryState(
      phase: IncomingDeliveryPhase.ringing,
      payload: payload,
      secondsRemaining: remaining,
      totalSeconds: remaining,
    );
    _startTicker();
  }

  // ---------------------------------------------------------------------------
  // Countdown
  // ---------------------------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!state.isActive) {
        _stopTicker();
        return;
      }
      final remaining = state.secondsRemaining - 1;
      if (remaining <= 0) {
        _stopTicker();
        _autoReject();
      } else {
        state = state.copyWith(secondsRemaining: remaining);
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ---------------------------------------------------------------------------
  // Accept (slide-to-accept)
  // ---------------------------------------------------------------------------

  Future<bool> accept() async {
    final payload = state.payload;
    if (payload == null || state.isBusy) return false;

    _stopTicker();
    state = state.copyWith(
      phase: IncomingDeliveryPhase.accepting,
      clearError: true,
    );

    try {
      await _missionService.acceptMission(payload.deliveryId.toString());

      if (payload.requiresAck && payload.notificationId > 0) {
        try {
          await _notificationService.acknowledge(payload.notificationId);
        } catch (e) {
          debugPrint('[IncomingDelivery] ack failed (non-fatal): $e');
        }
      }

      state = state.copyWith(phase: IncomingDeliveryPhase.accepted);
      return true;
    } on ApiException catch (e) {
      debugPrint('[IncomingDelivery] accept failed: $e');
      state = state.copyWith(
        phase: IncomingDeliveryPhase.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[IncomingDelivery] accept error: $e');
      state = state.copyWith(
        phase: IncomingDeliveryPhase.error,
        errorMessage: 'Impossible d\'accepter la livraison',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Reject (bouton refuser ou expiration auto)
  // ---------------------------------------------------------------------------

  Future<bool> reject({String reason = 'Refusee par le rider'}) async {
    final payload = state.payload;
    if (payload == null || state.isBusy) return false;

    _stopTicker();
    state = state.copyWith(
      phase: IncomingDeliveryPhase.rejecting,
      clearError: true,
    );

    try {
      await _missionService.rejectMission(
        payload.deliveryId.toString(),
        reason: reason,
      );

      if (payload.requiresAck && payload.notificationId > 0) {
        try {
          await _notificationService.acknowledge(payload.notificationId);
        } catch (e) {
          debugPrint('[IncomingDelivery] ack failed (non-fatal): $e');
        }
      }

      state = state.copyWith(phase: IncomingDeliveryPhase.rejected);
      return true;
    } on ApiException catch (e) {
      debugPrint('[IncomingDelivery] reject failed: $e');
      state = state.copyWith(
        phase: IncomingDeliveryPhase.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      debugPrint('[IncomingDelivery] reject error: $e');
      state = state.copyWith(
        phase: IncomingDeliveryPhase.error,
        errorMessage: 'Impossible de refuser la livraison',
      );
      return false;
    }
  }

  Future<void> _autoReject() async {
    await reject(reason: 'Timeout — rider n\'a pas repondu a temps');
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  void dismiss() {
    _stopTicker();
    state = const IncomingDeliveryState();
  }

  void retryAfterError() {
    if (state.phase != IncomingDeliveryPhase.error) return;
    final remaining =
        state.secondsRemaining > 0 ? state.secondsRemaining : state.totalSeconds;
    state = state.copyWith(
      phase: IncomingDeliveryPhase.ringing,
      secondsRemaining: remaining,
      clearError: true,
    );
    _startTicker();
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

final incomingDeliveryProvider = StateNotifierProvider<
    IncomingDeliveryNotifier, IncomingDeliveryState>((ref) {
  return IncomingDeliveryNotifier();
});
