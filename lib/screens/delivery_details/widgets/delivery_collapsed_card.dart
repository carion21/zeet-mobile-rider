// lib/screens/delivery_details/widgets/delivery_collapsed_card.dart
//
// Vue compacte (mode replie) : handle + 3 mini infos route + barre de
// progression (DeliveryStepsSection) + recap restau/client/montant.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_steps_section.dart';
import 'package:zeet_ui/zeet_ui.dart';

class DeliveryCollapsedCard extends StatelessWidget {
  final Mission? mission;
  final double routeDistance;
  final int estimatedTime;
  final String estimatedArrival;
  final VoidCallback onExpand;

  const DeliveryCollapsedCard({
    super.key,
    required this.mission,
    required this.routeDistance,
    required this.estimatedTime,
    required this.estimatedArrival,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    return Container(
      margin: EdgeInsets.all(AppSizes().paddingLarge),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onExpand,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textLightColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: _MiniInfoItem(
                    iconName: 'location_on',
                    iconColor: ZeetColors.success,
                    value: '${routeDistance.toStringAsFixed(1)} km',
                    label: 'Distance',
                    textColor: textColor,
                    textLightColor: textLightColor,
                    alignment: MainAxisAlignment.start,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: textLightColor.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _MiniInfoItem(
                    iconName: 'access_time',
                    iconColor: ZeetColors.danger,
                    value: '$estimatedTime min',
                    label: 'Temps',
                    textColor: textColor,
                    textLightColor: textLightColor,
                    alignment: MainAxisAlignment.center,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: textLightColor.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _MiniInfoItem(
                    iconName: 'clock',
                    iconColor: AppColors.primary,
                    value: estimatedArrival,
                    label: 'Arrivée',
                    textColor: textColor,
                    textLightColor: textLightColor,
                    alignment: MainAxisAlignment.end,
                  ),
                ),
              ],
            ),
          ),
          DeliveryStepsSection(
            status: mission?.status,
            dividerColor: textLightColor.withValues(alpha: 0.2),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BulletLine(
                        color: AppColors.primary,
                        text: mission?.partnerName ?? 'Restaurant',
                        textColor: textColor,
                      ),
                      const SizedBox(height: 8),
                      _BulletLine(
                        color: ZeetColors.success,
                        text: mission?.customerName ?? 'Client',
                        textColor: textColor,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ZeetMoney(
                    amount: mission?.fee ?? 0,
                    currency: ZeetCurrency.fcfa,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoItem extends StatelessWidget {
  final String iconName;
  final Color iconColor;
  final String value;
  final String label;
  final Color textColor;
  final Color textLightColor;
  final MainAxisAlignment alignment;

  const _MiniInfoItem({
    required this.iconName,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.textColor,
    required this.textLightColor,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: IconManager.getIcon(iconName, color: iconColor, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: textColor,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(color: textLightColor, fontSize: 11.sp)),
          ],
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  final Color color;
  final String text;
  final Color textColor;

  const _BulletLine({
    required this.color,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
