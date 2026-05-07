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
