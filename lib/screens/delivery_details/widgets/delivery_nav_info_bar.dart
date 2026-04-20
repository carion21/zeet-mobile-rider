// lib/screens/delivery_details/widgets/delivery_nav_info_bar.dart
//
// Bandeau Distance / Temps / Arrivee + chevron de toggle (deplie/replie).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:zeet_ui/zeet_ui.dart';

class DeliveryNavInfoBar extends StatelessWidget {
  final double routeDistance;
  final int estimatedTime;
  final String estimatedArrival;
  final bool isExpanded;
  final VoidCallback onToggle;

  const DeliveryNavInfoBar({
    super.key,
    required this.routeDistance,
    required this.estimatedTime,
    required this.estimatedArrival,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    return Container(
      margin: EdgeInsets.only(
        left: AppSizes().paddingLarge,
        right: AppSizes().paddingLarge,
        bottom: 10,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavInfoItem(
                  iconName: 'location_on',
                  value: '${routeDistance.toStringAsFixed(1)} km',
                  label: 'Distance',
                  color: ZeetColors.success,
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                _Divider(color: textLightColor),
                _NavInfoItem(
                  iconName: 'access_time',
                  value: '$estimatedTime min',
                  label: 'Temps',
                  color: ZeetColors.danger,
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                _Divider(color: textLightColor),
                _NavInfoItem(
                  iconName: 'clock',
                  value: estimatedArrival,
                  label: 'Arrivée',
                  color: AppColors.primary,
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: -20,
            child: GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: AppColors.primary,
                      size: 24.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavInfoItem extends StatelessWidget {
  final String iconName;
  final String value;
  final String label;
  final Color color;
  final Color textColor;
  final Color textLightColor;

  const _NavInfoItem({
    required this.iconName,
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
    required this.textLightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconManager.getIcon(iconName, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: textColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: textLightColor, fontSize: 12.sp)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: color.withValues(alpha: 0.2),
    );
  }
}
