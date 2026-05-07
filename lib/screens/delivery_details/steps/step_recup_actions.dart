// lib/screens/delivery_details/steps/step_recup_actions.dart
//
// Step RÉCUP — affichée quand `mission.status == 'accepted'`. Le rider va
// vers le commerce pour récupérer la commande. Action primaire = slide-to-
// confirm "J'ai récupéré la commande" (rendue par PrimaryStepAction côté
// orchestrateur). Action secondaire = "Signaler un souci" (not-delivered).
//
// Stateless, pure UI. La logique reste dans l'orchestrateur.
//
// Plan §4.P4.1 — refonte 3 step-screens.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zeet_ui/zeet_ui.dart';

class StepRecupActions extends StatelessWidget {
  /// Label du bouton primaire collect — fallback si l'orchestrateur ne
  /// rend pas `PrimaryStepAction` (cas `hidePrimaryStepActions: false`).
  final String collectLabel;

  /// Label du bouton "signaler un souci".
  final String reportLabel;

  /// Si `true`, masque le bouton collect (le slide-to-confirm primaire est
  /// rendu par `PrimaryStepAction` côté orchestrateur).
  final bool hidePrimary;

  final VoidCallback onCollect;
  final VoidCallback onNotDelivered;

  const StepRecupActions({
    super.key,
    required this.onCollect,
    required this.onNotDelivered,
    this.collectLabel = "J'ai récupéré la commande",
    this.reportLabel = 'Signaler un souci',
    this.hidePrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('step_recup_actions'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!hidePrimary) ...<Widget>[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onCollect,
              style: ElevatedButton.styleFrom(
                backgroundColor: ZeetColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                collectLabel,
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
