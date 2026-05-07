// lib/services/mission_action_idempotency_cache.dart
//
// Wrapper rétro-compatible autour de [IdempotencyCache] générique.
// Conserve l'API existante (mintOrReuse / peek / clear / clearAll) et
// délègue la persistance à `IdempotencyCaches.missionAction`.
//
// Pourquoi ?
//   Les endpoints `POST /v1/rider/missions/:id/{accept,collect,deliver,reject,not-delivered}`
//   doivent être dédoublonnés côté backend sur un UUID v4 fourni par le
//   client. Sans persistance, un kill app pendant le POST = nouveau UUID
//   au redémarrage = double prise en charge possible. On persiste donc
//   l'UUID en SharedPreferences AVANT l'appel HTTP, et on ne le supprime
//   QU'UNE FOIS la réponse 2xx confirmée (ou 4xx terminale). Tout retry
//   intermédiaire réutilise le même UUID.
//
// Stratégie de scope :
//   La clé est `idempotency.mission_action.v1.m_<missionId>_<verb>`.
//
// Lifecycle :
//   1. mintOrReuse(missionId, verb) avant le POST.
//   2. Si POST 2xx → clear(missionId, verb).
//   3. Si POST échec réseau / timeout / 5xx → on NE clear PAS.
//   4. Si POST 4xx définitif → clear(...).

import 'package:rider/services/idempotency_cache.dart';

class MissionActionIdempotencyCache {
  MissionActionIdempotencyCache._();
  static final MissionActionIdempotencyCache instance =
      MissionActionIdempotencyCache._();

  /// Verbes autorisés (les 5 actions critiques rider).
  static const Set<String> _kAllowedVerbs = <String>{
    'accept',
    'collect',
    'deliver',
    'reject',
    'not-delivered',
  };

  IdempotencyCache get _cache => IdempotencyCaches.missionAction;

  String _scopeKey(int missionId, String verb) => 'm_${missionId}_$verb';

  void _assertVerb(String verb) {
    assert(
      _kAllowedVerbs.contains(verb),
      'Verb invalide: $verb (attendu: ${_kAllowedVerbs.join(", ")})',
    );
  }

  Future<String> mintOrReuse({
    required int missionId,
    required String verb,
  }) async {
    _assertVerb(verb);
    return _cache.mintOrReuse(_scopeKey(missionId, verb));
  }

  Future<String?> peek({
    required int missionId,
    required String verb,
  }) async {
    _assertVerb(verb);
    return _cache.peek(_scopeKey(missionId, verb));
  }

  Future<void> clear({
    required int missionId,
    required String verb,
  }) async {
    _assertVerb(verb);
    return _cache.clear(_scopeKey(missionId, verb));
  }

  Future<void> clearAll() => _cache.clearAll();
}
