// lib/providers/availability_log_provider.dart
//
// Provider pour l'historique des bascules online/offline du rider
// (GET /v1/rider/availability-log). Supporte pagination et pull-to-refresh.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rider/models/availability_log_model.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/status_service.dart';

class AvailabilityLogState {
  final List<AvailabilityLogEntry> entries;
  final AvailabilityLogMeta? meta;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  const AvailabilityLogState({
    this.entries = const [],
    this.meta,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  bool get hasMore => meta?.hasNextPage ?? false;
  int get currentPage => meta?.page ?? 0;
  bool get isEmpty => !isLoading && entries.isEmpty && errorMessage == null;

  AvailabilityLogState copyWith({
    List<AvailabilityLogEntry>? entries,
    AvailabilityLogMeta? meta,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AvailabilityLogState(
      entries: entries ?? this.entries,
      meta: meta ?? this.meta,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AvailabilityLogNotifier extends StateNotifier<AvailabilityLogState> {
  final StatusService _service;

  AvailabilityLogNotifier(this._service) : super(const AvailabilityLogState());

  static const int _pageSize = 25;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _service.getAvailabilityLog(
        page: 1,
        limit: _pageSize,
      );
      state = state.copyWith(
        entries: result.data,
        meta: result.meta,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      debugPrint('[AvailabilityLog] load error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de charger l\'historique',
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final nextPage = state.currentPage + 1;
      final result = await _service.getAvailabilityLog(
        page: nextPage,
        limit: state.meta?.limit ?? _pageSize,
      );
      state = state.copyWith(
        entries: <AvailabilityLogEntry>[...state.entries, ...result.data],
        meta: result.meta,
        isLoadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, errorMessage: e.message);
    } catch (e) {
      debugPrint('[AvailabilityLog] loadMore error: $e');
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: 'Erreur de chargement',
      );
    }
  }

  Future<void> refresh() => load();
}

final availabilityLogProvider =
    StateNotifierProvider<AvailabilityLogNotifier, AvailabilityLogState>((ref) {
  final service = ref.watch(statusServiceProvider);
  return AvailabilityLogNotifier(service);
});
