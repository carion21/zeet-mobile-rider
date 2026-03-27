import 'package:rider/core/constants/api.dart';
import 'package:rider/services/api_client.dart';

/// Service pour le statut et la localisation du rider.
/// Encapsule les appels aux endpoints `/v1/rider/status` et `/v1/rider/location`.
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
}
