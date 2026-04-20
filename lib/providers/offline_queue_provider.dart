// lib/providers/offline_queue_provider.dart
//
// Providers Riverpod autour de [OfflineQueueService].
// Skill `zeet-offline-first` §5/§6/§7.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/queued_action.dart';
import 'package:rider/services/offline_queue_service.dart';

/// Service singleton (déjà initialisé dans `main.dart`).
final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  return OfflineQueueService.instance;
});

/// Stream de toutes les actions en queue (pending + syncing + failed).
final offlineQueueProvider = StreamProvider<List<QueuedAction>>((ref) {
  final OfflineQueueService svc = ref.watch(offlineQueueServiceProvider);
  return svc.stream;
});

/// Compteur d'actions `pending` (à afficher dans le banner global).
final pendingActionsCountProvider = Provider<int>((ref) {
  final List<QueuedAction> all =
      ref.watch(offlineQueueProvider).maybeWhen(data: (v) => v, orElse: () => const []);
  return all
      .where((QueuedAction a) =>
          a.status == QueuedActionStatus.pending ||
          a.status == QueuedActionStatus.syncing)
      .length;
});

/// Compteur d'actions `failed` (dead letter).
final failedActionsCountProvider = Provider<int>((ref) {
  final List<QueuedAction> all =
      ref.watch(offlineQueueProvider).maybeWhen(data: (v) => v, orElse: () => const []);
  return all
      .where((QueuedAction a) => a.status == QueuedActionStatus.failed)
      .length;
});
