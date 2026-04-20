// lib/screens/delivery_details/widgets/delivery_header.dart
//
// Header overlay sur la map : back button + pill `mission-ref-{id}` (Hero
// destination conserve) + bouton historique. Sticky en haut, SafeArea applique
// par l'orchestrateur.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/screens/delivery_details/widgets/mission_logs_sheet.dart';

class DeliveryHeader extends StatelessWidget {
  final String? missionId;
  final String? orderReference;
  final int? missionDbId;

  /// Tap sur l'icone "Signaler un souci". Cache si null.
  final VoidCallback? onReportIssue;

  const DeliveryHeader({
    super.key,
    required this.missionId,
    required this.orderReference,
    required this.missionDbId,
    this.onReportIssue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSizes().paddingMedium),
      child: Row(
        children: [
          // Hit target 48×48 (skill zeet-pos-ergonomics §1) — gants moto OK.
          // Container visuel 42pt centré dans la zone tactile 48pt.
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Routes.goBack(),
                customBorder: const CircleBorder(),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_back,
                        color: AppColors.text, size: 22),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            // Hero destination : matche la card source dans deliveries.
            // Tag stable par mission (`mission-ref-{id}`) pour eviter les
            // collisions entre missions affichees simultanement.
            child: Hero(
              tag: 'mission-ref-${missionId ?? 'pending'}',
              child: Material(
                color: Colors.transparent,
                child: Text(
                  orderReference ?? '#...',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (onReportIssue != null) ...[
            _OverlayCircleButton(
              icon: Icons.warning_amber_rounded,
              color: AppColors.text,
              onTap: onReportIssue!,
              tooltip: 'Signaler un souci',
            ),
            const SizedBox(width: 8),
          ],
          if (missionDbId != null)
            _OverlayCircleButton(
              icon: Icons.history_rounded,
              color: AppColors.text,
              onTap: () => showMissionLogsSheet(
                context,
                missionId: missionDbId.toString(),
              ),
              tooltip: 'Historique de la mission',
            ),
        ],
      ),
    );
  }
}

/// Bouton circulaire blanc overlay sur la map. Hit target 48pt
/// (skill zeet-pos-ergonomics §1) avec visuel 44pt centre.
class _OverlayCircleButton extends StatelessWidget {
  const _OverlayCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
