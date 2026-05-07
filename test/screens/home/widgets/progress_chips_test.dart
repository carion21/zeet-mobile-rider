// test/screens/home/widgets/progress_chips_test.dart
//
// Tests fonctionnels (non-pixel-perfect) pour `ProgressChips`. On verifie :
//   - acceptation absente quand stats null (pas de chip placeholder)
//   - acceptation visible avec valeur + couleur quand stats charges
//   - objectif chip absente si non configure (CTA texte a la place)
//   - objectif chip visible "X/Y" si configure, label success quand atteint
//
// Skill `zeet-flutter-widget-test` : on mocke les notifiers via overrides
// Riverpod, on ne touche pas l'API reelle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider/models/earnings_model.dart';
import 'package:rider/models/rider_stats_model.dart';
import 'package:rider/providers/earnings_provider.dart';
import 'package:rider/providers/stats_provider.dart';
import 'package:rider/screens/home/widgets/progress_chips.dart';
import 'package:rider/services/earnings_service.dart';
import 'package:rider/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEarningsNotifier extends EarningsSummaryNotifier {
  _FakeEarningsNotifier(EarningsSummary? summary) : super(EarningsService()) {
    state = EarningsSummaryState(summary: summary);
  }
}

class _FakeStatsNotifier extends RiderStatsNotifier {
  _FakeStatsNotifier(RiderStats? stats) : super(StatsService()) {
    state = RiderStatsState(stats: stats);
  }
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(child: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('etat initial — pas de chip acceptation, CTA objectif visible',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const ProgressChips()));
    await tester.pump();

    // Stats null → pas de chip Acceptation.
    expect(find.text('Acceptation'), findsNothing);
    // Objectif non configure → CTA discret visible, pas de chip.
    expect(find.text('Objectif'), findsNothing);
    expect(find.text('Définir un objectif du jour'), findsOneWidget);
  });

  testWidgets('acceptation chargee — affiche valeur + label', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(
      const ProgressChips(),
      overrides: <Override>[
        riderStatsProvider.overrideWith(
          (ref) => _FakeStatsNotifier(
            const RiderStats(acceptanceRate: 0.92),
          ),
        ),
      ],
    ));
    await tester.pump();

    expect(find.text('92%'), findsOneWidget);
    expect(find.text('Acceptation'), findsOneWidget);
  });

  testWidgets('objectif atteint — affiche X/Y + label success',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues(<String, Object>{
      'rider_daily_goal_courses': 3,
    });

    await tester.pumpWidget(_wrap(
      const ProgressChips(),
      overrides: <Override>[
        earningsSummaryProvider.overrideWith(
          (ref) => _FakeEarningsNotifier(
            const EarningsSummary(
              totalEarnings: 15000,
              completedDeliveries: 5,
              totalDeliveries: 5,
            ),
          ),
        ),
      ],
    ));
    // Laisse le DailyGoalNotifier hydrater depuis SharedPreferences.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('5/3'), findsOneWidget);
    expect(find.text('Objectif atteint'), findsOneWidget);
    // CTA texte cache des qu'un objectif est configure.
    expect(find.text('Définir un objectif du jour'), findsNothing);
  });
}
