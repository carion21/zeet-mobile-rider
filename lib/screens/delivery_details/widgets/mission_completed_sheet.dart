// lib/screens/delivery_details/widgets/mission_completed_sheet.dart
//
// Peak moment "fin de course" — modal bottom sheet affichée juste après
// que le rider valide la livraison (ou un signalement "non livrée"). Joue
// la chorégraphie peak-end :
//   1. Checkmark scale 0.6 → 1.0 sur 300ms (expressive)
//   2. +150ms : rolling counter "+X FCFA" sur 450ms
//   3. Haptic success synchro
//
// Skill `zeet-neuro-ux` §8 (peak-end rule) + §12bis.B (peak moments
// amplifiés par motion) + §12bis.I (completion satisfaction).
// Skill `zeet-motion-system` §12 (Peak moments).
// Skill `zeet-micro-copy` (rider direct camarade).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Helper pratique pour pousser la sheet via `showModalBottomSheet`.
/// `fee` = montant gagné sur cette course, en FCFA. `success` = true si
/// livraison aboutie, false si signalée non livrée (variante visuelle
/// + copy).
Future<void> showMissionCompletedSheet(
  BuildContext context, {
  required num fee,
  bool success = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (BuildContext ctx) =>
        _MissionCompletedSheet(fee: fee, success: success),
  );
}

class _MissionCompletedSheet extends StatefulWidget {
  const _MissionCompletedSheet({required this.fee, required this.success});

  final num fee;
  final bool success;

  @override
  State<_MissionCompletedSheet> createState() => _MissionCompletedSheetState();
}

class _MissionCompletedSheetState extends State<_MissionCompletedSheet>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final Animation<double> _checkScale;
  num _displayedFee = 0;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: ZeetCurves.expressive,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 1. Haptic success synchro avec checkmark.
      HapticFeedback.lightImpact();
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
    final String title =
        widget.success ? 'Belle course !' : 'Signalement enregistré';
    final String subtitle = widget.success
        ? 'Course terminée. À la prochaine !'
        : 'Le client et le restaurant sont notifiés.';

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
            // 1. Checkmark animé.
            ScaleTransition(
              scale: _checkScale,
              child: Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 38),
              ),
            ),
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

            // 4. CTA dismiss.
            ZeetButton.primary(
              label: 'Continuer',
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
