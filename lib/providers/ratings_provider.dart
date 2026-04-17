import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/rating_model.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/ratings_service.dart';

// ---------------------------------------------------------------------------
// Service Provider
// ---------------------------------------------------------------------------
final ratingsServiceProvider = Provider<RatingsService>((ref) {
  return RatingsService();
});

// ---------------------------------------------------------------------------
// Ratings List State
// ---------------------------------------------------------------------------
class RatingsListState {
  final List<RatingEntry> entries;
  final RatingSummary summary;
  final RatingsMeta meta;

  /// Chargement de la premiere page (loader plein ecran).
  final bool isLoading;

  /// Chargement d'une page supplementaire (loader bas de liste).
  final bool isLoadingMore;

  /// Message d'erreur (ELAE error state).
  final String? errorMessage;

  const RatingsListState({
    this.entries = const [],
    this.summary = const RatingSummary(),
    this.meta = const RatingsMeta(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  bool get hasMore => meta.page < meta.totalPages;

  /// Etat vide une fois le chargement termine.
  bool get isEmpty =>
      !isLoading && errorMessage == null && entries.isEmpty;

  RatingsListState copyWith({
    List<RatingEntry>? entries,
    RatingSummary? summary,
    RatingsMeta? meta,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RatingsListState(
      entries: entries ?? this.entries,
      summary: summary ?? this.summary,
      meta: meta ?? this.meta,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Ratings Notifier
// ---------------------------------------------------------------------------
class RatingsNotifier extends StateNotifier<RatingsListState> {
  final RatingsService _service;
  static const int _pageSize = 25;

  RatingsNotifier(this._service) : super(const RatingsListState());

  /// Charge la premiere page (utilise aussi pour pull-to-refresh).
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _service.getRatings(page: 1, limit: _pageSize);
      final page = RatingsPage.fromJson(response);

      state = state.copyWith(
        entries: page.entries,
        summary: page.summary,
        meta: page.meta,
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
        errorMessage: 'Impossible de charger vos notes',
      );
    }
  }

  /// Charge la page suivante (pagination infinie).
  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.meta.page + 1;
      final response = await _service.getRatings(
        page: nextPage,
        limit: _pageSize,
      );
      final page = RatingsPage.fromJson(response);

      state = state.copyWith(
        entries: [...state.entries, ...page.entries],
        meta: page.meta,
        summary: page.summary,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Rafraichit la liste (reset page a 1).
  Future<void> refresh() => load();
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final ratingsProvider =
    StateNotifierProvider<RatingsNotifier, RatingsListState>((ref) {
  final service = ref.watch(ratingsServiceProvider);
  return RatingsNotifier(service);
});
