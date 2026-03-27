import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/earnings_model.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/earnings_service.dart';

// ---------------------------------------------------------------------------
// Service Provider
// ---------------------------------------------------------------------------
final earningsServiceProvider = Provider<EarningsService>((ref) {
  return EarningsService();
});

// ---------------------------------------------------------------------------
// Earnings Summary State
// ---------------------------------------------------------------------------
class EarningsSummaryState {
  final EarningsSummary? summary;
  final bool isLoading;
  final String? errorMessage;
  final String currentPeriod;

  const EarningsSummaryState({
    this.summary,
    this.isLoading = false,
    this.errorMessage,
    this.currentPeriod = 'week',
  });

  EarningsSummaryState copyWith({
    EarningsSummary? summary,
    bool? isLoading,
    String? errorMessage,
    String? currentPeriod,
    bool clearError = false,
    bool clearSummary = false,
  }) {
    return EarningsSummaryState(
      summary: clearSummary ? null : (summary ?? this.summary),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentPeriod: currentPeriod ?? this.currentPeriod,
    );
  }
}

// ---------------------------------------------------------------------------
// Earnings Summary Notifier
// ---------------------------------------------------------------------------
class EarningsSummaryNotifier extends StateNotifier<EarningsSummaryState> {
  final EarningsService _earningsService;

  EarningsSummaryNotifier(this._earningsService)
      : super(const EarningsSummaryState());

  /// Charge le resume des gains pour une periode donnee.
  Future<void> load({
    String? period,
    String? dateFrom,
    String? dateTo,
  }) async {
    final effectivePeriod = period ?? state.currentPeriod;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentPeriod: effectivePeriod,
    );

    try {
      final response = await _earningsService.getSummary(
        period: effectivePeriod,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      final data = response['data'] as Map<String, dynamic>? ?? response;
      final summary = EarningsSummary.fromJson(data);

      state = state.copyWith(summary: summary, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger les gains',
      );
    }
  }

  /// Change la periode et recharge.
  Future<void> changePeriod(String period) => load(period: period);
}

// ---------------------------------------------------------------------------
// Earnings History State
// ---------------------------------------------------------------------------
class EarningsHistoryState {
  final List<EarningsEntry> entries;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final int currentPage;
  final bool hasMore;

  const EarningsHistoryState({
    this.entries = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.currentPage = 1,
    this.hasMore = true,
  });

  EarningsHistoryState copyWith({
    List<EarningsEntry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    int? currentPage,
    bool? hasMore,
    bool clearError = false,
  }) {
    return EarningsHistoryState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ---------------------------------------------------------------------------
// Earnings History Notifier
// ---------------------------------------------------------------------------
class EarningsHistoryNotifier extends StateNotifier<EarningsHistoryState> {
  final EarningsService _earningsService;
  static const int _pageSize = 10;

  EarningsHistoryNotifier(this._earningsService)
      : super(const EarningsHistoryState());

  /// Charge la premiere page de l'historique.
  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentPage: 1,
      hasMore: true,
    );

    try {
      final response = await _earningsService.getHistory(page: 1, limit: _pageSize);
      final entries = _parseEntries(response);

      state = state.copyWith(
        entries: entries,
        isLoading: false,
        currentPage: 1,
        hasMore: entries.length >= _pageSize,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger l\'historique',
      );
    }
  }

  /// Charge la page suivante (pagination infinie).
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    final nextPage = state.currentPage + 1;
    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _earningsService.getHistory(
        page: nextPage,
        limit: _pageSize,
      );
      final newEntries = _parseEntries(response);

      state = state.copyWith(
        entries: [...state.entries, ...newEntries],
        isLoadingMore: false,
        currentPage: nextPage,
        hasMore: newEntries.length >= _pageSize,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Rafraichit (premiere page).
  Future<void> refresh() => load();

  /// Parse la liste d'entrees depuis la reponse API.
  List<EarningsEntry> _parseEntries(Map<String, dynamic> response) {
    final dataRaw = response['data'];

    if (dataRaw is List) {
      return dataRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => EarningsEntry.fromJson(e))
          .toList();
    } else if (dataRaw is Map<String, dynamic>) {
      // Reponse paginee
      final items = dataRaw['items'] ?? dataRaw['data'];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map((e) => EarningsEntry.fromJson(e))
            .toList();
      }
    }

    return [];
  }
}

// ---------------------------------------------------------------------------
// Providers Riverpod
// ---------------------------------------------------------------------------

final earningsSummaryProvider =
    StateNotifierProvider<EarningsSummaryNotifier, EarningsSummaryState>((ref) {
  final service = ref.watch(earningsServiceProvider);
  return EarningsSummaryNotifier(service);
});

final earningsHistoryProvider =
    StateNotifierProvider<EarningsHistoryNotifier, EarningsHistoryState>((ref) {
  final service = ref.watch(earningsServiceProvider);
  return EarningsHistoryNotifier(service);
});
