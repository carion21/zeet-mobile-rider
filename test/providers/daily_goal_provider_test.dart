// test/providers/daily_goal_provider_test.dart
//
// Logic-only tests pour `dailyGoalProvider` :
// - default 0 (non defini)
// - setGoal persiste + state mis a jour
// - unset revient a 0
// - SharedPreferences entre instances : le state se recharge a l'init.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider/providers/daily_goal_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('default est 0 (non defini)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // _load est async dans le constructeur. Attendre une frame async.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(dailyGoalProvider), 0);
    expect(container.read(dailyGoalProvider.notifier).isSet, isFalse);
  });

  test('setGoal met a jour le state et persiste', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await container.read(dailyGoalProvider.notifier).setGoal(7);
    expect(container.read(dailyGoalProvider), 7);
    expect(container.read(dailyGoalProvider.notifier).isSet, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('rider_daily_goal_courses'), 7);
  });

  test('setGoal refuse les valeurs negatives', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await container.read(dailyGoalProvider.notifier).setGoal(-3);
    expect(container.read(dailyGoalProvider), 0);
  });

  test('unset revient a 0', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    await container.read(dailyGoalProvider.notifier).setGoal(8);
    expect(container.read(dailyGoalProvider), 8);

    await container.read(dailyGoalProvider.notifier).unset();
    expect(container.read(dailyGoalProvider), 0);
  });

  test('rechargement depuis SharedPreferences au cold-start', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'rider_daily_goal_courses': 5,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Forcer la creation du notifier puis attendre _load.
    container.read(dailyGoalProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(dailyGoalProvider), 5);
    expect(container.read(dailyGoalProvider.notifier).isSet, isTrue);
  });
}
