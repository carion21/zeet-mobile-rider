import 'package:flutter/foundation.dart';
import 'package:rider/core/constants/api.dart';
import 'package:rider/models/mission_log_model.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/mission_action_idempotency_cache.dart';

/// Service pour les missions de livraison du rider.
/// Encapsule les appels aux endpoints `/v1/rider/missions/*`.
class MissionService {
  final ApiClient _apiClient;

  MissionService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // Helpers idempotency
  // ---------------------------------------------------------------------------

  /// Codes HTTP 4xx terminaux : la requete est consideree comme
  /// definitivement non rejouable. On clear l'UUID d'idempotency dans
  /// ces cas (voir `MissionActionIdempotencyCache`).
  static const Set<int> _kTerminal4xx = <int>{400, 401, 403, 404, 409, 422};

  /// Convertit un id mission (recu en String par les callers historiques)
  /// vers un int pour le scope idempotency. Retourne null si non parsable.
  int? _missionIdAsInt(String id) {
    return int.tryParse(id);
  }

  /// Execute [run] en encadrant la requete par mintOrReuse / clear de
  /// l'UUID d'idempotency. Garantit que :
  /// - Le meme UUID est reutilise sur retry (timeout, 5xx, network).
  /// - L'UUID est efface des qu'on est sur que l'action est terminale
  ///   (2xx ou 4xx liste dans `_kTerminal4xx`).
  Future<Map<String, dynamic>> _withIdempotency({
    required String id,
    required String verb,
    required Future<Map<String, dynamic>> Function(String? idempotencyKey) run,
  }) async {
    final int? missionIdInt = _missionIdAsInt(id);
    String? idempotencyKey;
    if (missionIdInt != null) {
      idempotencyKey = await MissionActionIdempotencyCache.instance.mintOrReuse(
        missionId: missionIdInt,
        verb: verb,
      );
      if (kDebugMode) {
        debugPrint(
          '[MissionService] $verb mission $missionIdInt with Idempotency-Key=$idempotencyKey',
        );
      }
    }

    try {
      final Map<String, dynamic> response = await run(idempotencyKey);
      // 2xx confirme : on libere le slot.
      if (missionIdInt != null) {
        await MissionActionIdempotencyCache.instance.clear(
          missionId: missionIdInt,
          verb: verb,
        );
      }
      return response;
    } on ApiException catch (e) {
      // 4xx terminal : l'action ne peut plus aboutir avec cet UUID,
      // on clear pour ne pas conserver un UUID mort.
      // 5xx / autre code : on garde l'UUID pour le retry.
      if (missionIdInt != null && _kTerminal4xx.contains(e.statusCode)) {
        await MissionActionIdempotencyCache.instance.clear(
          missionId: missionIdInt,
          verb: verb,
        );
      }
      rethrow;
    } catch (_) {
      // Erreur reseau / timeout / parsing : on NE clear PAS, le retry
      // reutilisera le meme UUID via mintOrReuse.
      rethrow;
    }
  }

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

  /// Construit le map d'headers pour `ApiClient.extraHeaders` quand une
  /// cle d'idempotence est disponible. Retourne null si pas de cle (mission
  /// id non parsable) — l'ApiClient ignore alors le merge.
  Map<String, String>? _idempotencyHeaders(String? key) {
    if (key == null) return null;
    return <String, String>{'Idempotency-Key': key};
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/missions/:id/accept
  // ---------------------------------------------------------------------------
  /// Accepte une mission.
  ///
  /// Idempotency : un UUID v4 est genere/reutilise via
  /// `MissionActionIdempotencyCache` et transmis au backend dans le header
  /// HTTP `Idempotency-Key` (le backend deduplique sur cette cle).
  Future<Map<String, dynamic>> acceptMission(String id) async {
    return _withIdempotency(
      id: id,
      verb: 'accept',
      run: (String? key) => _apiClient.post(
        MissionEndpoints.accept(id),
        extraHeaders: _idempotencyHeaders(key),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/missions/:id/reject
  // ---------------------------------------------------------------------------
  /// Rejette une mission avec une raison.
  ///
  /// Idempotency : voir [acceptMission].
  Future<Map<String, dynamic>> rejectMission(String id, {required String reason}) async {
    return _withIdempotency(
      id: id,
      verb: 'reject',
      run: (String? key) => _apiClient.post(
        MissionEndpoints.reject(id),
        body: <String, dynamic>{'reason': reason},
        extraHeaders: _idempotencyHeaders(key),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/missions/:id/collect
  // ---------------------------------------------------------------------------
  /// Confirme la collecte d'une commande avec le code OTP du partenaire.
  ///
  /// Idempotency : voir [acceptMission].
  Future<Map<String, dynamic>> collectMission(String id, {required String otpCode}) async {
    return _withIdempotency(
      id: id,
      verb: 'collect',
      run: (String? key) => _apiClient.post(
        MissionEndpoints.collect(id),
        body: <String, dynamic>{'otp_code': otpCode},
        extraHeaders: _idempotencyHeaders(key),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/missions/:id/deliver
  // ---------------------------------------------------------------------------
  /// Confirme la livraison au client avec le code OTP.
  ///
  /// Idempotency : voir [acceptMission].
  Future<Map<String, dynamic>> deliverMission(String id, {required String otpCode}) async {
    return _withIdempotency(
      id: id,
      verb: 'deliver',
      run: (String? key) => _apiClient.post(
        MissionEndpoints.deliver(id),
        body: <String, dynamic>{'otp_code': otpCode},
        extraHeaders: _idempotencyHeaders(key),
      ),
    );
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
  // GET /v1/rider/missions/:id/logs
  // ---------------------------------------------------------------------------
  /// Recupere l'audit trail d'une mission (timeline des transitions/events).
  Future<List<MissionLogEntry>> getMissionLogs(String id) async {
    final response = await _apiClient.get(MissionEndpoints.logs(id));
    final rawData = response['data'] ?? response['logs'];
    if (rawData is List) {
      return rawData
          .whereType<Map>()
          .map((e) => MissionLogEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const <MissionLogEntry>[];
  }

}
