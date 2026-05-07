// lib/screens/delivery_details/widgets/delivery_progress_header.dart
//
// Header progress 3 segments — Récup → Trajet → Livraison.
//
// Affiche l'avancée de la mission selon `mission.status` :
// - `assigned` / `pending`                  → 0 segment actif
// - `accepted`                              → 1 segment actif (Récup en cours)
// - `collected` / `on-the-way` / variantes  → 2 segments actifs (Trajet en cours)
// - `delivered`                             → 3 segments actifs
// - `not-delivered` / `cancelled`           → 0 actif (échec / annulation)
//
// Tokens uniquement (ZeetColors / ZeetMotion / ZeetCurves / ZeetSpacing).
// Animation `TweenAnimationBuilder` ZeetMotion.md + ZeetCurves.decelerate
// sur la transition de chaque segment (0 → 1).
//
// Stateless. Add-only — n'impacte pas la state machine ni les actions.

import 'package:flutter/material.dart';
import 'package:rider/screens/delivery_details/steps/step_focus.dart';
import 'package:zeet_ui/zeet_ui.dart';

class DeliveryProgressHeader extends StatelessWidget {
  /// Statut delivery brut (peut être `null` pendant le chargement).
  final String? missionStatus;

  /// Hauteur de la barre de chaque segment.
  final double barHeight;

  const DeliveryProgressHeader({
    super.key,
    required this.missionStatus,
    this.barHeight = 6,
  });

  /// Index du dernier segment franchi (-1 si aucun, 0 = Récup, 1 = Trajet,
  /// 2 = Livraison). Délègue à [DeliveryStepFocus] pour la source de vérité.
  /// `delivered` est terminal mais avec progression complète → traité ici.
  int _stepIndex(String? raw) {
    if (raw == null || raw.isEmpty) return -1;
    if (raw.replaceAll('_', '-') == 'delivered') return 2;
    final focus = DeliveryStepFocusX.fromStatus(raw);
    switch (focus) {
      case DeliveryStepFocus.offer:
        return -1;
      case DeliveryStepFocus.recup:
        return 0;
      case DeliveryStepFocus.trajet:
        return 1;
      case DeliveryStepFocus.terminal:
        return -1; // not-delivered/cancelled — pas de progression
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color trackColor =
        isDarkMode ? ZeetColors.lineDark : ZeetColors.line;
    final Color activeColor = ZeetColors.primary;
    final Color labelActive =
        isDarkMode ? ZeetColors.inkDark : ZeetColors.ink;
    final Color labelInactive =
        isDarkMode ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;

    final currentIndex = _stepIndex(missionStatus);

    const labels = <String>['Récup.', 'Trajet', 'Livraison'];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZeetSpacing.x4,
        vertical: ZeetSpacing.x2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Barres animées.
          Row(
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                Expanded(
                  child: _SegmentBar(
                    target: i <= currentIndex ? 1.0 : 0.0,
                    height: barHeight,
                    activeColor: activeColor,
                    trackColor: trackColor,
                  ),
                ),
                if (i < 2) const SizedBox(width: ZeetSpacing.x2),
              ],
            ],
          ),
          const SizedBox(height: ZeetSpacing.x2),
          // Labels alignés sous chaque barre.
          Row(
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i <= currentIndex ? labelActive : labelInactive,
                      fontSize: 11,
                      fontWeight: i <= currentIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i < 2) const SizedBox(width: ZeetSpacing.x2),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Une barre de progression unique 0→1 animée.
class _SegmentBar extends StatelessWidget {
  final double target;
  final double height;
  final Color activeColor;
  final Color trackColor;

  const _SegmentBar({
    required this.target,
    required this.height,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: target, end: target),
      duration: reduceMotion ? Duration.zero : ZeetMotion.md,
      curve: ZeetCurves.decelerate,
      builder: (BuildContext _, double value, Widget? __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            color: trackColor,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(color: activeColor),
              ),
            ),
          ),
        );
      },
    );
  }
}
