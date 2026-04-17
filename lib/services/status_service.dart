import 'package:rider/core/constants/api.dart';
import 'package:rider/models/availability_log_model.dart';
import 'package:rider/services/api_client.dart';

/// Service pour le statut et la localisation du rider.
/// Encapsule les appels aux endpoints `/v1/rider/status`, `/v1/rider/location`
/// et `/v1/rider/availability-log`.
class StatusService {
  final ApiClient _apiClient;

  StatusService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/rider/status
  // ---------------------------------------------------------------------------
  /// Recupere le statut actuel du rider (online/offline).
  Future<Map<String, dynamic>> getStatus() async {
    final response = await _apiClient.get(StatusEndpoints.get);
    return response;
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/rider/status
  // ---------------------------------------------------------------------------
  /// Met a jour le statut en ligne du rider.
  ///
  /// [online] : `true` pour se mettre en ligne, `false` pour se mettre hors ligne.
  Future<Map<String, dynamic>> setOnline(bool online) async {
    final response = await _apiClient.patch(
      StatusEndpoints.setOnline,
      body: {'online': online},
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // PATCH /v1/rider/location
  // ---------------------------------------------------------------------------
  /// Met a jour la position GPS du rider.
  ///
  /// [lat] : latitude (ex: "5.3600").
  /// [lng] : longitude (ex: "-4.0083").
  Future<Map<String, dynamic>> updateLocation({
    required String lat,
    required String lng,
  }) async {
    final response = await _apiClient.patch(
      StatusEndpoints.updateLocation,
      body: {
        'lat': lat,
        'lng': lng,
      },
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // GET /v1/rider/availability-log
  // ---------------------------------------------------------------------------
  /// Recupere l'historique pagine des bascules online/offline du rider.
  Future<AvailabilityLogPage> getAvailabilityLog({
    int page = 1,
    int limit = 25,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParams['date_to'] = dateTo;
    }

    final response = await _apiClient.get(
      StatusEndpoints.availabilityLog,
      queryParams: queryParams,
    );

    final rawData = response['data'];
    final items = rawData is List
        ? rawData
            .whereType<Map>()
            .map((e) =>
                AvailabilityLogEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AvailabilityLogEntry>[];

    final meta = response['meta'] is Map<String, dynamic>
        ? AvailabilityLogMeta.fromJson(
            response['meta'] as Map<String, dynamic>)
        : AvailabilityLogMeta(
            total: items.length,
            page: page,
            limit: limit,
            totalPages: 1,
          );

    return AvailabilityLogPage(data: items, meta: meta);
  }
}
