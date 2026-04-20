// lib/screens/stats/widgets/end_of_day_recap_sheet.dart
//
// Peak moment "fin de service" — modal récap journalier affichée quand
// le rider clôture sa session. 3 KPI animés en cascade, haptic success
// au mount, optionnel confetti si record battu.
//
// Skill `zeet-neuro-ux` §8 (peak-end rule) + §12bis.B (peak moments).
// Skill `zeet-motion-system` §12 (Peak moments — 1 anim riche par peak).
// Skill `zeet-micro-copy` (rider direct camarade).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Helper pratique. `deliveries` = nb courses livrées, `earnings` = gains
/// FCFA, `distanceKm` = km parcourus (optionnel), `ratingAvg` = note
/// moyenne /5 (optionnel). `isRecord` ajoute copy "Record battu !".
///
/// En mode reduceMotion (`MediaQuery.disableAnimations`), la cascade
/// est desactivee et toutes les valeurs s'affichent directement.
Future<void> showEndOfDayRecapSheet(
  BuildContext context, {
  required int deliveries,
  required num earnings,
  num? distanceKm,
  num? ratingAvg,
  bool isRecord = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (BuildContext ctx) => _EndOfDayRecapSheet(
      deliveries: deliveries,
      earnings: earnings,
      distanceKm: distanceKm,
      ratingAvg: ratingAvg,
      isRecord: isRecord,
    ),
  );
}

class _EndOfDayRecapSheet extends StatefulWidget {
  const _EndOfDayRecapSheet({
    required this.deliveries,
    required this.earnings,
    required this.distanceKm,
    required this.ratingAvg,
    required this.isRecord,
  });

  final int deliveries;
  final num earnings;
  final num? distanceKm;
  final num? ratingAvg;
  final bool isRecord;

  @override
  State<_EndOfDayRecapSheet> createState() => _EndOfDayRecapSheetState();
}

class _EndOfDayRecapSheetState extends State<_EndOfDayRecapSheet> {
  // Valeurs animées en cascade : 0 puis vraies valeurs avec délai entre chaque.
  int _displayedDeliveries = 0;
  num _displayedEarnings = 0;
  num _displayedDistance = 0;
  num _displayedRating = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Haptic success au mount (skill `zeet-motion-system` §10).
      HapticFeedback.lightImpact();

      // Respect reduceMotion : pas de cascade, affichage direct des
      // valeurs (skill `zeet-motion-system` §14).
      final bool reduceMotion =
          MediaQuery.of(context).disableAnimations;

      if (reduceMotion) {
        if (!mounted) return;
        setState(() {
          _displayedDeliveries = widget.deliveries;
          _displayedEarnings = widget.earnings;
          _displayedDistance = widget.distanceKm ?? 0;
          _displayedRating = widget.ratingAvg ?? 0;
        });
        return;
      }

      // Cascade staggered : 200ms entre chaque KPI (skill `zeet-neuro-ux`
      // §12bis.A — chaque révélation = micro-shot dopaminergique).
      // Haptic light a chaque chiffre qui apparait (skill parent) pour
      // creer une memoire tactile distincte par KPI.
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        HapticFeedback.selectionClick();
        setState(() => _displayedDeliveries = widget.deliveries);
      });
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        HapticFeedback.selectionClick();
        setState(() => _displayedEarnings = widget.earnings);
      });
      if (widget.distanceKm != null) {
        Future<void>.delayed(const Duration(milliseconds: 550), () {
          if (!mounted) return;
          HapticFeedback.selectionClick();
          setState(() => _displayedDistance = widget.distanceKm!);
        });
      }
      if (widget.ratingAvg != null) {
        Future<void>.delayed(const Duration(milliseconds: 750), () {
          if (!mounted) return;
          HapticFeedback.selectionClick();
          setState(() => _displayedRating = widget.ratingAvg!);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final String title = widget.isRecord ? 'Record battu !' : 'Belle journée !';
    final String subtitle = widget.isRecord
        ? "Tu enchaines, on adore. À demain pour casser la baraque ?"
        : 'Récap de ta session. À la prochaine.';

    return SafeArea(
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 24.h),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Titre + emoji discret.
            Center(
              child: Text(
                title,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Center(
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style:
                    tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            SizedBox(height: 24.h),

            // KPI 1 : courses.
            _RecapKpi(
              icon: Icons.delivery_dining_rounded,
              color: ZeetColors.primary,
              label: 'courses',
              value: _displayedDeliveries,
              suffix: '',
            ),
            SizedBox(height: 12.h),

            // KPI 2 : gains.
            _RecapKpi(
              icon: Icons.account_balance_wallet_rounded,
              color: ZeetColors.success,
              label: 'gagnés',
              value: _displayedEarnings,
              suffix: ' FCFA',
              big: true,
            ),

            // KPI 3 : distance (optionnel — masqué si non fourni).
            if (widget.distanceKm != null) ...<Widget>[
              SizedBox(height: 12.h),
              _RecapKpi(
                icon: Icons.route_rounded,
                color: ZeetColors.info,
                label: 'parcourus',
                value: _displayedDistance,
                suffix: ' km',
                fractionDigits: 1,
              ),
            ],

            // KPI 4 : note moyenne (optionnel).
            if (widget.ratingAvg != null && widget.ratingAvg! > 0) ...<Widget>[
              SizedBox(height: 12.h),
              _RecapKpi(
                icon: Icons.star_rounded,
                color: ZeetColors.warning,
                label: '/5 en moyenne',
                value: _displayedRating,
                suffix: '',
                fractionDigits: 1,
              ),
            ],

            SizedBox(height: 24.h),

            // CTA dismiss — tone rider direct camarade ("A demain !").
            ZeetButton.primary(
              label: 'À demain !',
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne KPI : icône colorée + rolling counter + label.
class _RecapKpi extends StatelessWidget {
  const _RecapKpi({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.suffix = '',
    this.fractionDigits = 0,
    this.big = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final num value;
  final String suffix;
  final int fractionDigits;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, color: color, size: big ? 24 : 20),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                ZeetRollingCounter(
                  value: value,
                  fractionDigits: fractionDigits,
                  suffix: suffix,
                  style: TextStyle(
                    color: color,
                    fontSize: big ? 26.sp : 20.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
