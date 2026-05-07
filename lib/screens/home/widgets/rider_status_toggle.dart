// lib/screens/home/widgets/rider_status_toggle.dart
//
// Indicateur tap-able du statut online/offline du rider (centre dans le
// header). Tap → confirmation modale → toggle. Transition fade+slide via
// ZeetStateSwitcher quand on bascule.
//
// Skill `zeet-pos-ergonomics` §1 — actions récurrentes ≤ 1 tap : passer
// offline depuis le home en 1 tap au lieu de 2 (avant : Profil → toggle).
// Hit zone élargie à 56×120 pour gants.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/widgets/app_popup.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:rider/screens/stats/widgets/end_of_day_trigger.dart';
import 'package:zeet_ui/zeet_ui.dart';

class RiderStatusToggle extends ConsumerStatefulWidget {
  const RiderStatusToggle({super.key});

  @override
  ConsumerState<RiderStatusToggle> createState() => _RiderStatusToggleState();
}

class _RiderStatusToggleState extends ConsumerState<RiderStatusToggle> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;
    final bool wasOnline = ref.read(isOnlineProvider);

    ZeetHaptics.tap();

    final confirmed = await AppPopup.showConfirmation(
      context: context,
      title: wasOnline ? 'Passer hors-ligne ?' : 'Repasser en ligne ?',
      message: wasOnline
          ? 'Tu vas passer hors-ligne — tu ne recevras plus de missions. Continuer ?'
          : 'Te remettre en ligne pour recevoir des missions ?',
      confirmLabel: 'Confirmer',
      cancelLabel: 'Annuler',
      isDestructive: wasOnline,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(statusProvider.notifier).toggleOnline();
    if (!mounted) return;
    setState(() => _busy = false);

    if (result['success'] == true) {
      AppToast.showSuccess(
        context: context,
        message: result['message'] as String,
      );
      // Peak-end rule : si on vient de passer offline avec >= 1 livraison
      // dans la journée, on déclenche le récap fin-de-journée.
      if (wasOnline && mounted) {
        await EndOfDayTrigger.maybeShow(context, ref);
      }
    } else {
      AppToast.showError(
        context: context,
        message: result['message'] as String,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final bool isOnline = ref.watch(isOnlineProvider);

    return Semantics(
      button: true,
      label: isOnline
          ? 'Statut en ligne. Appuie pour passer hors-ligne.'
          : 'Statut hors-ligne. Appuie pour repasser en ligne.',
      child: InkWell(
        onTap: _onTap,
        borderRadius: BorderRadius.circular(ZeetRadius.pill),
        // Hit zone POS : 56pt minimum en hauteur (skill §1).
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: ZeetSpacing.x3,
            vertical: ZeetSpacing.x1,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Statut',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 12.sp,
                ),
              ),
              const SizedBox(height: ZeetSpacing.x1),
              ZeetStateSwitcher(
                stateKey: isOnline,
                child: Row(
                  key: ValueKey<bool>(isOnline),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? ZeetColors.success : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: ZeetSpacing.x2),
                    Text(
                      isOnline ? 'En ligne' : 'Hors ligne',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
