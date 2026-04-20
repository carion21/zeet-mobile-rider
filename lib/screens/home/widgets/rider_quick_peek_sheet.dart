// lib/screens/home/widgets/rider_quick_peek_sheet.dart
//
// Mini-card affichee en bottom sheet au long-press sur l'avatar Home.
// Permet au rider de verifier rapidement son nom complet, son numero,
// son statut online — sans avoir a naviguer dans Profile.
//
// Skill `zeet-3-clicks-rule` §5bis (long-press preview = 0 tap de nav)
// + `zeet-pos-ergonomics` (info clic au pouce, 1 main).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

Future<void> showRiderQuickPeekSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (BuildContext ctx) => const _RiderQuickPeekSheet(),
  );
}

class _RiderQuickPeekSheet extends ConsumerWidget {
  const _RiderQuickPeekSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rider = ref.watch(currentRiderProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final fullName = (rider == null)
        ? 'Rider'
        : [rider.firstname, rider.lastname]
            .where((s) => s != null && s.trim().isNotEmpty)
            .map((s) => s!.trim())
            .join(' ');
    final phone = rider?.phone ?? '';
    final initials = rider?.initials ?? '';

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 18.h),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Handle drag visuel.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 18.h),
            // Avatar grand.
            Stack(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: ZeetColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // Pastille statut online en bas-droite (skill
                // zeet-pos-ergonomics §6 — couleur + icone + label).
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? ZeetColors.success
                          : ZeetColors.inkMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 3),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              fullName.isEmpty ? 'Rider ZEET' : fullName,
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (phone.isNotEmpty) ...<Widget>[
              SizedBox(height: 4.h),
              Text(
                phone,
                style: tt.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: (isOnline ? ZeetColors.success : ZeetColors.inkMuted)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    isOnline
                        ? Icons.check_circle_rounded
                        : Icons.pause_circle_outline_rounded,
                    size: 14,
                    color:
                        isOnline ? ZeetColors.success : ZeetColors.inkMuted,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    isOnline ? 'En ligne' : 'En pause',
                    style: TextStyle(
                      color: isOnline
                          ? ZeetColors.success
                          : ZeetColors.inkMuted,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Routes.navigateTo(Routes.profile);
                },
                icon: const Icon(Icons.person_rounded, size: 18),
                label: Text(
                  'Voir mon profil',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
