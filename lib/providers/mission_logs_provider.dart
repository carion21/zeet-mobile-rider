// lib/providers/mission_logs_provider.dart
//
// Provider pour l'audit trail d'une mission (GET /v1/rider/missions/:id/logs).
// Implemente avec FutureProvider.family pour avoir un cache par missionId
// et un rafraichissement simple via `ref.invalidate`.
//
// TTL : [CachePolicy.missionLogs] (1 min). Une entree par missionId est
// gardee en memoire et reutilisee tant qu'elle est fraiche. `ref.invalidate`
// continue a forcer un refetch (l'invalidation supprime aussi le cache TTL).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rider/models/mission_log_model.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/services/cache_policies.dart';

/// Cache TTL en memoire des logs par missionId.
///
/// Cle = missionId. Valeur = (timestamp du dernier fetch, logs).
/// Reset via [resetMissionLogsCache] sur logout / erreur.
final Map<String, _CachedLogs> _logsCache = <String, _CachedLogs>{};

class _CachedLogs {
  final DateTime fetchedAt;
  final List<MissionLogEntry> logs;
  const _CachedLogs(this.fetchedAt, this.logs);
}

/// Vide le cache des logs (a appeler sur logout).
void resetMissionLogsCache() => _logsCache.clear();

/// Recupere la liste des logs d'une mission.
/// Utilisation :
/// ```dart
/// final logsAsync = ref.watch(missionLogsProvider(missionId));
/// // Force refresh : ref.invalidate(missionLogsProvider(missionId));
/// ```
final missionLogsProvider =
    FutureProvider.family<List<MissionLogEntry>, String>((ref, missionId) async {
  // Court-circuit cache TTL.
  final cached = _logsCache[missionId];
  if (cached != null &&
      CachePolicies.fresh(CachePolicy.missionLogs, cached.fetchedAt)) {
    return cached.logs;
  }

  final service = ref.watch(missionServiceProvider);
  try {
    final logs = await service.getMissionLogs(missionId);
    _logsCache[missionId] = _CachedLogs(DateTime.now(), logs);
    return logs;
  } catch (_) {
    // Reset entree cache sur erreur pour que le prochain watch retente.
    _logsCache.remove(missionId);
    rethrow;
  }
});
