// lib/screens/home/widgets/progress_chips.dart
//
// Bandeau compact de chips de progression rider sur le Home. Remplace
// l'ancienne KpiGrid 2x2 (note / acceptation / en ligne / objectif) qui
// surchargeait l'écran sans valeur d'action immédiate.
//
// Le Home rider sert UNE chose : "que dois-je faire maintenant ?".
// Les vanity metrics (note, heures online) ont leur propre écran dédié
// (/ratings, /availability-log).
//
// Chips affichées :
//   - ✅ Acceptation : seul KPI vraiment actionnable (signal risque
//     deactivation). Code couleur strict : rouge < 70%, orange 70-85%,
//     vert > 85%. Tap → /stats.
//   - 🎯 Objectif : visible UNIQUEMENT si rider a configuré un objectif.
//     Affiche "X/Y courses". Highlight success quand atteint. Tap → édit.
//
// Si objectif non configuré, un lien texte discret "Définir un objectif"
// apparaît sous la chip acceptation (opt-in gamification, jamais imposé).
//
// Skills :
//   - zeet-pos-ergonomics §6 (glanceability — couleur + icône + label)
//   - zeet-neuro-ux §1 (Miller 5±2 — réduit charge cognitive home)
//   - zeet-neuro-ux §11 (peak — objectif = gamification opt-in)
//   - zeet-3-clicks-rule §5 (rider : infos critiques home, pas dashboard)
//   - zeet-design-system (tokens ZeetColors uniquement)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/providers/daily_goal_provider.dart';
import 'package:rider/providers/earnings_provider.dart';
import 'package:rider/providers/stats_provider.dart';
import 'package:rider/screens/home/widgets/daily_goal_sheet.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class ProgressChips extends ConsumerWidget {
  const ProgressChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _AcceptanceView? acceptance = _acceptanceView(ref);
    final _GoalView? goal = _goalView(ref);

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted =
        isDark ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: <Widget>[
              if (acceptance != null)
                _Chip(
                  icon: Icons.check_circle_rounded,
                  iconColor: acceptance.color,
                  bg: acceptance.bg,
                  label: acceptance.value,
                  sublabel: 'Acceptation',
                  onTap: () => Routes.navigateTo(Routes.stats),
                ),
              if (goal != null)
                _Chip(
                  icon: Icons.flag_rounded,
                  iconColor: goal.reached ? ZeetColors.success : ZeetColors.primary,
                  bg: goal.reached ? ZeetColors.successBg : ZeetColors.primaryLight,
                  label: goal.value,
                  sublabel: goal.reached ? 'Objectif atteint' : 'Objectif',
                  onTap: () => showDailyGoalSheet(context),
                ),
            ],
          ),
          // Lien discret "Définir un objectif" — visible uniquement si
          // le rider n'a pas encore configuré (opt-in, jamais imposé).
          if (goal == null) ...<Widget>[
            SizedBox(height: 6.h),
            InkWell(
              onTap: () => showDailyGoalSheet(context),
              borderRadius: BorderRadius.circular(ZeetRadius.sm),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.flag_outlined, color: muted, size: 14.sp),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: Text(
                        'Définir un objectif du jour',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Retourne `null` si stats pas encore chargés (évite chip placeholder
  /// qui pollue l'écran — `zeet-empty-loading-error` : pas de skeleton
  /// sur info secondaire).
  _AcceptanceView? _acceptanceView(WidgetRef ref) {
    final stats = ref.watch(riderStatsProvider).stats;
    if (stats == null) return null;

    final double rate = stats.acceptanceRate;
    final int pct = (rate <= 1.0 ? rate * 100 : rate).round();

    // Code couleur strict : signal risque deactivation rider.
    final Color color;
    final Color bg;
    if (pct < 70) {
      color = ZeetColors.danger;
      bg = ZeetColors.dangerBg;
    } else if (pct < 85) {
      color = ZeetColors.warning;
      bg = ZeetColors.warningBg;
    } else {
      color = ZeetColors.success;
      bg = ZeetColors.successBg;
    }
    return _AcceptanceView(value: '$pct%', color: color, bg: bg);
  }

  /// Retourne `null` si rider n'a pas configuré d'objectif (opt-in).
  _GoalView? _goalView(WidgetRef ref) {
    final int goal = ref.watch(dailyGoalProvider);
    if (goal <= 0) return null;

    final int done = ref.watch(earningsSummaryProvider).summary
            ?.completedDeliveries ??
        0;
    return _GoalView(
      value: '$done/$goal',
      reached: done >= goal,
    );
  }
}

class _AcceptanceView {
  const _AcceptanceView({
    required this.value,
    required this.color,
    required this.bg,
  });
  final String value;
  final Color color;
  final Color bg;
}

class _GoalView {
  const _GoalView({required this.value, required this.reached});
  final String value;
  final bool reached;
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ink = isDark ? ZeetColors.inkDark : ZeetColors.ink;
    final Color muted =
        isDark ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(ZeetRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZeetRadius.pill),
        child: Padding(
          // Hit target ≥ 44pt vertical (a11y + zeet-pos-ergonomics §1).
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: iconColor, size: 16.sp),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: ink,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                sublabel,
                style: TextStyle(
                  color: muted,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
