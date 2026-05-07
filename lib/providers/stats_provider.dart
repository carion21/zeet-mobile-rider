import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/rider_stats_model.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/cache_policies.dart';
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
  DateTime? _lastFetchedAt;

  RiderStatsNotifier(this._service) : super(const RiderStatsState());

  /// Charge les statistiques.
  ///
  /// [dateFrom] / [dateTo] : ISO 8601 dates optionnelles.
  /// [force] : si `true`, ignore le TTL [CachePolicy.stats] (5 min).
  Future<void> load({
    String? dateFrom,
    String? dateTo,
    bool force = false,
  }) async {
    // Court-circuit cache : meme periode, donnees fraiches → no-op.
    if (!force &&
        _lastFetchedAt != null &&
        CachePolicies.fresh(CachePolicy.stats, _lastFetchedAt!) &&
        state.stats != null &&
        state.currentDateFrom == dateFrom &&
        state.currentDateTo == dateTo) {
      return;
    }

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
      _lastFetchedAt = DateTime.now();
    } on ApiException catch (e) {
      _lastFetchedAt = null;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (_) {
      _lastFetchedAt = null;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les statistiques',
      );
    }
  }

  /// Rafraichit la periode courante (force refresh, bypass cache).
  Future<void> refresh() => load(
        dateFrom: state.currentDateFrom,
        dateTo: state.currentDateTo,
        force: true,
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
