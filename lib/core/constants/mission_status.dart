// lib/core/constants/mission_status.dart
//
// Source de verite unique pour le status mission cote rider.
//
// Avant : 3 helpers locaux (mission_card, deliveries, delivery_details)
// dupliquaient la logique avec des labels divergents (« Recuperee » vs
// « En collecte ») et des couleurs hardcodees (`Color(0xFF...)`).
//
// Apres : un seul mapping `MissionStatusVisual.resolve(rawApi)` qui
// renvoie color + icon + label long + label court, ancres sur les tokens
// `ZeetColors`. Tone rider direct (skill `zeet-micro-copy`).

import 'package:flutter/material.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Statut d'une mission tel qu'il transite cote API rider.
enum MissionStatusKind {
  pending,
  assigned,
  accepted,
  collecting,
  collected,
  pickedUp,
  delivering,
  delivered,
  notDelivered,
  cancelled,
  rejected,
  unknown,
}

/// Visuel complet d'un status mission.
///
/// Regle ZEET : un status n'est jamais qu'une couleur — il faut couleur
/// + icone + label (cf. `zeet-pos-ergonomics` §6, glanceability).
class MissionStatusVisual {
  const MissionStatusVisual({
    required this.kind,
    required this.color,
    required this.icon,
    required this.label,
    required this.shortLabel,
  });

  /// Statut canonique resolu.
  final MissionStatusKind kind;

  /// Couleur principale (texte + accent du chip).
  final Color color;

  /// Icone associee (Material).
  final IconData icon;

  /// Label long, vue detail rider (« En route vers le client »).
  final String label;

  /// Label court, badge dense liste (« En route client »).
  final String shortLabel;

  /// Resout le visuel a partir du raw status renvoye par l'API.
  ///
  /// Tolere :
  /// - `snake_case` (`picked_up`) et `kebab-case` (`not-delivered`) ;
  /// - majuscules / minuscules ;
  /// - `null` ou chaine vide → status « inconnu ».
  static MissionStatusVisual resolve(String? rawStatus) {
    final normalized = (rawStatus ?? '').trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'pending':
      case 'assigned':
        return const MissionStatusVisual(
          kind: MissionStatusKind.assigned,
          color: ZeetColors.warning,
          icon: Icons.notifications_active,
          label: 'Nouvelle livraison',
          shortLabel: 'Nouvelle',
        );
      case 'accepted':
        return const MissionStatusVisual(
          kind: MissionStatusKind.accepted,
          color: ZeetColors.info,
          icon: Icons.directions_bike_rounded,
          label: 'En route vers le resto',
          shortLabel: 'Acceptee',
        );
      case 'collecting':
        return const MissionStatusVisual(
          kind: MissionStatusKind.collecting,
          color: ZeetColors.collecting,
          icon: Icons.shopping_bag_rounded,
          label: 'En collecte chez le resto',
          shortLabel: 'En collecte',
        );
      case 'collected':
      case 'picked_up':
        return const MissionStatusVisual(
          kind: MissionStatusKind.collected,
          color: ZeetColors.primary,
          icon: Icons.shopping_bag_rounded,
          label: 'En route vers le client',
          shortLabel: 'Recuperee',
        );
      case 'delivering':
        return const MissionStatusVisual(
          kind: MissionStatusKind.delivering,
          color: ZeetColors.primary,
          icon: Icons.delivery_dining_rounded,
          label: 'En livraison',
          shortLabel: 'En livraison',
        );
      case 'delivered':
        return const MissionStatusVisual(
          kind: MissionStatusKind.delivered,
          color: ZeetColors.success,
          icon: Icons.check_circle_rounded,
          label: 'Livree',
          shortLabel: 'Livree',
        );
      case 'not_delivered':
        return const MissionStatusVisual(
          kind: MissionStatusKind.notDelivered,
          color: ZeetColors.danger,
          icon: Icons.report_rounded,
          label: 'Non livree',
          shortLabel: 'Non livree',
        );
      case 'cancelled':
      case 'canceled':
        return const MissionStatusVisual(
          kind: MissionStatusKind.cancelled,
          color: ZeetColors.inkMuted,
          icon: Icons.cancel_rounded,
          label: 'Annulee',
          shortLabel: 'Annulee',
        );
      case 'rejected':
        return const MissionStatusVisual(
          kind: MissionStatusKind.rejected,
          color: ZeetColors.inkMuted,
          icon: Icons.cancel_rounded,
          label: 'Refusee',
          shortLabel: 'Refusee',
        );
      default:
        return const MissionStatusVisual(
          kind: MissionStatusKind.unknown,
          color: ZeetColors.inkMuted,
          icon: Icons.help_outline_rounded,
          label: 'Statut inconnu',
          shortLabel: 'Inconnu',
        );
    }
  }
}
