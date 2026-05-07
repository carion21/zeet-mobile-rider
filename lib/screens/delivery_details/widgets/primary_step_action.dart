// lib/screens/delivery_details/widgets/primary_step_action.dart
//
// Wrapper léger autour de `ZeetSwipeToConfirm` (zeet_ui) — adapte le label
// et la couleur selon le statut delivery courant.
//
// Mapping :
// - `accepted`             → "Glisser pour récupérer" (orange primary)
// - `collected` / variantes → "Glisser pour livrer"   (vert success)
// - autres                 → SizedBox.shrink (rien à confirmer ici)
//
// Pourquoi un slide-to-confirm sur ces deux étapes ? Audit UX :
// - geste continu = pas de double-tap accidentel à moto / sous casque
// - hit target ≥ 64dp (height 64 + track entier swipeable)
// - haptics progressifs déjà gérés par ZeetSwipeToConfirm
//   (tap au pickup, warning à 75%, success à 100%) → ZeetHaptics.success()
//   au confirm équivaut au heavy attendu côté action handler.
//
// Le caller fournit `onConfirm` qui doit exécuter l'action métier (collect
// ou deliver). Le widget ne change pas la state machine ni les flux.

import 'package:flutter/material.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// État cible du flow rider — pilote label et couleur du swipe.
enum PrimaryStepActionKind {
  /// Phase Récupération (mission acceptée).
  collect,

  /// Phase Trajet (commande collectée, en route vers le client).
  deliver,
}

class PrimaryStepAction extends StatelessWidget {
  /// Statut delivery brut (`mission.status`).
  final String? missionStatus;

  /// Callback invoqué après slide validé. Fait le _heavy haptic + appelle
  /// l'action API (collect / deliver) côté orchestrateur.
  final VoidCallback onConfirm;

  /// `false` quand une action est déjà en vol (verrou `_busy`) ou que le
  /// provider est en `isActionLoading`.
  final bool enabled;

  /// Hauteur du slider — défaut 64 (≥ 64dp tactile, gants moto OK).
  final double height;

  const PrimaryStepAction({
    super.key,
    required this.missionStatus,
    required this.onConfirm,
    this.enabled = true,
    this.height = 64,
  });

  PrimaryStepActionKind? _kindFor(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.replaceAll('_', '-');
    switch (s) {
      case 'accepted':
        return PrimaryStepActionKind.collect;
      case 'collected':
      case 'collecting':
      case 'on-the-way':
      case 'picked-up':
      case 'delivering':
        return PrimaryStepActionKind.deliver;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kindFor(missionStatus);
    if (kind == null) return const SizedBox.shrink();

    late final String label;
    late final String thresholdLabel;
    late final String confirmedLabel;
    late final Color fillColor;

    switch (kind) {
      case PrimaryStepActionKind.collect:
        label = 'Glisser pour récupérer';
        thresholdLabel = 'Relâche pour confirmer la récup';
        confirmedLabel = 'Commande récupérée';
        fillColor = ZeetColors.primary;
        break;
      case PrimaryStepActionKind.deliver:
        label = 'Glisser pour livrer';
        thresholdLabel = 'Relâche pour confirmer la livraison';
        confirmedLabel = 'Livraison confirmée';
        fillColor = ZeetColors.success;
        break;
    }

    return ZeetSwipeToConfirm(
      // Reset visuel sur changement d'étape (sinon l'animation de retour
      // peut être perçue comme un "rejet").
      key: ValueKey<PrimaryStepActionKind>(kind),
      onConfirmed: () async {
        // Haptic fort en plus du `success` interne du swipe — confirme une
        // action irréversible côté rider (équivalent ZeetHaptics.heavy()
        // utilisé historiquement par les boutons d'action).
        await ZeetHaptics.heavy();
        onConfirm();
      },
      label: label,
      thresholdLabel: thresholdLabel,
      confirmedLabel: confirmedLabel,
      height: height,
      enabled: enabled,
      fillColor: fillColor,
    );
  }
}
