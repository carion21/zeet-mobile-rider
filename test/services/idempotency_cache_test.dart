// test/services/idempotency_cache_test.dart
//
// Tests du cache générique d'UUID d'idempotency (lib/services/idempotency_cache.dart) :
//   - mintOrReuse persiste l'UUID v4 et le réutilise pour la même scopeKey
//   - peek lit sans créer
//   - clear / clearAll purgent correctement (par scope ou tout le namespace)
//   - isolation entre namespaces
//   - singletons IdempotencyCaches.* exposent les bons namespaces.

import 'package:flutter_test/flutter_test.dart';
import 'package:rider/services/idempotency_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regex officielle d'un UUID v4 (RFC 4122). Le 13e caractère doit être '4'
/// et le 17e doit appartenir à {8,9,a,b}.
final RegExp _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('mintOrReuse', () {
    test('génère un UUID v4 valide', () async {
      final cache = IdempotencyCache('test_ns');
      final uuid = await cache.mintOrReuse('mission-1:accept');

      expect(uuid, matches(_uuidV4));
    });

    test('retourne le même UUID pour la même scopeKey (idempotent)', () async {
      final cache = IdempotencyCache('test_ns');
      final first = await cache.mintOrReuse('mission-1:accept');
      final second = await cache.mintOrReuse('mission-1:accept');
      final third = await cache.mintOrReuse('mission-1:accept');

      expect(second, equals(first));
      expect(third, equals(first));
    });

    test('génère un UUID différent pour scopeKeys différentes', () async {
      final cache = IdempotencyCache('test_ns');
      final a = await cache.mintOrReuse('mission-1:accept');
      final b = await cache.mintOrReuse('mission-2:accept');

      expect(a, isNot(equals(b)));
    });
  });

  group('peek', () {
    test('retourne null si aucun UUID en cache', () async {
      final cache = IdempotencyCache('test_ns');
      final peeked = await cache.peek('mission-1:accept');
      expect(peeked, isNull);
    });

    test('retourne l\'UUID sans en créer', () async {
      final cache = IdempotencyCache('test_ns');
      final minted = await cache.mintOrReuse('mission-1:accept');
      final peeked = await cache.peek('mission-1:accept');

      expect(peeked, equals(minted));
    });

    test('peek seul ne crée pas d\'entrée', () async {
      final cache = IdempotencyCache('test_ns');

      // peek avant tout mint
      final peekedBefore = await cache.peek('mission-1:accept');
      expect(peekedBefore, isNull);

      // Vérifier qu'aucune entrée n'existe en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().any((k) => k.contains('mission-1:accept')), isFalse);
    });
  });

  group('clear', () {
    test('supprime l\'UUID — un mintOrReuse suivant en génère un nouveau',
        () async {
      final cache = IdempotencyCache('test_ns');
      final first = await cache.mintOrReuse('mission-1:accept');

      await cache.clear('mission-1:accept');
      expect(await cache.peek('mission-1:accept'), isNull);

      final second = await cache.mintOrReuse('mission-1:accept');
      expect(second, isNot(equals(first)));
      expect(second, matches(_uuidV4));
    });

    test('clear ne touche pas aux autres scopeKeys', () async {
      final cache = IdempotencyCache('test_ns');
      final a = await cache.mintOrReuse('mission-1:accept');
      final b = await cache.mintOrReuse('mission-2:accept');

      await cache.clear('mission-1:accept');

      expect(await cache.peek('mission-1:accept'), isNull);
      expect(await cache.peek('mission-2:accept'), equals(b));

      // Et le ré-mint sur mission-2 reste idempotent
      expect(await cache.mintOrReuse('mission-2:accept'), equals(b));
      // Tandis que mission-1 a généré un autre
      final aBis = await cache.mintOrReuse('mission-1:accept');
      expect(aBis, isNot(equals(a)));
    });
  });

  group('clearAll', () {
    test('purge tout le namespace courant', () async {
      final cache = IdempotencyCache('ns_a');
      await cache.mintOrReuse('k1');
      await cache.mintOrReuse('k2');
      await cache.mintOrReuse('k3');

      await cache.clearAll();

      expect(await cache.peek('k1'), isNull);
      expect(await cache.peek('k2'), isNull);
      expect(await cache.peek('k3'), isNull);
    });

    test('préserve les autres namespaces (isolation)', () async {
      final cacheA = IdempotencyCache('ns_a');
      final cacheB = IdempotencyCache('ns_b');

      final a1 = await cacheA.mintOrReuse('shared_key');
      final b1 = await cacheB.mintOrReuse('shared_key');

      // Les UUID sont indépendants même avec la même scopeKey
      expect(a1, isNot(equals(b1)));

      await cacheA.clearAll();

      expect(await cacheA.peek('shared_key'), isNull);
      expect(await cacheB.peek('shared_key'), equals(b1));
    });
  });

  group('isolation entre instances de namespaces différents', () {
    test('deux instances avec namespaces différents stockent séparément',
        () async {
      final missionAction = IdempotencyCache('mission_action');
      final notification = IdempotencyCache('notification');

      final m = await missionAction.mintOrReuse('id-42:accept');
      final n = await notification.mintOrReuse('id-42:accept');

      expect(m, isNot(equals(n)));
      expect(await missionAction.peek('id-42:accept'), equals(m));
      expect(await notification.peek('id-42:accept'), equals(n));
    });
  });

  group('IdempotencyCaches singletons', () {
    test('missionAction expose namespace "mission_action"', () async {
      final uuid =
          await IdempotencyCaches.missionAction.mintOrReuse('check-ns');
      expect(uuid, matches(_uuidV4));

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      expect(
        keys.any((k) => k.startsWith('idempotency.mission_action.v1.')),
        isTrue,
      );
      // Cleanup pour ne pas polluer un éventuel test suivant
      await IdempotencyCaches.missionAction.clearAll();
    });

    test('notification expose namespace "notification"', () async {
      await IdempotencyCaches.notification.mintOrReuse('check-ns');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any(
              (k) => k.startsWith('idempotency.notification.v1.'),
            ),
        isTrue,
      );
      await IdempotencyCaches.notification.clearAll();
    });

    test('profilePhoto expose namespace "profile_photo"', () async {
      await IdempotencyCaches.profilePhoto.mintOrReuse('check-ns');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any(
              (k) => k.startsWith('idempotency.profile_photo.v1.'),
            ),
        isTrue,
      );
      await IdempotencyCaches.profilePhoto.clearAll();
    });

    test('cashCollected expose namespace "cash_collected"', () async {
      await IdempotencyCaches.cashCollected.mintOrReuse('check-ns');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any(
              (k) => k.startsWith('idempotency.cash_collected.v1.'),
            ),
        isTrue,
      );
      await IdempotencyCaches.cashCollected.clearAll();
    });

    test('proof expose namespace "proof"', () async {
      await IdempotencyCaches.proof.mintOrReuse('check-ns');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any((k) => k.startsWith('idempotency.proof.v1.')),
        isTrue,
      );
      await IdempotencyCaches.proof.clearAll();
    });

    test('IdempotencyCaches.clearAll() purge tous les namespaces', () async {
      await IdempotencyCaches.missionAction.mintOrReuse('k');
      await IdempotencyCaches.notification.mintOrReuse('k');
      await IdempotencyCaches.profilePhoto.mintOrReuse('k');
      await IdempotencyCaches.cashCollected.mintOrReuse('k');
      await IdempotencyCaches.proof.mintOrReuse('k');

      await IdempotencyCaches.clearAll();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('idempotency.')),
        isEmpty,
      );
    });
  });
}
