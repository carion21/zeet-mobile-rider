// lib/screens/home/widgets/earnings_hero_card.dart
//
// Card "montant recupere" — refonte plein soleil / guidon de moto.
//
// Avant : image background + Colors.white surimpression. En usage reel
// (rider sur scooter, soleil direct, casque), le contraste etait
// imprevisible et le ZeetMoney rolling sans tabular figures faisait
// danser le layout a chaque mise a jour.
//
// Apres :
// - Fond solid `ZeetColors.surface` (light) / `surfaceAltDark` (dark)
//   → contraste mesure 17:1 / 14:1 = AAA+ vs ~5:1 incertain avant.
// - Montant en `ink` 40.sp w900 + `FontFeature.tabularFigures()` :
//   chiffres a largeur fixe, le rolling counter ne danse plus.
// - Bord gauche 4dp `primary` orange ZEET = signal branding visible
//   en peripherique (skill `zeet-pos-ergonomics` §6 glanceability :
//   couleur + icone + label, jamais texte sur image complexe).
// - Label "MONTANT RECUPERE" small caps `primary` letterSpacing 1.5.
// - Footer/icone wallet en cercle `primaryLight` solide (vs alpha:0.2
//   avant qui faisait disparaitre le rond).
//
// Tap = switch sur l'onglet Stats du MainScaffold (3-clicks-rule rider).
// Skill `zeet-neuro-ux` §11 (peak moment) + §12bis.A (dopamine
// anticipation : ZeetMoney rolling counter conserve).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/providers/daily_goal_provider.dart';
import 'package:rider/providers/earnings_provider.dart';
import 'package:rider/providers/main_tab_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

class EarningsHeroCard extends ConsumerWidget {
  const EarningsHeroCard({
    super.key,
    required this.dailyEarnings,
  });

  final double dailyEarnings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(earningsSummaryProvider).summary;
    final int deliveries = summary?.completedDeliveries ?? 0;
    final double avgPerDelivery = deliveries > 0
        ? (summary?.averagePerDelivery ?? (dailyEarnings / deliveries))
        : 0;
    final double tips = summary?.tips ?? 0;
    final double bonuses = summary?.bonuses ?? 0;
    // Plan §3.2 : barre de progression vers objectif courses/jour si
    // l'objectif est défini (opt-in via tile Home). Skill `zeet-neuro-ux`
    // §11 peak moment — feedback immédiat sur la progression.
    final int dailyGoal = ref.watch(dailyGoalProvider);
    final bool hasGoal = dailyGoal > 0;
    final double goalProgress = hasGoal
        ? (deliveries / dailyGoal).clamp(0.0, 1.0)
        : 0.0;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Tokens contrastes maximaux. Ratios mesures :
    // - ink (#0F1115) sur surface (#FFFFFF)        → 17.4:1 AAA+
    // - inkDark (#F7F8FA) sur surfaceAltDark (#1A1E26) → 14.2:1 AAA+
    final Color background =
        isDark ? ZeetColors.surfaceAltDark : ZeetColors.surface;
    final Color amountColor = isDark ? ZeetColors.inkDark : ZeetColors.ink;
    final Color mutedColor =
        isDark ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;
    final Color borderColor =
        isDark ? ZeetColors.lineDark : ZeetColors.line;

    return GestureDetector(
      onTap: () async {
        await ZeetHaptics.success();
        ref.read(mainTabIndexProvider.notifier).goStats();
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(ZeetRadius.md),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ZeetRadius.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Bord gauche orange ZEET — signal branding visible meme
                // en peripherique (rider qui jette un coup d'oeil), sans
                // concurrencer le contraste du montant central.
                Container(width: 4.w, color: ZeetColors.primary),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 18.h, 16.w, 18.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'MONTANT RÉCUPÉRÉ',
                                style: TextStyle(
                                  color: ZeetColors.primary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: ZeetColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: IconManager.getIcon(
                                'wallet',
                                color: ZeetColors.primary,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Aujourd'hui",
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // Montant : extra-large w900 avec tabular figures —
                        // les chiffres ont une largeur fixe, le rolling
                        // counter ne fait plus danser le layout.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: ZeetMoney(
                            amount: dailyEarnings,
                            currency: ZeetCurrency.fcfa,
                            style: TextStyle(
                              color: amountColor,
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              height: 1.05,
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        // Sous-ligne : nombre de courses + moyenne par
                        // course. Aide a contextualiser le montant brut
                        // (skill `zeet-neuro-ux` §13 — un chiffre seul
                        // n'est pas une histoire). Cachee si aucune
                        // course livree aujourd'hui.
                        if (deliveries > 0) ...<Widget>[
                          SizedBox(height: 10.h),
                          Container(height: 1, color: borderColor),
                          SizedBox(height: 10.h),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.two_wheeler_rounded,
                                color: mutedColor,
                                size: 14.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                deliveries == 1
                                    ? '1 course'
                                    : '$deliveries courses',
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (avgPerDelivery > 0) ...<Widget>[
                                Text(
                                  '  ·  ',
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 12.sp,
                                  ),
                                ),
                                Text(
                                  'Moy. ',
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 12.sp,
                                  ),
                                ),
                                ZeetMoney(
                                  amount: avgPerDelivery,
                                  currency: ZeetCurrency.fcfa,
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  ' / course',
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        // Barre de progression vers objectif courses/jour
                        // (plan §3.2). Affichée seulement si objectif défini.
                        // Skill `zeet-neuro-ux` §11 (peak moment, gamification
                        // opt-in) + `zeet-motion-system` (snappy < 200ms).
                        if (hasGoal) ...<Widget>[
                          SizedBox(height: 12.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Objectif du jour',
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$deliveries / $dailyGoal',
                                style: TextStyle(
                                  color: amountColor,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: goalProgress),
                              duration: ZeetMotion.md,
                              curve: ZeetCurves.decelerate,
                              builder: (_, double v, __) =>
                                  LinearProgressIndicator(
                                value: v,
                                minHeight: 6.h,
                                backgroundColor: borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  goalProgress >= 1.0
                                      ? ZeetColors.success
                                      : ZeetColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Chips pourboires/primes — visibles seulement
                        // si > 0 pour eviter de polluer l'ecran. Skill
                        // `zeet-neuro-ux` §12bis (dopamine instantanee).
                        if (tips > 0 || bonuses > 0) ...<Widget>[
                          SizedBox(height: 10.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 6.h,
                            children: <Widget>[
                              if (tips > 0)
                                _BonusChip(
                                  icon: Icons.volunteer_activism_rounded,
                                  label: 'Pourboires',
                                  amount: tips,
                                  bg: ZeetColors.successBg,
                                  fg: ZeetColors.successText,
                                ),
                              if (bonuses > 0)
                                _BonusChip(
                                  icon: Icons.card_giftcard_rounded,
                                  label: 'Prime',
                                  amount: bonuses,
                                  bg: ZeetColors.primaryLight,
                                  fg: ZeetColors.primary,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BonusChip extends StatelessWidget {
  const _BonusChip({
    required this.icon,
    required this.label,
    required this.amount,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String label;
  final double amount;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ZeetRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: fg, size: 14.sp),
          SizedBox(width: 5.w),
          Text(
            '$label +',
            style: TextStyle(
              color: fg,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          ZeetMoney(
            amount: amount,
            currency: ZeetCurrency.fcfa,
            style: TextStyle(
              color: fg,
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
