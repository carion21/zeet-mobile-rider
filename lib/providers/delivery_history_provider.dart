// lib/providers/delivery_history_provider.dart
//
// Provider pour l'historique paginé des livraisons du rider
// (GET /v1/rider/deliveries). Supporte scroll infini + filtre par statut.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rider/models/delivery_history_model.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/delivery_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------
final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService();
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class DeliveryHistoryState {
  final List<DeliveryHistoryItem> items;
  final DeliveryHistoryMeta? meta;
  final DeliveryHistoryFilter filter;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  const DeliveryHistoryState({
    this.items = const [],
    this.meta,
    this.filter = DeliveryHistoryFilter.all,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  bool get hasMore => meta?.hasNextPage ?? false;
  int get currentPage => meta?.page ?? 0;
  bool get isEmpty => !isLoading && items.isEmpty && errorMessage == null;

  DeliveryHistoryState copyWith({
    List<DeliveryHistoryItem>? items,
    DeliveryHistoryMeta? meta,
    DeliveryHistoryFilter? filter,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DeliveryHistoryState(
      items: items ?? this.items,
      meta: meta ?? this.meta,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------
class DeliveryHistoryNotifier extends StateNotifier<DeliveryHistoryState> {
  final DeliveryService _service;

  DeliveryHistoryNotifier(this._service) : super(const DeliveryHistoryState());

  static const int _pageSize = 25;

  /// Charge la premiere page selon le filtre courant.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.listDeliveries(
        page: 1,
        limit: _pageSize,
        status: state.filter.apiStatus,
      );
      state = state.copyWith(
        items: result.data,
        meta: result.meta,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[DeliveryHistory] load error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger l\'historique des livraisons',
      );
    }
  }

  /// Charge la page suivante (scroll infini).
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final nextPage = state.currentPage + 1;
      final result = await _service.listDeliveries(
        page: nextPage,
        limit: state.meta?.limit ?? _pageSize,
        status: state.filter.apiStatus,
      );
      state = state.copyWith(
        items: <DeliveryHistoryItem>[...state.items, ...result.data],
        meta: result.meta,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[DeliveryHistory] loadMore error: $e');
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'Erreur de chargement',
      );
    }
  }

  /// Change le filtre et recharge depuis la page 1.
  Future<void> setFilter(DeliveryHistoryFilter filter) async {
    if (state.filter == filter) return;
    state = state.copyWith(
      filter: filter,
      items: const [],
      meta: null,
      clearError: true,
    );
    await load();
  }

  /// Pull-to-refresh.
  Future<void> refresh() => load();
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------
final deliveryHistoryProvider =
    StateNotifierProvider<DeliveryHistoryNotifier, DeliveryHistoryState>((ref) {
  final service = ref.watch(deliveryServiceProvider);
  return DeliveryHistoryNotifier(service);
});
