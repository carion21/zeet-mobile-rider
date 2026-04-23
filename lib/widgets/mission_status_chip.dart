// lib/widgets/mission_status_chip.dart
//
// Pill compact (icone + label) qui resume le status d'une mission rider.
// Couleur pilotee par le backend (`mission.statusColor`). L'icone et le
// label viennent de [MissionStatusVisual] qui reste cote client pour
// garder une voix produit coherente.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/mission_status.dart';
import 'package:rider/models/mission_model.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Chip de status mission, dense ou normal.
class MissionStatusChip extends StatelessWidget {
  const MissionStatusChip({
    super.key,
    required this.mission,
    this.dense = false,
    this.useShortLabel = true,
  });

  /// Mission source — porte a la fois le statut brut (pour icone/label) et
  /// la couleur resolue par le backend.
  final Mission mission;

  /// Densite reduite (badges en liste).
  final bool dense;

  /// Si `true`, affiche `shortLabel`. Si `false`, affiche `label` (detail).
  final bool useShortLabel;

  @override
  Widget build(BuildContext context) {
    final MissionStatusVisual visual =
        MissionStatusVisual.resolve(mission.status);
    final Color color = mission.statusColor ?? ZeetColors.inkMuted;
    final String text = mission.lastDeliveryStatus?.label ??
        mission.order?.lastOrderStatus?.label ??
        (useShortLabel ? visual.shortLabel : visual.label);

    final double padH = dense ? 8 : 10;
    final double padV = dense ? 3 : 4;
    final double iconSize = dense ? 12 : 14;
    final double fontSize = dense ? 11.sp : 12.sp;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: iconSize, color: color),
          SizedBox(width: dense ? 4 : 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
