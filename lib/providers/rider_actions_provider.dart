// lib/providers/rider_actions_provider.dart
//
// Cache memoire des actions disponibles par statut delivery / order.
// Evite de re-fetch a chaque rebuild de la mission detail card.
//
// Usage typique :
//   final actions = ref.watch(deliveryActionsProvider(mission.status));
//   actions.when(
//     loading: () => SizedBox(),
//     data: (list) => buildButtons(list),
//     error: (_, _) => fallback(),
//   );

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/rider_action_model.dart';
import 'package:rider/services/rider_actions_service.dart';

final riderActionsServiceProvider = Provider<RiderActionsService>((ref) {
  return RiderActionsService();
});

/// Actions disponibles pour un statut DELIVERY donne.
/// FutureProvider.family : permet de cacher par status (Riverpod fait
/// l'auto-keep tant qu'au moins un widget watch).
final deliveryActionsProvider =
    FutureProvider.family<List<RiderAction>, String>((ref, status) async {
  final svc = ref.watch(riderActionsServiceProvider);
  return svc.getDeliveryActions(status: status);
});

/// Actions disponibles pour un statut ORDER donne.
final orderActionsProvider =
    FutureProvider.family<List<RiderAction>, String>((ref, status) async {
  final svc = ref.watch(riderActionsServiceProvider);
  return svc.getOrderActions(status: status);
});
