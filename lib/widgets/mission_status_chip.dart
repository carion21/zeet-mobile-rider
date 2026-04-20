// lib/widgets/mission_status_chip.dart
//
// Pill compact (icone + label) qui resume le status d'une mission rider.
// Construit a partir de [MissionStatusVisual] -> couleurs et icones
// proviennent du module canonical `core/constants/mission_status.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/mission_status.dart';

/// Chip de status mission, dense ou normal.
class MissionStatusChip extends StatelessWidget {
  const MissionStatusChip({
    super.key,
    required this.visual,
    this.dense = false,
    this.useShortLabel = true,
  });

  /// Construit le chip a partir d'une string brute API.
  factory MissionStatusChip.raw(
    String? rawStatus, {
    Key? key,
    bool dense = false,
    bool useShortLabel = true,
  }) {
    return MissionStatusChip(
      key: key,
      visual: MissionStatusVisual.resolve(rawStatus),
      dense: dense,
      useShortLabel: useShortLabel,
    );
  }

  /// Visuel resolu (color + icon + labels).
  final MissionStatusVisual visual;

  /// Densite reduite (badges en liste).
  final bool dense;

  /// Si `true`, affiche `shortLabel`. Si `false`, affiche `label` (detail).
  final bool useShortLabel;

  @override
  Widget build(BuildContext context) {
    final String text = useShortLabel ? visual.shortLabel : visual.label;
    final double padH = dense ? 8 : 10;
    final double padV = dense ? 3 : 4;
    final double iconSize = dense ? 12 : 14;
    final double fontSize = dense ? 11.sp : 12.sp;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: iconSize, color: visual.color),
          SizedBox(width: dense ? 4 : 6),
          Text(
            text,
            style: TextStyle(
              color: visual.color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
