// lib/services/rider_actions_service.dart
//
// Source de verite UI : actions disponibles selon le statut courant
// (commande ou delivery). A partir de ces actions, les ecrans rider
// generent dynamiquement les boutons (skill ZEET : "ne jamais hardcoder
// statut -> boutons").
//
// Endpoints :
//   GET /v1/rider/orders/actions?status=preparing|ready-for-delivery|on-the-way
//   GET /v1/rider/deliveries/actions?status=assigned|accepted|collected|on-the-way
//   GET /v1/rider/deliveries/transitions?status=...   (debug)

import 'package:rider/core/constants/api.dart';
import 'package:rider/models/rider_action_model.dart';
import 'package:rider/services/api_client.dart';

class RiderActionsService {
  final ApiClient _apiClient;

  RiderActionsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// GET /v1/rider/orders/actions?status=...
  Future<List<RiderAction>> getOrderActions({required String status}) async {
    if (status.isEmpty) return const <RiderAction>[];
    final response = await _apiClient.get(
      OrderActionEndpoints.ordersActions,
      queryParams: <String, String>{'status': status},
    );
    return _parseActions(response);
  }

  /// GET /v1/rider/deliveries/actions?status=...
  Future<List<RiderAction>> getDeliveryActions({required String status}) async {
    if (status.isEmpty) return const <RiderAction>[];
    final response = await _apiClient.get(
      DeliveryEndpoints.deliveriesActions,
      queryParams: <String, String>{'status': status},
    );
    return _parseActions(response);
  }

  /// GET /v1/rider/deliveries/transitions?status=... (debug / safe filter)
  Future<List<String>> getDeliveryTransitions({required String status}) async {
    if (status.isEmpty) return const <String>[];
    final response = await _apiClient.get(
      DeliveryEndpoints.deliveriesTransitions,
      queryParams: <String, String>{'status': status},
    );
    final data = response['data'];
    if (data is List) {
      return data
          .map((e) {
            if (e is String) return e;
            if (e is Map<String, dynamic>) {
              return (e['value']?.toString() ?? '');
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<RiderAction> _parseActions(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(RiderAction.fromJson)
          .toList(growable: false);
    }
    return const <RiderAction>[];
  }
}
