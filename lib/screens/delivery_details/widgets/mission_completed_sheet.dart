// lib/screens/delivery_details/widgets/mission_completed_sheet.dart
//
// Peak moment "fin de course" — modal bottom sheet affichée juste après
// que le rider valide la livraison (ou un signalement "non livrée"). Joue
// la chorégraphie peak-end :
//   1. Checkmark scale 0.6 → 1.0 sur ZeetMotion.lg (expressive)
//   2. +150ms : rolling counter "+X FCFA" via ZeetRollingCounter
//   3. Haptic success synchro (lightImpact x1, ou x3 sur jalon 5e/10e/20e)
//
// Plan §3.5 polish :
//   - Copy ZEET varié (rotation 5 messages success / 3 failure)
//   - CTA "Encore une !" sur succès (énergie volontaire)
//   - Jalons : checkmark plus gros + haptic triple sur 5e/10e/20e mission
//
// Skill `zeet-neuro-ux` §8 (peak-end rule) + §12bis.B (peak moments
// amplifiés par motion) + §12bis.I (completion satisfaction).
// Skill `zeet-motion-system` §12 (Peak moments).
// Skill `zeet-micro-copy` (rider direct camarade).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/config/app_config.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Messages success rotatifs — ton ZEET FR direct (skill
/// `zeet-tone-of-voice-fr` + `zeet-micro-copy`). Sélection aléatoire à
/// chaque ouverture pour éviter l'effet bot.
const List<({String title, String subtitle})> _kSuccessCopy = [
  (title: 'Belle course !', subtitle: 'Course terminée. À la prochaine !'),
  (title: 'On enchaîne ?', subtitle: 'Encore une de bouclée. Beau rythme.'),
  (title: 'T’es solide.', subtitle: 'Livraison validée. Continue comme ça.'),
  (title: 'Pile à l’heure.', subtitle: 'Mission OK. Le client est content.'),
  (title: 'Et de plus !', subtitle: 'Une de plus au compteur. Cadence top.'),
];

/// Messages failure — ton calme, factuel, pas de blâme.
const List<({String title, String subtitle})> _kFailureCopy = [
  (title: 'Signalement enregistré', subtitle: 'Le client et le restaurant sont notifiés.'),
  (title: 'Bien noté.', subtitle: 'On a transmis l’info. Pas de souci.'),
  (title: 'C’est pris en compte.', subtitle: 'L’équipe support prend le relais.'),
];

/// Helper pratique pour pousser la sheet via `showModalBottomSheet`.
/// `fee` = montant gagné sur cette course, en FCFA. `success` = true si
/// livraison aboutie, false si signalée non livrée (variante visuelle
/// + copy). `deliveriesToday` permet le marquage jalon (5e/10e/20e
/// → célébration amplifiée).
Future<void> showMissionCompletedSheet(
  BuildContext context, {
  required num fee,
  bool success = true,
  int deliveriesToday = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (BuildContext ctx) => _MissionCompletedSheet(
      fee: fee,
      success: success,
      deliveriesToday: deliveriesToday,
    ),
  );
}

class _MissionCompletedSheet extends StatefulWidget {
  const _MissionCompletedSheet({
    required this.fee,
    required this.success,
    required this.deliveriesToday,
  });

  final num fee;
  final bool success;
  final int deliveriesToday;

  @override
  State<_MissionCompletedSheet> createState() => _MissionCompletedSheetState();
}

class _MissionCompletedSheetState extends State<_MissionCompletedSheet>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final Animation<double> _checkScale;
  late final ({String title, String subtitle}) _copy;
  late final bool _isMilestone;
  num _displayedFee = 0;

  @override
  void initState() {
    super.initState();
    // Rotation aléatoire du copy (skill `zeet-micro-copy` — éviter l'effet
    // bot, varier l'expérience pour amortir la répétition quotidienne).
    final pool = widget.success ? _kSuccessCopy : _kFailureCopy;
    _copy = pool[math.Random().nextInt(pool.length)];
    // Jalon : 1ère, 5e, 10e, 20e, 50e mission du jour.
    _isMilestone = widget.success &&
        AppConfig.milestoneCounts.contains(widget.deliveriesToday);

    _checkController = AnimationController(
      vsync: this,
      duration: ZeetMotion.lg,
    );
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: ZeetCurves.expressive,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Haptic synchro. Sur jalon : burst triple pour amplifier
      // la récompense (skill `zeet-neuro-ux` §completion-satisfaction).
      if (_isMilestone) {
        ZeetHaptics.success();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        ZeetHaptics.success();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        ZeetHaptics.heavy();
      } else {
        ZeetHaptics.success();
      }
      _checkController.forward();
      // 2. +150ms : déclenche le rolling counter.
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        setState(() => _displayedFee = widget.fee);
      });
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final Color accent =
        widget.success ? ZeetColors.success : ZeetColors.warning;
    final IconData icon =
        widget.success ? Icons.check_rounded : Icons.report_rounded;
    final String title = _copy.title;
    final String subtitle = _copy.subtitle;
    // Jalon : checkmark plus gros (84 vs 72), badge "5e du jour" subtle.
    final double checkSize = _isMilestone ? 84.w : 72.w;
    final String ctaLabel = widget.success ? 'Encore une' : 'OK';

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
          children: <Widget>[
            // 1. Checkmark animé (plus gros sur jalon).
            ScaleTransition(
              scale: _checkScale,
              child: Container(
                width: checkSize,
                height: checkSize,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: _isMilestone ? 44 : 38),
              ),
            ),
            // Badge jalon "Xe du jour" — célébration discrète.
            if (_isMilestone) ...<Widget>[
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: ZeetColors.primaryLight,
                  borderRadius: BorderRadius.circular(ZeetRadius.pill),
                ),
                child: Text(
                  '${widget.deliveriesToday}e du jour',
                  style: TextStyle(
                    color: ZeetColors.primary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
            SizedBox(height: 18.h),

            // 2. Titre.
            Text(
              title,
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),

            // 3. Rolling counter du gain (uniquement si succès).
            if (widget.success && widget.fee > 0) ...[
              SizedBox(height: 22.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.add_rounded, color: accent, size: 22),
                    SizedBox(width: 4.w),
                    ZeetRollingCounter(
                      value: _displayedFee,
                      suffix: ' FCFA',
                      style: TextStyle(
                        color: accent,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 22.h),

            // 4. CTA dismiss — copy direct ("Encore une" sur succès).
            ZeetButton.primary(
              label: ctaLabel,
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
