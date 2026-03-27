import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/mission_service.dart';

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
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _missionService.listMissions();
      final dataRaw = response['data'];

      List<Mission> missions = [];
      if (dataRaw is List) {
        missions = dataRaw
            .whereType<Map<String, dynamic>>()
            .map((e) => Mission.fromJson(e))
            .toList();
      } else if (dataRaw is Map<String, dynamic> && dataRaw['items'] is List) {
        // Reponse paginee
        missions = (dataRaw['items'] as List)
            .whereType<Map<String, dynamic>>()
            .map((e) => Mission.fromJson(e))
            .toList();
      }

      state = state.copyWith(missions: missions, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les missions',
      );
    }
  }

  /// Rafraichit la liste des missions.
  Future<void> refresh() => load();

  /// Met a jour le statut d'une mission localement (apres une action).
  void updateMissionStatus(int missionId, String newStatus) {
    final updated = state.missions.map((m) {
      if (m.id == missionId) {
        return m.copyWith(status: newStatus);
      }
      return m;
    }).toList();
    state = state.copyWith(missions: updated);
  }

  /// Supprime une mission de la liste locale (apres reject par ex.).
  void removeMission(int missionId) {
    final updated = state.missions.where((m) => m.id != missionId).toList();
    state = state.copyWith(missions: updated);
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
  Future<void> load(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _missionService.getMission(id);
      final data = response['data'] as Map<String, dynamic>? ?? response;
      final mission = Mission.fromJson(data);

      state = state.copyWith(mission: mission, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger la mission',
      );
    }
  }

  /// Accepte la mission en cours.
  Future<Map<String, dynamic>> accept() async {
    if (state.mission == null) {
      return {'success': false, 'message': 'Aucune mission chargee'};
    }

    state = state.copyWith(isActionLoading: true, clearActionError: true);

    try {
      await _missionService.acceptMission(state.mission!.id.toString());

      state = state.copyWith(
        mission: state.mission!.copyWith(status: 'accepted'),
        isActionLoading: false,
      );
      return {'success': true, 'message': 'Mission acceptee'};
    } on ApiException catch (e) {
      state = state.copyWith(isActionLoading: false, actionError: e.message);
      return {'success': false, 'message': e.message};
    } catch (_) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Erreur lors de l\'acceptation',
      );
      return {'success': false, 'message': 'Erreur lors de l\'acceptation'};
    }
  }

  /// Rejette la mission en cours.
  Future<Map<String, dynamic>> reject({required String reason}) async {
    if (state.mission == null) {
      return {'success': false, 'message': 'Aucune mission chargee'};
    }

    state = state.copyWith(isActionLoading: true, clearActionError: true);

    try {
      await _missionService.rejectMission(
        state.mission!.id.toString(),
        reason: reason,
      );

      state = state.copyWith(
        mission: state.mission!.copyWith(status: 'rejected'),
        isActionLoading: false,
      );
      return {'success': true, 'message': 'Mission refusee'};
    } on ApiException catch (e) {
      state = state.copyWith(isActionLoading: false, actionError: e.message);
      return {'success': false, 'message': e.message};
    } catch (_) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Erreur lors du refus',
      );
      return {'success': false, 'message': 'Erreur lors du refus'};
    }
  }

  /// Confirme la collecte de la commande.
  Future<Map<String, dynamic>> collect({required String otpCode}) async {
    if (state.mission == null) {
      return {'success': false, 'message': 'Aucune mission chargee'};
    }

    state = state.copyWith(isActionLoading: true, clearActionError: true);

    try {
      await _missionService.collectMission(
        state.mission!.id.toString(),
        otpCode: otpCode,
      );

      state = state.copyWith(
        mission: state.mission!.copyWith(status: 'collected'),
        isActionLoading: false,
      );
      return {'success': true, 'message': 'Commande collectee'};
    } on ApiException catch (e) {
      state = state.copyWith(isActionLoading: false, actionError: e.message);
      return {'success': false, 'message': e.message};
    } catch (_) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Erreur lors de la collecte',
      );
      return {'success': false, 'message': 'Erreur lors de la collecte'};
    }
  }

  /// Confirme la livraison au client.
  Future<Map<String, dynamic>> deliver({required String otpCode}) async {
    if (state.mission == null) {
      return {'success': false, 'message': 'Aucune mission chargee'};
    }

    state = state.copyWith(isActionLoading: true, clearActionError: true);

    try {
      await _missionService.deliverMission(
        state.mission!.id.toString(),
        otpCode: otpCode,
      );

      state = state.copyWith(
        mission: state.mission!.copyWith(status: 'delivered'),
        isActionLoading: false,
      );
      return {'success': true, 'message': 'Livraison effectuee'};
    } on ApiException catch (e) {
      state = state.copyWith(isActionLoading: false, actionError: e.message);
      return {'success': false, 'message': e.message};
    } catch (_) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Erreur lors de la livraison',
      );
      return {'success': false, 'message': 'Erreur lors de la livraison'};
    }
  }

  /// Signale que la livraison n'a pas pu etre effectuee.
  Future<Map<String, dynamic>> notDelivered({
    required String reason,
    double? lat,
    double? lng,
  }) async {
    if (state.mission == null) {
      return {'success': false, 'message': 'Aucune mission chargee'};
    }

    state = state.copyWith(isActionLoading: true, clearActionError: true);

    try {
      await _missionService.notDelivered(
        state.mission!.id.toString(),
        reason: reason,
        geoLat: lat?.toString(),
        geoLng: lng?.toString(),
      );

      state = state.copyWith(
        mission: state.mission!.copyWith(status: 'not-delivered'),
        isActionLoading: false,
      );
      return {'success': true, 'message': 'Signalement enregistre'};
    } on ApiException catch (e) {
      state = state.copyWith(isActionLoading: false, actionError: e.message);
      return {'success': false, 'message': e.message};
    } catch (_) {
      state = state.copyWith(
        isActionLoading: false,
        actionError: 'Erreur lors du signalement',
      );
      return {'success': false, 'message': 'Erreur lors du signalement'};
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

final missionDetailProvider =
    StateNotifierProvider<MissionDetailNotifier, MissionDetailState>((ref) {
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
