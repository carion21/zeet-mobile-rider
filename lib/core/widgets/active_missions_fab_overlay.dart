// lib/core/widgets/active_missions_fab_overlay.dart
//
// FAB persistant globalement affiché quand le rider a au moins une
// mission `ongoing`. Inspiré du `ActiveOrdersFabOverlay` côté client
// (Zeigarnik étendu — la course inachevée reste visible hors detail).
//
// Skill `zeet-neuro-ux` §6 (Effet Zeigarnik) + §6bis (Zeigarnik amplifié).
// Skill `zeet-pos-ergonomics` §1 (hit target ≥56pt).
//
// V1 : visible dès qu'il y a > 0 missions ongoing, sans route observer
// (donc visible aussi sur l'écran liste — pas optimal mais inoffensif).
// V2 : ajouter `route_observer_provider.dart` pour masquer sur les
// écrans qui affichent déjà la liste (deliveries, deliveries_history).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rider/models/mission_model.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class ActiveMissionsFabOverlay extends ConsumerWidget {
  const ActiveMissionsFabOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Mission> ongoing = ref.watch(ongoingMissionsProvider);
    if (ongoing.isEmpty) return const SizedBox.shrink();

    final Mission first = ongoing.first;
    final int count = ongoing.length;
    final EdgeInsets safe = MediaQuery.of(context).padding;

    return Positioned(
      right: 16,
      bottom: safe.bottom + 24,
      child: _PulsingFab(
        count: count,
        onTap: () {
          HapticFeedback.selectionClick();
          Routes.pushMissionDetails(missionId: first.id.toString());
        },
      ),
    );
  }
}

class _PulsingFab extends StatefulWidget {
  const _PulsingFab({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  State<_PulsingFab> createState() => _PulsingFabState();
}

class _PulsingFabState extends State<_PulsingFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final Widget body = Material(
      color: ZeetColors.primary,
      shape: const StadiumBorder(),
      elevation: 6,
      shadowColor: ZeetColors.primary.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.directions_bike_rounded,
                color: ZeetColors.surface,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                widget.count == 1
                    ? 'Course en cours'
                    : '${widget.count} courses en cours',
                style: const TextStyle(
                  color: ZeetColors.surface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: ZeetColors.surface,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );

    if (reduceMotion) return body;
    return AnimatedBuilder(
      animation: _scale,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(scale: _scale.value, child: child);
      },
      child: body,
    );
  }
}
