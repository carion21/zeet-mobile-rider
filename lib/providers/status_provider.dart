import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/status_service.dart';

// ---------------------------------------------------------------------------
// Service Provider
// ---------------------------------------------------------------------------
final statusServiceProvider = Provider<StatusService>((ref) {
  return StatusService();
});

// ---------------------------------------------------------------------------
// Status State
// ---------------------------------------------------------------------------
class StatusState {
  final bool isOnline;
  final bool isLoading;
  final String? errorMessage;

  const StatusState({
    this.isOnline = false,
    this.isLoading = false,
    this.errorMessage,
  });

  StatusState copyWith({
    bool? isOnline,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StatusState(
      isOnline: isOnline ?? this.isOnline,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Notifier
// ---------------------------------------------------------------------------
class StatusNotifier extends StateNotifier<StatusState> {
  final StatusService _statusService;

  StatusNotifier(this._statusService) : super(const StatusState());

  /// Charge le statut actuel du rider depuis l'API.
  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _statusService.getStatus();
      final data = response['data'] as Map<String, dynamic>? ?? response;

      final online = data['online'] as bool? ?? false;

      state = state.copyWith(
        isOnline: online,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger le statut',
      );
    }
  }

  /// Bascule le statut en ligne / hors ligne.
  /// Retourne un Map avec `success` et `message` pour afficher un toast.
  Future<Map<String, dynamic>> toggleOnline() async {
    final newStatus = !state.isOnline;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _statusService.setOnline(newStatus);

      state = state.copyWith(
        isOnline: newStatus,
        isLoading: false,
      );

      return {
        'success': true,
        'message': newStatus
            ? 'Vous etes maintenant en ligne'
            : 'Vous etes maintenant hors ligne',
      };
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return {'success': false, 'message': e.message};
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors du changement de statut',
      );
      return {'success': false, 'message': 'Erreur lors du changement de statut'};
    }
  }

  /// Met a jour la position GPS du rider.
  Future<void> updateLocation({
    required double lat,
    required double lng,
  }) async {
    try {
      await _statusService.updateLocation(
        lat: lat.toString(),
        lng: lng.toString(),
      );
    } catch (_) {
      // La mise a jour de localisation est best-effort,
      // on ne bloque pas l'UI en cas d'echec.
    }
  }

  /// Met a jour le statut localement (ex: apres un checkAuthStatus qui contient rider_status).
  void setOnlineLocally(bool online) {
    state = state.copyWith(isOnline: online);
  }
}

// ---------------------------------------------------------------------------
// Providers Riverpod
// ---------------------------------------------------------------------------
final statusProvider = StateNotifierProvider<StatusNotifier, StatusState>((ref) {
  final statusService = ref.watch(statusServiceProvider);
  return StatusNotifier(statusService);
});

/// Provider pratique pour lire uniquement le statut en ligne.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(statusProvider).isOnline;
});
