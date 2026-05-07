// lib/screens/home/index.dart
//
// Orchestrateur leger du Home rider. Compose les sous-widgets dedies :
//   - HomeHeader (avatar + dev btn + notifs + RiderStatusToggle)
//   - EarningsHeroCard (gains du jour, courses, moyenne, pourboires/primes)
//   - ProgressChips (acceptation + objectif conditionnel)
//   - OngoingMissionsList (section "Mes livraisons")
//
// Refonte 2026-05 (v2) : suppression de KpiGrid 2x2 (note/acceptation/
// online/objectif) — surcharge cognitive sans valeur d'action immediate.
// Note et heures online retournent sur leurs ecrans dedies (/ratings,
// /availability-log). Acceptation et objectif (opt-in) restent visibles
// en bandeau compact via ProgressChips. Skills appliques :
//   - zeet-neuro-ux §1 (Miller 5±2 — reduction zones cognitives)
//   - zeet-3-clicks-rule §5 (rider : home = action, pas dashboard)
//   - zeet-pos-ergonomics §6 (glanceability — 2 chips suffisent)
//   - zeet-performance-budget (2 GET de moins au cold-start home)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/widgets/notif_rationale_sheet.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/providers/earnings_provider.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/providers/notifications_provider.dart';
import 'package:rider/providers/offline_queue_provider.dart';
import 'package:rider/providers/stats_provider.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:rider/screens/home/widgets/earnings_hero_card.dart';
import 'package:rider/screens/home/widgets/home_header.dart';
import 'package:rider/screens/home/widgets/notif_warning_banner.dart';
import 'package:rider/screens/home/widgets/ongoing_missions_list.dart';
import 'package:rider/screens/home/widgets/progress_chips.dart';
import 'package:rider/screens/stats/widgets/end_of_day_trigger.dart';
import 'package:rider/services/fcm_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Charger statut + gains + missions + unread count + stats rider
    // (acceptation seule chip KPI restante sur le home).
    // Note : ratingsProvider et availabilityLogProvider ne sont plus
    // charges ici — leurs ecrans dedies (/ratings, /availability-log)
    // se chargent eux-memes a l'init.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStatus();
      ref.read(earningsSummaryProvider.notifier).load(period: 'today');
      ref.read(missionsListProvider.notifier).load();
      ref.read(unreadCountProvider.notifier).refresh();
      ref.read(riderStatsProvider.notifier).load();
      _maybeShowNotifRationale();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refetch silencieux au retour foreground (Phase 1.3).
    // Aucun flash isLoading : tous les providers utilises ont leur propre
    // silentRefresh qui preserve l'affichage courant pendant le fetch.
    if (state == AppLifecycleState.resumed) {
      ref.read(missionsListProvider.notifier).silentRefresh();
      ref.read(earningsSummaryProvider.notifier).silentRefresh(period: 'today');
      ref.read(unreadCountProvider.notifier).refresh();
      // Bonus : draine la queue offline (best-effort).
      // ignore: discarded_futures
      ref.read(offlineQueueServiceProvider).sync();
    }
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
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : Colors.white;

    AppSizes().initialize(context);

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
                    const SizedBox(height: 8),
                    const ProgressChips(),
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
                        fontSize: 12.sp,
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

}
