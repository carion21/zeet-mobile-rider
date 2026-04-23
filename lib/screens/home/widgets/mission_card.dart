// lib/screens/home/widgets/mission_card.dart
//
// Card de mission reutilisable (available + ongoing). Conserve le Hero
// `mission-ref-${mission.id}` qui flie vers le header du detail.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/widgets/mission_status_chip.dart';
import 'package:zeet_ui/zeet_ui.dart';

class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
  });

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Routes.pushMissionDetails(missionId: mission.id.toString());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tete reference + badge statut.
              // Hero `mission-ref-${id}` flie vers le header de detail.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Hero(
                    tag: 'mission-ref-${mission.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        mission.orderReference,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  MissionStatusChip(mission: mission, dense: true),
                ],
              ),
              const SizedBox(height: 12),

              // Restaurant
              Row(
                children: [
                  IconManager.getIcon(
                    'restaurant',
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mission.partnerName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Client
              Row(
                children: [
                  IconManager.getIcon(
                    'person',
                    color: textLightColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mission.customerName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Adresse de livraison
              Row(
                children: [
                  IconManager.getIcon(
                    'location',
                    color: textLightColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mission.dropoffAddressDisplay,
                      style: TextStyle(
                        color: textLightColor,
                        fontSize: 13.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bas de carte : badges (distance/temps) + frais
              Row(
                children: [
                  if (mission.distance != null)
                    _SmallBadge(
                      iconName: 'location_on',
                      text: '${mission.distance!.toStringAsFixed(1)} km',
                      color: ZeetColors.success,
                    ),
                  if (mission.distance != null) const SizedBox(width: 8),
                  if (mission.estimatedTime != null)
                    _SmallBadge(
                      iconName: 'access_time',
                      text: '${mission.estimatedTime} min',
                      color: ZeetColors.danger,
                    ),
                  const Spacer(),
                  ZeetMoney(
                    amount: mission.fee,
                    currency: ZeetCurrency.fcfa,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({
    required this.iconName,
    required this.text,
    required this.color,
  });

  final String iconName;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconManager.getIcon(iconName, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
