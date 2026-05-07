// test/screens/delivery_details/steps/step_focus_test.dart
//
// Tests pour `DeliveryStepFocus` — source de vérité du routage 3 step-screens
// rider (offer / recup / trajet / terminal).

import 'package:flutter_test/flutter_test.dart';
import 'package:rider/screens/delivery_details/steps/step_focus.dart';

void main() {
  group('DeliveryStepFocusX.fromStatus', () {
    test('null → terminal', () {
      expect(DeliveryStepFocusX.fromStatus(null), DeliveryStepFocus.terminal);
    });

    test('vide → terminal', () {
      expect(DeliveryStepFocusX.fromStatus(''), DeliveryStepFocus.terminal);
    });

    test('assigned → offer', () {
      expect(
        DeliveryStepFocusX.fromStatus('assigned'),
        DeliveryStepFocus.offer,
      );
    });

    test('pending → offer', () {
      expect(
        DeliveryStepFocusX.fromStatus('pending'),
        DeliveryStepFocus.offer,
      );
    });

    test('accepted → recup', () {
      expect(
        DeliveryStepFocusX.fromStatus('accepted'),
        DeliveryStepFocus.recup,
      );
    });

    test('collected → trajet', () {
      expect(
        DeliveryStepFocusX.fromStatus('collected'),
        DeliveryStepFocus.trajet,
      );
    });

    test('on-the-way → trajet', () {
      expect(
        DeliveryStepFocusX.fromStatus('on-the-way'),
        DeliveryStepFocus.trajet,
      );
    });

    test('on_the_way (underscore) → trajet', () {
      expect(
        DeliveryStepFocusX.fromStatus('on_the_way'),
        DeliveryStepFocus.trajet,
      );
    });

    test('picked-up → trajet', () {
      expect(
        DeliveryStepFocusX.fromStatus('picked-up'),
        DeliveryStepFocus.trajet,
      );
    });

    test('collecting → trajet', () {
      expect(
        DeliveryStepFocusX.fromStatus('collecting'),
        DeliveryStepFocus.trajet,
      );
    });

    test('delivering → trajet', () {
      expect(
        DeliveryStepFocusX.fromStatus('delivering'),
        DeliveryStepFocus.trajet,
      );
    });

    test('delivered → terminal', () {
      expect(
        DeliveryStepFocusX.fromStatus('delivered'),
        DeliveryStepFocus.terminal,
      );
    });

    test('not-delivered → terminal', () {
      expect(
        DeliveryStepFocusX.fromStatus('not-delivered'),
        DeliveryStepFocus.terminal,
      );
    });

    test('not_delivered (underscore) → terminal', () {
      expect(
        DeliveryStepFocusX.fromStatus('not_delivered'),
        DeliveryStepFocus.terminal,
      );
    });

    test('cancelled → terminal', () {
      expect(
        DeliveryStepFocusX.fromStatus('cancelled'),
        DeliveryStepFocus.terminal,
      );
    });

    test('canceled (US spelling) → terminal', () {
      expect(
        DeliveryStepFocusX.fromStatus('canceled'),
        DeliveryStepFocus.terminal,
      );
    });

    test('statut inconnu → terminal (graceful fallback)', () {
      expect(
        DeliveryStepFocusX.fromStatus('foobar'),
        DeliveryStepFocus.terminal,
      );
    });
  });

  group('DeliveryStepFocusX.isActive', () {
    test('offer/recup/trajet sont actifs', () {
      expect(DeliveryStepFocus.offer.isActive, true);
      expect(DeliveryStepFocus.recup.isActive, true);
      expect(DeliveryStepFocus.trajet.isActive, true);
    });

    test('terminal n\'est pas actif', () {
      expect(DeliveryStepFocus.terminal.isActive, false);
    });
  });

  group('DeliveryStepFocusX.debugLabel', () {
    test('chaque focus a un label distinct', () {
      final labels = <String>{
        DeliveryStepFocus.offer.debugLabel,
        DeliveryStepFocus.recup.debugLabel,
        DeliveryStepFocus.trajet.debugLabel,
        DeliveryStepFocus.terminal.debugLabel,
      };
      expect(labels.length, 4);
    });
  });
}
