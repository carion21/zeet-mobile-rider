// lib/services/cache_policies.dart
//
// Politique TTL centralisée pour les endpoints GET du rider (plan §7B
// critère 5, §7D §4). Chaque provider qui cache un GET *doit* déclarer
// son TTL ici plutôt que de hardcoder.
//
// Usage typique côté provider (Riverpod) :
//
//   class StatsNotifier extends StateNotifier<...> {
//     DateTime? _lastFetchedAt;
//     Future<void> load({bool force = false}) async {
//       if (!force &&
//           _lastFetchedAt != null &&
//           !CachePolicies.expired(CachePolicy.stats, _lastFetchedAt!)) {
//         return; // cache valide → no-op
//       }
//       final data = await _api.fetch();
//       _lastFetchedAt = DateTime.now();
//       state = data;
//     }
//   }
//
// Règle générale :
//   - Données qui pilotent une action en temps réel (missions list,
//     notifications, unread-count) → TTL court (≤ 30s).
//   - Données agrégées peu sensibles (stats, earnings, ratings) → TTL
//     moyen (2-10 min).
//   - Métadonnées quasi-statiques (statuses, profile, preferences) →
//     TTL long (1h+).

/// Catalogue des politiques de cache par endpoint logique.
enum CachePolicy {
  // ─── Données temps réel (TTL court) ──────────────────────
  /// `GET /v1/rider/missions` — liste missions actives.
  missionsList,

  /// `GET /v1/rider/missions/{id}` — détail mission.
  missionDetail,

  /// `GET /v1/rider/notifications` — liste paginée notifs.
  notificationsList,

  /// `GET /v1/rider/notifications/unread-count` — badge.
  notificationsUnreadCount,

  /// `GET /v1/rider/status` — statut online/offline rider.
  riderStatus,

  // ─── Agrégats (TTL moyen) ────────────────────────────────
  /// `GET /v1/rider/earnings` — résumé période (today/week/month).
  earningsSummary,

  /// `GET /v1/rider/earnings/history` — historique transactions.
  earningsHistory,

  /// `GET /v1/rider/stats` — KPIs agrégés.
  stats,

  /// `GET /v1/rider/ratings` — notes reçues + summary.
  ratings,

  /// `GET /v1/rider/deliveries` — historique livraisons.
  deliveriesHistory,

  /// `GET /v1/rider/availability-log` — historique online/offline.
  availabilityLog,

  /// `GET /v1/rider/missions/{id}/logs` — audit trail mission.
  missionLogs,

  // ─── Métadonnées quasi-statiques (TTL long) ──────────────
  /// `GET /v1/rider/profile` (via auth/me).
  profile,

  /// `GET /v1/rider/notifications/preferences`.
  notificationPreferences,

  /// `GET /v1/rider/{deliveries,orders}/actions?status=`.
  actionsMeta,

  /// `GET /v1/rider/deliveries/transitions?status=`.
  transitionsMeta,
}

/// Singleton qui mappe chaque [CachePolicy] vers son TTL.
/// Centralise les durées pour que la modification d'un TTL touche
/// toujours un seul endroit.
abstract class CachePolicies {
  /// Table de référence des TTL par politique.
  static const Map<CachePolicy, Duration> _ttl = <CachePolicy, Duration>{
    // Temps réel — invalider vite, l'état change vite
    CachePolicy.missionsList: Duration(seconds: 30),
    CachePolicy.missionDetail: Duration(seconds: 15),
    CachePolicy.notificationsList: Duration(seconds: 30),
    CachePolicy.notificationsUnreadCount: Duration(seconds: 30),
    CachePolicy.riderStatus: Duration(seconds: 30),

    // Agrégats — coût backend modéré, refresh raisonnable
    CachePolicy.earningsSummary: Duration(minutes: 2),
    CachePolicy.earningsHistory: Duration(minutes: 5),
    CachePolicy.stats: Duration(minutes: 5),
    CachePolicy.ratings: Duration(minutes: 10),
    CachePolicy.deliveriesHistory: Duration(minutes: 5),
    CachePolicy.availabilityLog: Duration(minutes: 5),
    CachePolicy.missionLogs: Duration(minutes: 1),

    // Quasi-statique — cache long, refresh sur action utilisateur
    CachePolicy.profile: Duration(hours: 1),
    CachePolicy.notificationPreferences: Duration(hours: 1),
    CachePolicy.actionsMeta: Duration(hours: 6),
    CachePolicy.transitionsMeta: Duration(hours: 6),
  };

  /// Retourne le TTL associé à [policy]. Source de vérité unique.
  static Duration ttlFor(CachePolicy policy) {
    final ttl = _ttl[policy];
    assert(ttl != null, 'TTL manquant pour $policy');
    return ttl ?? const Duration(minutes: 1);
  }

  /// Retourne `true` si [lastFetchedAt] est plus vieux que le TTL de
  /// [policy] (donc cache expiré → refetch nécessaire).
  static bool expired(CachePolicy policy, DateTime lastFetchedAt) {
    return DateTime.now().difference(lastFetchedAt) > ttlFor(policy);
  }

  /// Inverse de [expired] : `true` si la donnée cachée est encore fraîche.
  static bool fresh(CachePolicy policy, DateTime lastFetchedAt) =>
      !expired(policy, lastFetchedAt);
}
