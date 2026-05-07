// lib/screens/delivery_details/steps/step_trajet_actions.dart
//
// Step TRAJET — affichée quand `mission.status` ∈ {collected, on-the-way,
// collecting, delivering, picked-up}. Le rider va vers le client. Action
// primaire = slide-to-confirm "Livraison effectuée" (rendue par
// PrimaryStepAction côté orchestrateur, vert `success`). Action secondaire
// = "Livraison impossible" (not-delivered).
//
// Stateless, pure UI. La logique reste dans l'orchestrateur.
//
// Plan §4.P4.1 — refonte 3 step-screens.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zeet_ui/zeet_ui.dart';

class StepTrajetActions extends StatelessWidget {
  /// Label du bouton primaire deliver — fallback si l'orchestrateur ne
  /// rend pas `PrimaryStepAction`.
  final String deliverLabel;

  /// Label du bouton "livraison impossible".
  final String reportLabel;

  /// Si `true`, masque le bouton deliver (slide-to-confirm primaire rendu
  /// par `PrimaryStepAction` côté orchestrateur).
  final bool hidePrimary;

  final VoidCallback onDeliver;
  final VoidCallback onNotDelivered;

  const StepTrajetActions({
    super.key,
    required this.onDeliver,
    required this.onNotDelivered,
    this.deliverLabel = 'Livraison effectuée',
    this.reportLabel = 'Livraison impossible',
    this.hidePrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('step_trajet_actions'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!hidePrimary) ...<Widget>[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onDeliver,
              style: ElevatedButton.styleFrom(
                backgroundColor: ZeetColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                deliverLabel,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: onNotDelivered,
            style: OutlinedButton.styleFrom(
              foregroundColor: ZeetColors.danger,
              side: const BorderSide(color: ZeetColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              reportLabel,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
