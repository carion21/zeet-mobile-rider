// lib/core/constants/mission_status.dart
//
// Metadata UI (icone + label) pour un statut mission cote rider. La couleur
// vient maintenant du backend (`last_delivery_status.color`) et n'est plus
// derivee ici — la seule regle cote mobile reste : "status = couleur API +
// icone + label" (skill `zeet-pos-ergonomics` §6, glanceability).
//
// Tone rider direct (skill `zeet-micro-copy`).

import 'package:flutter/material.dart';

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

/// Metadata visuelle (hors couleur) pour un status mission.
///
/// La couleur est fournie par le champ `color` de l'API ; ce bundle
/// complete avec l'icone et le label (court/long) qui restent cote
/// client pour garder une voix produit coherente.
class MissionStatusVisual {
  const MissionStatusVisual({
    required this.kind,
    required this.icon,
    required this.label,
    required this.shortLabel,
  });

  /// Statut canonique resolu.
  final MissionStatusKind kind;

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
          icon: Icons.notifications_active,
          label: 'Nouvelle livraison',
          shortLabel: 'Nouvelle',
        );
      case 'accepted':
        return const MissionStatusVisual(
          kind: MissionStatusKind.accepted,
          icon: Icons.directions_bike_rounded,
          label: 'En route vers le resto',
          shortLabel: 'Acceptee',
        );
      case 'collecting':
        return const MissionStatusVisual(
          kind: MissionStatusKind.collecting,
          icon: Icons.shopping_bag_rounded,
          label: 'En collecte chez le resto',
          shortLabel: 'En collecte',
        );
      case 'collected':
      case 'picked_up':
        return const MissionStatusVisual(
          kind: MissionStatusKind.collected,
          icon: Icons.shopping_bag_rounded,
          label: 'En route vers le client',
          shortLabel: 'Recuperee',
        );
      case 'delivering':
      case 'on_the_way':
        return const MissionStatusVisual(
          kind: MissionStatusKind.delivering,
          icon: Icons.delivery_dining_rounded,
          label: 'En livraison',
          shortLabel: 'En livraison',
        );
      case 'delivered':
        return const MissionStatusVisual(
          kind: MissionStatusKind.delivered,
          icon: Icons.check_circle_rounded,
          label: 'Livree',
          shortLabel: 'Livree',
        );
      case 'not_delivered':
        return const MissionStatusVisual(
          kind: MissionStatusKind.notDelivered,
          icon: Icons.report_rounded,
          label: 'Non livree',
          shortLabel: 'Non livree',
        );
      case 'cancelled':
      case 'canceled':
        return const MissionStatusVisual(
          kind: MissionStatusKind.cancelled,
          icon: Icons.cancel_rounded,
          label: 'Annulee',
          shortLabel: 'Annulee',
        );
      case 'rejected':
        return const MissionStatusVisual(
          kind: MissionStatusKind.rejected,
          icon: Icons.cancel_rounded,
          label: 'Refusee',
          shortLabel: 'Refusee',
        );
      default:
        return const MissionStatusVisual(
          kind: MissionStatusKind.unknown,
          icon: Icons.help_outline_rounded,
          label: 'Statut inconnu',
          shortLabel: 'Inconnu',
        );
    }
  }
}
