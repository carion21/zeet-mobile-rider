// lib/screens/home/widgets/rider_status_toggle.dart
//
// Indicateur de statut online/offline du rider (centre dans le header).
// Transition fade+slide via ZeetStateSwitcher quand on bascule.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

class RiderStatusToggle extends ConsumerWidget {
  const RiderStatusToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final bool isOnline = ref.watch(isOnlineProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Statut',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 12.sp,
          ),
        ),
        const SizedBox(height: 2),
        ZeetStateSwitcher(
          stateKey: isOnline,
          child: Row(
            key: ValueKey<bool>(isOnline),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isOnline ? ZeetColors.success : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                isOnline ? 'En ligne' : 'Hors ligne',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
