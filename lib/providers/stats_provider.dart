import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/rider_stats_model.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/stats_service.dart';

// ---------------------------------------------------------------------------
// Service Provider
// ---------------------------------------------------------------------------
final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService();
});

// ---------------------------------------------------------------------------
// Rider Stats State
// ---------------------------------------------------------------------------
class RiderStatsState {
  final RiderStats? stats;
  final bool isLoading;
  final String? errorMessage;
  final String? currentDateFrom;
  final String? currentDateTo;

  const RiderStatsState({
    this.stats,
    this.isLoading = false,
    this.errorMessage,
    this.currentDateFrom,
    this.currentDateTo,
  });

  RiderStatsState copyWith({
    RiderStats? stats,
    bool? isLoading,
    String? errorMessage,
    String? currentDateFrom,
    String? currentDateTo,
    bool clearError = false,
    bool clearStats = false,
  }) {
    return RiderStatsState(
      stats: clearStats ? null : (stats ?? this.stats),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentDateFrom: currentDateFrom ?? this.currentDateFrom,
      currentDateTo: currentDateTo ?? this.currentDateTo,
    );
  }
}

// ---------------------------------------------------------------------------
// Rider Stats Notifier
// ---------------------------------------------------------------------------
class RiderStatsNotifier extends StateNotifier<RiderStatsState> {
  final StatsService _service;

  RiderStatsNotifier(this._service) : super(const RiderStatsState());

  /// Charge les statistiques.
  ///
  /// [dateFrom] / [dateTo] : ISO 8601 dates optionnelles.
  Future<void> load({String? dateFrom, String? dateTo}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentDateFrom: dateFrom,
      currentDateTo: dateTo,
    );

    try {
      final response = await _service.getStats(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      final data = response['data'] as Map<String, dynamic>? ?? response;
      final stats = RiderStats.fromJson(data);

      state = state.copyWith(stats: stats, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les statistiques',
      );
    }
  }

  /// Rafraichit la periode courante.
  Future<void> refresh() => load(
        dateFrom: state.currentDateFrom,
        dateTo: state.currentDateTo,
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final riderStatsProvider =
    StateNotifierProvider<RiderStatsNotifier, RiderStatsState>((ref) {
  final service = ref.watch(statsServiceProvider);
  return RiderStatsNotifier(service);
});
