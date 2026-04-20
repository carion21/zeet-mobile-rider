// lib/screens/home/widgets/home_header.dart
//
// Header custom du Home rider : avatar (-> profile, long-press = peek),
// bouton dev (incoming delivery factice), badge notifs (-> notifications),
// et indicateur de statut centre via [RiderStatusToggle].
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/providers/main_tab_provider.dart';
import 'package:rider/providers/notifications_provider.dart';
import 'package:rider/screens/home/widgets/rider_quick_peek_sheet.dart';
import 'package:rider/screens/home/widgets/rider_status_toggle.dart';
import 'package:rider/services/incoming_delivery_dispatcher.dart';
import 'package:rider/services/navigation_service.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes().paddingMedium,
        vertical: AppSizes().paddingSmall,
      ),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _AvatarButton(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kDebugMode)
                    IconButton(
                      tooltip: 'Tester nouvelle livraison (dev)',
                      onPressed: () =>
                          IncomingDeliveryDispatcher.triggerDev(ref),
                      icon: Icon(
                        Icons.flash_on_rounded,
                        color: AppColors.primary,
                        size: 24.r,
                      ),
                    ),
                  _NotificationsButton(textColor: textColor),
                ],
              ),
            ],
          ),
          const Center(child: RiderStatusToggle()),
        ],
      ),
    );
  }
}

class _AvatarButton extends ConsumerWidget {
  const _AvatarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = ref.watch(currentRiderProvider)?.initials ?? '';
    // Tap → profile complet. Long-press → mini-card peek (skill
    // `zeet-3-clicks-rule` §5bis — preview sans nav).
    return Tooltip(
      message: 'Profil — long-press pour voir mes infos',
      child: GestureDetector(
        onTap: () => ref.read(mainTabIndexProvider.notifier).goProfile(),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          showRiderQuickPeekSheet(context);
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsButton extends ConsumerWidget {
  const _NotificationsButton({required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider).count;
    return IconButton(
      onPressed: () => Routes.navigateTo(Routes.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          IconManager.getIcon(
            'notifications',
            color: textColor,
            size: 26,
          ),
          if (unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Center(
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
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
