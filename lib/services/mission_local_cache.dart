// lib/services/mission_local_cache.dart
//
// Cache local (SharedPreferences) des réponses API missions.
// Skill `zeet-offline-first` §4 (Architecture local-first) + §10 (TTL).
//
// On persiste les Maps brutes (réponse JSON API) plutôt que les modèles
// Mission, parce que Mission n'a pas de toJson (parsing one-way). Au
// reload, on rejoue Mission.fromJson() pour reconstituer les modèles.
//
// Objectif : si le rider redémarre l'app en zone blanche, l'écran
// "Mes livraisons" s'hydrate depuis le cache au lieu d'afficher une
// liste vide.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MissionLocalCache {
  MissionLocalCache._();

  static final MissionLocalCache instance = MissionLocalCache._();

  static const String _kListKey = 'rider_missions_list_raw_v1';
  static const String _kDetailKeyPrefix = 'rider_mission_detail_raw_v1_';

  // ─── List ─────────────────────────────────────────────────────────

  /// Persist le payload brut retourné par `GET /v1/rider/missions`.
  /// Le caller peut passer soit le `response` complet, soit la `data`.
  Future<void> saveListRaw(List<Map<String, dynamic>> rawItems) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kListKey, jsonEncode(rawItems));
    } catch (e) {
      debugPrint('[MissionLocalCache] saveListRaw error: $e');
    }
  }

  /// Retourne les items bruts du cache (à parser via Mission.fromJson).
  Future<List<Map<String, dynamic>>> loadListRaw() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kListKey);
      if (raw == null || raw.isEmpty) return const <Map<String, dynamic>>[];
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return const <Map<String, dynamic>>[];
      return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (e) {
      debugPrint('[MissionLocalCache] loadListRaw error: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  // ─── Detail ───────────────────────────────────────────────────────

  Future<void> saveDetailRaw(String id, Map<String, dynamic> raw) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_kDetailKeyPrefix$id', jsonEncode(raw));
    } catch (e) {
      debugPrint('[MissionLocalCache] saveDetailRaw error: $e');
    }
  }

  Future<Map<String, dynamic>?> loadDetailRaw(String id) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('$_kDetailKeyPrefix$id');
      if (raw == null || raw.isEmpty) return null;
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (e) {
      debugPrint('[MissionLocalCache] loadDetailRaw error: $e');
      return null;
    }
  }

  /// Purge cache complet (logout, ou debug).
  Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kListKey);
      final Set<String> keys = prefs.getKeys();
      for (final String k in keys) {
        if (k.startsWith(_kDetailKeyPrefix)) {
          await prefs.remove(k);
        }
      }
    } catch (e) {
      debugPrint('[MissionLocalCache] clear error: $e');
    }
  }
}
