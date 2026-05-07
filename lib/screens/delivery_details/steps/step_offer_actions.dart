// lib/screens/delivery_details/steps/step_offer_actions.dart
//
// Step OFFER — affichée quand `mission.status == 'assigned'` ou `'pending'`.
// Le rider décide d'accepter ou refuser. 2 actions distinctes (donc pas de
// slide-to-confirm — le swipe serait ambigu sur 2 directions).
//
// Stateless, pure UI. Toute la logique (busy lock, idempotency, API calls)
// reste dans l'orchestrateur via les callbacks.
//
// Plan §4.P4.1 — refonte 3 step-screens.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zeet_ui/zeet_ui.dart';

class StepOfferActions extends StatelessWidget {
  /// Label du bouton accept (peut venir de l'API `/rider/deliveries/actions`).
  final String acceptLabel;

  /// Label du bouton reject (idem).
  final String rejectLabel;

  final VoidCallback onAccept;
  final VoidCallback onReject;

  const StepOfferActions({
    super.key,
    required this.onAccept,
    required this.onReject,
    this.acceptLabel = 'Accepter la livraison',
    this.rejectLabel = 'Refuser',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('step_offer_actions'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Accepter — primaire bleu `info` (pas vert : `accepted` n'est pas
        // un état terminal, vert est réservé à `delivered`).
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: ZeetColors.info,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              acceptLabel,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Refuser — secondaire outlined danger.
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: ZeetColors.danger,
              side: const BorderSide(color: ZeetColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              rejectLabel,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
