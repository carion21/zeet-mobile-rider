// lib/screens/home/index.dart
//
// Orchestrateur leger du Home rider. Compose les sous-widgets dedies :
//   - HomeHeader (avatar + dev btn + notifs + RiderStatusToggle)
//   - EarningsHeroCard (gains du jour)
//   - OngoingMissionsList (section "Mes livraisons")
// Conserve les init FCM/permissions et le pre-prompt notifs cote initState.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/widgets/notif_rationale_sheet.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/providers/earnings_provider.dart';
import 'package:rider/providers/main_tab_provider.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/providers/notifications_provider.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:rider/screens/home/widgets/earnings_hero_card.dart';
import 'package:rider/screens/home/widgets/home_header.dart';
import 'package:rider/screens/home/widgets/notif_warning_banner.dart';
import 'package:rider/screens/home/widgets/ongoing_missions_list.dart';
import 'package:rider/screens/stats/widgets/end_of_day_trigger.dart';
import 'package:rider/services/fcm_service.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:zeet_ui/zeet_ui.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Charger statut + gains + missions + unread count au demarrage.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStatus();
      ref.read(earningsSummaryProvider.notifier).load(period: 'today');
      ref.read(missionsListProvider.notifier).load();
      ref.read(unreadCountProvider.notifier).refresh();
      _maybeShowNotifRationale();
    });
  }

  /// Pre-prompt notifications — affiche le bottom sheet custom avant de
  /// demander la permission systeme (iOS one-shot). Cf.
  /// zeet-notification-strategy §8 : sans notifs, le rider rate ses missions.
  Future<void> _maybeShowNotifRationale() async {
    final alreadyShown = await NotifRationaleSheet.hasBeenShown();
    if (alreadyShown || !mounted) return;

    final accepted = await NotifRationaleSheet.show(context);
    if (accepted == true) {
      await NotifRationaleSheet.markAsShown();
      await FcmService.instance.requestPushPermission();
    }
    // Refus / dismiss : ne PAS marquer shown -> on redemandera au prochain
    // cold-start (evite de bruler la permission iOS prematurement).
  }

  void _initStatus() {
    final rider = ref.read(currentRiderProvider);
    if (rider != null) {
      ref.read(statusProvider.notifier).setOnlineLocally(rider.isOnline);
    }
    ref.read(statusProvider.notifier).loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers so that build() re-runs when they change
    ref.watch(isOnlineProvider);
    ref.watch(currentRiderProvider);

    final earningsState = ref.watch(earningsSummaryProvider);
    final double dailyEarnings = earningsState.summary?.totalEarnings ?? 0;
    final int dailyDeliveries =
        earningsState.summary?.completedDeliveries ??
            earningsState.summary?.totalDeliveries ??
            0;
    final bool isOnline = ref.watch(isOnlineProvider);
    final bool canWrapUpDay = !isOnline && dailyDeliveries >= 1;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    AppSizes().initialize(context);

    final ongoingCount = ref.watch(ongoingMissionsProvider).length;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const HomeHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HomeNotifWarningBanner(),
                    EarningsHeroCard(dailyEarnings: dailyEarnings),
                    const SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSizes().paddingLarge),
                      child: _buildCompactStats(
                        textColor,
                        textLightColor,
                        surfaceColor,
                        isDarkMode,
                        dailyEarnings,
                        ongoingCount,
                      ),
                    ),
                    if (canWrapUpDay) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSizes().paddingLarge),
                        child: _buildWrapUpDayButton(dailyDeliveries),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const OngoingMissionsList(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ongoingCount > 0
          ? _buildDeliveriesFAB(ongoingCount)
          : null,
    );
  }

  Widget _buildDeliveriesFAB(int ongoingCount) {
    return FloatingActionButton(
      onPressed: () =>
          ref.read(mainTabIndexProvider.notifier).goDeliveries(),
      backgroundColor: AppColors.primary,
      elevation: 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Iconsax.task_square,
            color: Colors.white,
            size: 28,
          ),
          if (ongoingCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 10,
                  minHeight: 10,
                ),
                child: Center(
                  child: Text(
                    '$ongoingCount',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11.sp,
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

  /// Bouton "Terminer la journee" — peak moment rider (skill
  /// zeet-neuro-ux §8, peak-end rule). Visible quand :
  ///   - le rider est offline (service cloture), ET
  ///   - il a livre au moins 1 course aujourd'hui.
  ///
  /// Au tap : ouvre le recap bottom sheet avec rolling counters
  /// (gains / courses / note moyenne si dispo).
  Widget _buildWrapUpDayButton(int dailyDeliveries) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await EndOfDayTrigger.maybeShow(context, ref);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.celebration_rounded,
                color: AppColors.primary,
                size: 20.sp,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terminer la journée',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dailyDeliveries == 1
                          ? 'Récap de ta course du jour'
                          : 'Récap de tes $dailyDeliveries courses du jour',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.75),
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.primary,
                size: 14.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStats(
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    bool isDarkMode,
    double dailyEarnings,
    int ongoingCount,
  ) {
    return InkWell(
      onTap: () => ref.read(mainTabIndexProvider.notifier).goStats(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'En attente',
                    style: TextStyle(
                      color: textLightColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconManager.getIcon(
                        'delivery',
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$ongoingCount',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: 1,
                height: 40,
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.15),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Votre gain du jour',
                    style: TextStyle(
                      color: textLightColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconManager.getIcon(
                        'wallet',
                        color: ZeetColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      ZeetMoney(
                        amount: dailyEarnings,
                        currency: ZeetCurrency.fcfa,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
