// lib/services/idempotency_cache.dart
//
// Cache local générique d'UUID d'idempotency pour mutations critiques.
// Généralisation de [MissionActionIdempotencyCache] pour couvrir les autres
// surfaces (plan §7B critère 1, plan §7D §2) :
//
//   - mission_action  : accept/collect/deliver/reject/not-delivered (existant)
//   - notification    : ack/read (cascade WS — éviter doubles ack)
//   - profile_photo   : upload multipart (replay possible si timeout)
//   - cash_collected  : Phase 2 (sync wallet rider ↔ commande)
//   - proof           : Phase 2 (upload preuve livraison séparée)
//
// Sémantique : un namespace + une scope key (souvent l'id ressource + verbe)
// → un UUID v4 persistant. mintOrReuse → POST → clear sur 2xx ou 4xx
// terminal. Le retry réseau/5xx réutilise le même UUID.
//
// Stratégie de namespace SharedPreferences :
//   `idempotency.<namespace>.v1.<scopeKey>` → UUID v4
//
// Skill `zeet-flutter-bloc-recipe` §error-handling.
// Plan §7B critère 1 — Idempotency-Key sur mutations critiques.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache générique. Préférer une instance par namespace pour pouvoir
/// purger un domaine sans toucher les autres.
class IdempotencyCache {
  IdempotencyCache(this.namespace) : assert(namespace.length > 0); // ignore: prefer_is_empty

  /// Namespace logique (ex: `mission_action`, `notification`, `profile_photo`).
  /// Sert à isoler les UUIDs d'un domaine (purge ciblée + debug).
  final String namespace;

  String get _prefix => 'idempotency.$namespace.v1.';

  String _key(String scopeKey) => '$_prefix$scopeKey';

  /// Génère un UUID v4 cryptographiquement aléatoire (RFC 4122).
  static String _generateUuidV4() {
    final Random rng = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final String hex =
        bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// Retourne l'UUID en cache pour [scopeKey], ou en génère un nouveau
  /// et le persiste avant de le retourner. Idempotent : appels successifs
  /// avec la même scopeKey renvoient toujours le même UUID tant que
  /// [clear] n'a pas été appelé.
  ///
  /// Sur fallback (SharedPreferences cassée), retourne un UUID volatile
  /// — préférable à bloquer l'action.
  Future<String> mintOrReuse(String scopeKey) async {
    assert(scopeKey.isNotEmpty, 'scopeKey ne peut pas être vide');
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = _key(scopeKey);
      final String? existing = prefs.getString(key);
      if (existing != null && existing.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[IdempotencyCache:$namespace] reuse $scopeKey: $existing');
        }
        return existing;
      }
      final String fresh = _generateUuidV4();
      await prefs.setString(key, fresh);
      if (kDebugMode) {
        debugPrint('[IdempotencyCache:$namespace] mint $scopeKey: $fresh');
      }
      return fresh;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IdempotencyCache:$namespace] mintOrReuse $scopeKey: $e');
      }
      return _generateUuidV4();
    }
  }

  /// Lit l'UUID en cache sans en créer un. Pour debug / introspection.
  Future<String?> peek(String scopeKey) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key(scopeKey));
    } catch (_) {
      return null;
    }
  }

  /// Supprime l'UUID en cache pour [scopeKey]. À appeler APRÈS :
  /// - une réponse 2xx confirmée (action OK), ou
  /// - une erreur 4xx définitive (400/401/403/404/409/422) — l'action
  ///   ne peut plus aboutir avec ce même UUID.
  /// À NE PAS appeler sur erreur réseau / timeout / 5xx — le retry
  /// suivant doit réutiliser le même UUID.
  Future<void> clear(String scopeKey) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(scopeKey));
      if (kDebugMode) {
        debugPrint('[IdempotencyCache:$namespace] cleared $scopeKey');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IdempotencyCache:$namespace] clear $scopeKey: $e');
      }
    }
  }

  /// Purge tout le namespace (utile au logout).
  Future<void> clearAll() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Set<String> keys = prefs.getKeys();
      for (final String k in keys) {
        if (k.startsWith(_prefix)) {
          await prefs.remove(k);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[IdempotencyCache:$namespace] clearAll: $e');
      }
    }
  }
}

/// Caches préinstanciés par domaine.
///
/// Préférer ces singletons aux instances ad-hoc pour garder une vue
/// claire des namespaces utilisés et faciliter la purge globale au logout.
abstract class IdempotencyCaches {
  /// Actions mission rider (accept/collect/deliver/reject/not-delivered).
  /// Utilisé par [MissionActionIdempotencyCache] (wrapper rétrocompatible).
  static final IdempotencyCache missionAction = IdempotencyCache('mission_action');

  /// Acquittement de notification (POST /notifications/{id}/ack).
  /// Évite la double-ack si le ticker WS retransmet (plan §7B critère 1).
  static final IdempotencyCache notification = IdempotencyCache('notification');

  /// Upload photo profile (POST /profile/photo). Multipart non rejouable
  /// nativement, mais l'UUID permet au backend de dédoublonner si l'app
  /// est tuée pendant l'upload puis le rider re-tente.
  static final IdempotencyCache profilePhoto = IdempotencyCache('profile_photo');

  /// Encaissement cash (Phase 2 — POST /missions/{id}/cash-collected).
  static final IdempotencyCache cashCollected = IdempotencyCache('cash_collected');

  /// Upload preuve livraison séparée (Phase 2 — POST /missions/{id}/proof).
  static final IdempotencyCache proof = IdempotencyCache('proof');

  /// Purge tous les caches (logout).
  static Future<void> clearAll() async {
    await missionAction.clearAll();
    await notification.clearAll();
    await profilePhoto.clearAll();
    await cashCollected.clearAll();
    await proof.clearAll();
  }
}
