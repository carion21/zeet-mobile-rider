// test/screens/delivery_details/delivery_navigate_button_test.dart
//
// Widget tests pour le CTA "Naviguer vers...". Vérifie label FR par
// variant, état enabled/disabled selon présence d'URL ou coords, et
// semanticLabel d'accessibilité.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_navigate_button.dart';
import 'package:zeet_ui/zeet_ui.dart';

Mission _makeMission({
  String? navPickupUrl,
  String? navDeliveryUrl,
  double? pickupLat,
  double? pickupLng,
  double? dropoffLat,
  double? dropoffLng,
}) {
  return Mission(
    id: 1,
    pickupAddress: MissionAddress(lat: pickupLat, lng: pickupLng),
    dropoffAddress: MissionAddress(lat: dropoffLat, lng: dropoffLng),
    navigationPickupUrl: navPickupUrl,
    navigationDeliveryUrl: navDeliveryUrl,
  );
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('DeliveryNavigateButton', () {
    testWidgets('variant pickup affiche le label restaurant',
        (tester) async {
      final mission = _makeMission(
        navPickupUrl:
            'https://www.google.com/maps/dir/?api=1&destination=14.7,-17.4&travelmode=driving',
      );
      await tester.pumpWidget(_wrap(DeliveryNavigateButton(
        mission: mission,
        variant: NavigateVariant.pickup,
      )));

      expect(find.text('Naviguer vers le restaurant'), findsOneWidget);
    });

    testWidgets('variant dropoff affiche le label client', (tester) async {
      final mission = _makeMission(
        navDeliveryUrl:
            'https://www.google.com/maps/dir/?api=1&destination=14.7,-17.4&travelmode=driving',
      );
      await tester.pumpWidget(_wrap(DeliveryNavigateButton(
        mission: mission,
        variant: NavigateVariant.dropoff,
      )));

      expect(find.text('Naviguer vers le client'), findsOneWidget);
    });

    testWidgets('bouton enabled si URL backend présente', (tester) async {
      final mission = _makeMission(
        navPickupUrl:
            'https://www.google.com/maps/dir/?api=1&destination=14.7,-17.4&travelmode=driving',
      );
      await tester.pumpWidget(_wrap(DeliveryNavigateButton(
        mission: mission,
        variant: NavigateVariant.pickup,
      )));

      final ZeetButton button = tester.widget<ZeetButton>(
        find.byType(ZeetButton),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('bouton enabled si coords présentes (fallback)',
        (tester) async {
      final mission = _makeMission(
        pickupLat: 14.7167,
        pickupLng: -17.4677,
      );
      await tester.pumpWidget(_wrap(DeliveryNavigateButton(
        mission: mission,
        variant: NavigateVariant.pickup,
      )));

      final ZeetButton button = tester.widget<ZeetButton>(
        find.byType(ZeetButton),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('bouton disabled si ni URL ni coords', (tester) async {
      final mission = _makeMission();
      await tester.pumpWidget(_wrap(DeliveryNavigateButton(
        mission: mission,
        variant: NavigateVariant.pickup,
      )));

      final ZeetButton button = tester.widget<ZeetButton>(
        find.byType(ZeetButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('semanticLabel mentionne coords indisponibles si disabled',
        (tester) async {
      final mission = _makeMission();
      await tester.pumpWidget(_wrap(DeliveryNavigateButton(
        mission: mission,
        variant: NavigateVariant.dropoff,
      )));

      final ZeetButton button = tester.widget<ZeetButton>(
        find.byType(ZeetButton),
      );
      expect(button.semanticLabel, contains('coordonnées indisponibles'));
    });

    testWidgets('variant pickup utilise ZeetButtonVariant.primary',
        (tester) async {
      final mission = _makeMission(pickupLat: 14.7, pickupLng: -17.4);
      await tester.pumpWidget(_wrap(DeliveryNavigateButton(
        mission: mission,
        variant: NavigateVariant.pickup,
      )));

      final ZeetButton button = tester.widget<ZeetButton>(
        find.byType(ZeetButton),
      );
      expect(button.variant, ZeetButtonVariant.primary);
    });

    testWidgets('variant dropoff utilise ZeetButtonVariant.success',
        (tester) async {
      final mission = _makeMission(dropoffLat: 14.7, dropoffLng: -17.4);
      await tester.pumpWidget(_wrap(DeliveryNavigateButton(
        mission: mission,
        variant: NavigateVariant.dropoff,
      )));

      final ZeetButton button = tester.widget<ZeetButton>(
        find.byType(ZeetButton),
      );
      expect(button.variant, ZeetButtonVariant.success);
    });
  });
}
