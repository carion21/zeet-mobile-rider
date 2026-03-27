import 'package:rider/core/constants/api.dart';
import 'package:rider/services/api_client.dart';

/// Service pour les missions de livraison du rider.
/// Encapsule les appels aux endpoints `/v1/rider/missions/*`,
/// `/v1/rider/deliveries/transitions` et `/v1/rider/orders/actions`.
class MissionService {
  final ApiClient _apiClient;

  MissionService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/rider/missions
  // ---------------------------------------------------------------------------
  /// Liste les missions du rider.
  /// [status] optionnel pour filtrer par statut.
  Future<Map<String, dynamic>> listMissions({String? status}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      MissionEndpoints.list,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // GET /v1/rider/missions/:id
  // ---------------------------------------------------------------------------
  /// Recupere le detail d'une mission.
  Future<Map<String, dynamic>> getMission(String id) async {
    final response = await _apiClient.get(MissionEndpoints.get(id));
    return response;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/missions/:id/accept
  // ---------------------------------------------------------------------------
  /// Accepte une mission.
  Future<Map<String, dynamic>> acceptMission(String id) async {
    final response = await _apiClient.post(MissionEndpoints.accept(id));
    return response;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/missions/:id/reject
  // ---------------------------------------------------------------------------
  /// Rejette une mission avec une raison.
  Future<Map<String, dynamic>> rejectMission(String id, {required String reason}) async {
    final response = await _apiClient.post(
      MissionEndpoints.reject(id),
      body: {'reason': reason},
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/missions/:id/collect
  // ---------------------------------------------------------------------------
  /// Confirme la collecte d'une commande avec le code OTP du partenaire.
  Future<Map<String, dynamic>> collectMission(String id, {required String otpCode}) async {
    final response = await _apiClient.post(
      MissionEndpoints.collect(id),
      body: {'otp_code': otpCode},
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/missions/:id/deliver
  // ---------------------------------------------------------------------------
  /// Confirme la livraison au client avec le code OTP.
  Future<Map<String, dynamic>> deliverMission(String id, {required String otpCode}) async {
    final response = await _apiClient.post(
      MissionEndpoints.deliver(id),
      body: {'otp_code': otpCode},
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/missions/:id/not-delivered
  // ---------------------------------------------------------------------------
  /// Signale que la livraison n'a pas pu etre effectuee.
  Future<Map<String, dynamic>> notDelivered(
    String id, {
    required String reason,
    String? geoLat,
    String? geoLng,
  }) async {
    final body = <String, dynamic>{
      'reason': reason,
    };
    if (geoLat != null) body['geo_lat'] = geoLat;
    if (geoLng != null) body['geo_lng'] = geoLng;

    final response = await _apiClient.post(
      MissionEndpoints.notDelivered(id),
      body: body,
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // GET /v1/rider/deliveries/transitions
  // ---------------------------------------------------------------------------
  /// Recupere les transitions possibles pour les livraisons.
  Future<Map<String, dynamic>> getTransitions({String? status}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      DeliveryEndpoints.transitions,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // GET /v1/rider/orders/actions
  // ---------------------------------------------------------------------------
  /// Recupere les actions possibles sur les commandes.
  Future<Map<String, dynamic>> getOrderActions({String? status}) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      DeliveryEndpoints.actions,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    return response;
  }
}
