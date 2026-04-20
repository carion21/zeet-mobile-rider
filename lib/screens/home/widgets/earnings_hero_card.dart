// lib/screens/home/widgets/earnings_hero_card.dart
//
// Card "gains du jour" — image de fond + ZeetMoney rolling counter +
// libelle. Tap -> switch sur l'onglet Stats du MainScaffold (1 tap).
// Skill `zeet-neuro-ux` §11 (peak moment) + `zeet-3-clicks-rule` §1.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/assets.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final walletBackground =
        isDarkMode ? AppAssets.darkWallet : AppAssets.lightWallet;

    return GestureDetector(
      onTap: () => ref.read(mainTabIndexProvider.notifier).goStats(),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: AppSizes().paddingLarge,
          vertical: AppSizes().paddingSmall,
        ),
        padding: EdgeInsets.all(AppSizes().paddingLarge * 1.2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: AssetImage(walletBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Montant récupéré aujourd\'hui',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ZeetMoney(
                  amount: dailyEarnings,
                  currency: ZeetCurrency.fcfa,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: IconManager.getIcon(
                'wallet',
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
