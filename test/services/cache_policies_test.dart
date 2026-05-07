// test/services/cache_policies_test.dart
//
// Tests de la politique TTL centralisée (lib/services/cache_policies.dart).
// Vérifie le mapping des durées, expired/fresh et la couverture exhaustive
// de l'enum CachePolicy.

import 'package:flutter_test/flutter_test.dart';
import 'package:rider/services/cache_policies.dart';

void main() {
  group('ttlFor', () {
    test('CachePolicy.stats -> 5 minutes', () {
      expect(
        CachePolicies.ttlFor(CachePolicy.stats),
        const Duration(minutes: 5),
      );
    });

    test('CachePolicy.profile -> 1 heure', () {
      expect(
        CachePolicies.ttlFor(CachePolicy.profile),
        const Duration(hours: 1),
      );
    });

    test('CachePolicy.missionsList -> 30 secondes', () {
      expect(
        CachePolicies.ttlFor(CachePolicy.missionsList),
        const Duration(seconds: 30),
      );
    });

    test('toutes les valeurs CachePolicy ont un TTL strictement positif', () {
      for (final policy in CachePolicy.values) {
        final ttl = CachePolicies.ttlFor(policy);
        expect(
          ttl.inMilliseconds,
          greaterThan(0),
          reason: 'TTL manquant ou nul pour $policy',
        );
      }
    });
  });

  group('expired / fresh', () {
    test('expired() est false quand la donnée est fraîche (juste fetched)',
        () {
      // Itération sur plusieurs policies pour couvrir TTL court / moyen / long
      for (final policy in <CachePolicy>[
        CachePolicy.missionsList,
        CachePolicy.stats,
        CachePolicy.profile,
      ]) {
        final justNow = DateTime.now();
        expect(
          CachePolicies.expired(policy, justNow),
          isFalse,
          reason: '$policy: fetched maintenant ne doit pas être expiré',
        );
      }
    });

    test('expired() est true quand lastFetchedAt > TTL + 1s', () {
      for (final policy in <CachePolicy>[
        CachePolicy.missionsList,
        CachePolicy.stats,
        CachePolicy.profile,
      ]) {
        final ttl = CachePolicies.ttlFor(policy);
        final stale = DateTime.now().subtract(ttl + const Duration(seconds: 1));
        expect(
          CachePolicies.expired(policy, stale),
          isTrue,
          reason: '$policy: au-delà du TTL doit être expiré',
        );
      }
    });

    test('fresh() est l\'inverse strict d\'expired()', () {
      final now = DateTime.now();
      for (final policy in CachePolicy.values) {
        // Frais
        expect(
          CachePolicies.fresh(policy, now),
          equals(!CachePolicies.expired(policy, now)),
          reason: '$policy: fresh != !expired (frais)',
        );

        // Périmé
        final ttl = CachePolicies.ttlFor(policy);
        final stale = now.subtract(ttl + const Duration(seconds: 1));
        expect(
          CachePolicies.fresh(policy, stale),
          equals(!CachePolicies.expired(policy, stale)),
          reason: '$policy: fresh != !expired (périmé)',
        );
      }
    });

    test('limite : à peine sous le TTL = encore frais', () {
      // 10s sous le TTL pour couvrir aussi la policy missionDetail (TTL=15s)
      for (final policy in CachePolicy.values) {
        final ttl = CachePolicies.ttlFor(policy);
        if (ttl <= const Duration(seconds: 10)) continue;
        final almostStale =
            DateTime.now().subtract(ttl - const Duration(seconds: 5));
        expect(
          CachePolicies.expired(policy, almostStale),
          isFalse,
          reason: '$policy: juste avant TTL doit rester frais',
        );
      }
    });
  });
}
