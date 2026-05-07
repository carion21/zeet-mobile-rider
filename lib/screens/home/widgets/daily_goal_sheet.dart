// lib/screens/home/widgets/daily_goal_sheet.dart
//
// Bottom sheet pour regler/effacer l'objectif courses/jour rider.
// Presets : 3 / 5 / 8 / 10 + champ libre. Bouton "Retirer l'objectif"
// en bas si deja defini.
//
// Skill `zeet-neuro-ux` §11 (peak moment, gamification opt-in) +
// `zeet-pos-ergonomics` §1 (hit target >= 56pt).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/providers/daily_goal_provider.dart';
import 'package:zeet_ui/zeet_ui.dart';

Future<void> showDailyGoalSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _DailyGoalSheet(),
  );
}

class _DailyGoalSheet extends ConsumerStatefulWidget {
  const _DailyGoalSheet();

  @override
  ConsumerState<_DailyGoalSheet> createState() => _DailyGoalSheetState();
}

class _DailyGoalSheetState extends ConsumerState<_DailyGoalSheet> {
  static const List<int> _presets = <int>[3, 5, 8, 10];
  late final TextEditingController _customCtrl;

  @override
  void initState() {
    super.initState();
    final int current = ref.read(dailyGoalProvider);
    _customCtrl = TextEditingController(
      text: current > 0 && !_presets.contains(current) ? '$current' : '',
    );
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply(int value) async {
    ZeetHaptics.tap();
    await ref.read(dailyGoalProvider.notifier).setGoal(value);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    ZeetHaptics.tap();
    await ref.read(dailyGoalProvider.notifier).unset();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final int current = ref.watch(dailyGoalProvider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface =
        isDark ? ZeetColors.surfaceAltDark : ZeetColors.surface;
    final Color ink = isDark ? ZeetColors.inkDark : ZeetColors.ink;
    final Color muted =
        isDark ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;
    final Color line = isDark ? ZeetColors.lineDark : ZeetColors.line;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                children: <Widget>[
                  Icon(Icons.flag_rounded,
                      color: ZeetColors.primary, size: 22.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Mon objectif du jour',
                    style: TextStyle(
                      color: ink,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                'Choisis un nombre de courses à viser aujourd\'hui.',
                style: TextStyle(color: muted, fontSize: 13.sp),
              ),
              SizedBox(height: 18.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                children: _presets.map((int v) {
                  final bool selected = v == current;
                  return _PresetChip(
                    value: v,
                    selected: selected,
                    onTap: () => _apply(v),
                  );
                }).toList(),
              ),
              SizedBox(height: 18.h),
              Text(
                'Ou nombre libre',
                style: TextStyle(
                  color: muted,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _customCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                      style: TextStyle(
                        color: ink,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ex. 7',
                        hintStyle: TextStyle(color: muted),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 12.h),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(
                              color: ZeetColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZeetColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size(72.w, 48.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    onPressed: () {
                      final int? parsed =
                          int.tryParse(_customCtrl.text.trim());
                      if (parsed == null || parsed <= 0) return;
                      _apply(parsed);
                    },
                    child: Text(
                      'OK',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (current > 0) ...<Widget>[
                SizedBox(height: 18.h),
                Center(
                  child: TextButton.icon(
                    onPressed: _remove,
                    icon: Icon(Icons.close_rounded,
                        color: ZeetColors.danger, size: 18.sp),
                    label: Text(
                      'Retirer l\'objectif',
                      style: TextStyle(
                        color: ZeetColors.danger,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = selected
        ? ZeetColors.primary
        : (isDark ? ZeetColors.surfaceDark : ZeetColors.surfaceAlt);
    final Color fg = selected
        ? Colors.white
        : (isDark ? ZeetColors.inkDark : ZeetColors.ink);
    final Color border = selected
        ? ZeetColors.primary
        : (isDark ? ZeetColors.lineDark : ZeetColors.line);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        constraints: BoxConstraints(minWidth: 64.w, minHeight: 48.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          '$value courses',
          style: TextStyle(
            color: fg,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
