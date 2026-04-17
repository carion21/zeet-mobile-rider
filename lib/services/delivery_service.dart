import 'package:rider/core/constants/api.dart';
import 'package:rider/models/delivery_history_model.dart';
import 'package:rider/services/api_client.dart';

/// Service pour l'historique des livraisons du rider.
/// Encapsule l'appel a GET /v1/rider/deliveries (pagine, filtrable).
///
/// Distinct de MissionService qui ne couvre que les missions actives.
class DeliveryService {
  final ApiClient _apiClient;

  DeliveryService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/rider/deliveries
  // ---------------------------------------------------------------------------
  /// Liste paginee de l'historique des livraisons.
  ///
  /// [status] : filtre par statut (ex: "delivered", "not-delivered").
  /// [search] : recherche par code de livraison ou de commande.
  /// [dateFrom]/[dateTo] : bornes ISO.
  /// [sort] : defaut "-date_created" cote backend.
  Future<DeliveryHistoryPage> listDeliveries({
    int page = 1,
    int limit = 25,
    String? status,
    String? search,
    String? dateFrom,
    String? dateTo,
    String? sort,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
    if (sort != null && sort.isNotEmpty) queryParams['sort'] = sort;

    final response = await _apiClient.get(
      DeliveryEndpoints.list,
      queryParams: queryParams,
    );

    final rawData = response['data'];
    final items = rawData is List
        ? rawData
            .whereType<Map>()
            .map((e) =>
                DeliveryHistoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DeliveryHistoryItem>[];

    final meta = response['meta'] is Map<String, dynamic>
        ? DeliveryHistoryMeta.fromJson(
            response['meta'] as Map<String, dynamic>)
        : DeliveryHistoryMeta(
            total: items.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return DeliveryHistoryPage(data: items, meta: meta);
  }
}
