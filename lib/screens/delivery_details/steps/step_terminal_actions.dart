// lib/screens/delivery_details/steps/step_terminal_actions.dart
//
// Step TERMINAL — affichée pour `delivered`, `not-delivered`, `cancelled`,
// `canceled`. Plus aucune action métier côté rider, seulement consultation
// de l'historique + retour.
//
// Plan §4.P4.1 — refonte 3 step-screens.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/screens/delivery_details/widgets/mission_logs_sheet.dart';

class StepTerminalActions extends StatelessWidget {
  /// ID mission (pour `showMissionLogsSheet`).
  final String missionId;

  /// Callback retour (pop écran).
  final VoidCallback onClose;

  const StepTerminalActions({
    super.key,
    required this.missionId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('step_terminal_actions'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => showMissionLogsSheet(context, missionId: missionId),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: Text(
              "Voir l'historique",
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onClose,
          child: Text(
            'Retour',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
        ),
      ],
    );
  }
}
