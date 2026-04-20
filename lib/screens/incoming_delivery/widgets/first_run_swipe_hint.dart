// lib/screens/incoming_delivery/widgets/first_run_swipe_hint.dart
//
// Overlay coach-mark affiche au-dessus du SlideToAcceptButton la PREMIERE
// fois qu'un rider voit un IncomingDelivery. Une fleche oscillante + texte
// "Glisse pour accepter" renforcent la memoire musculaire du geste.
//
// Skill `zeet-gesture-grammar` §6 (discoverability) — un geste cache
// n'existe pas. SharedPreferences flag `slide_to_accept_coach_v1` evite
// le re-run.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kCoachShownPrefKey = 'slide_to_accept_coach_v1';

class FirstRunSwipeHint extends StatefulWidget {
  /// Texte d'aide. Court et direct (skill micro-copy).
  final String label;

  const FirstRunSwipeHint({
    super.key,
    this.label = 'Glisse vers la droite pour accepter',
  });

  @override
  State<FirstRunSwipeHint> createState() => _FirstRunSwipeHintState();
}

class _FirstRunSwipeHintState extends State<FirstRunSwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _maybeShow();
  }

  Future<void> _maybeShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool(_kCoachShownPrefKey) ?? false;
      if (alreadyShown) return;
      if (!mounted) return;
      setState(() => _visible = true);
      _controller.repeat(reverse: true);
      // Marquer immediatement vu pour ne plus jamais re-afficher.
      await prefs.setBool(_kCoachShownPrefKey, true);
      // Auto-dismiss apres 6s (le rider a la sonnerie pour pousser).
      await Future<void>.delayed(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() => _visible = false);
    } catch (_) {
      // SharedPreferences indispo : skip silencieusement.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _visible ? 1 : 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Fleche qui rebondit doucement vers la droite (signal du geste).
            if (!reduceMotion)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(_controller.value * 8, 0),
                    child: const Icon(
                      Icons.swipe_right_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  );
                },
              )
            else
              const Icon(
                Icons.swipe_right_rounded,
                color: Colors.white,
                size: 22,
              ),
            SizedBox(width: 8.w),
            Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
