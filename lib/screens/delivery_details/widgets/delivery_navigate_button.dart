// lib/screens/delivery_details/widgets/delivery_navigate_button.dart
//
// CTA "Naviguer vers le restaurant/client" — ouvre Google Maps externe
// en navigation guidée. Variant pickup (orange/primary) ou dropoff
// (vert/success). Utilise ZeetButton pleine largeur du design system ZEET.
//
// Usage :
//   DeliveryNavigateButton(
//     mission: mission,
//     variant: NavigateVariant.pickup,
//   )

import 'package:flutter/material.dart';
import 'package:rider/core/utils/maps_launcher.dart';
import 'package:rider/models/mission_model.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Cible de la navigation : pickup = restaurant, dropoff = client.
enum NavigateVariant { pickup, dropoff }

class DeliveryNavigateButton extends StatelessWidget {
  final Mission mission;
  final NavigateVariant variant;

  const DeliveryNavigateButton({
    super.key,
    required this.mission,
    required this.variant,
  });

  /// URL backend selon variant. Le core renvoie déjà ces URLs (cf.
  /// `buildGoogleMapsNavigationUrl` core-system) — on les consomme telles
  /// quelles. Fallback : reconstruction côté app via `lat/lng`.
  String? get _backendUrl => variant == NavigateVariant.pickup
      ? mission.navigationPickupUrl
      : mission.navigationDeliveryUrl;

  /// Adresse cible selon variant pour fallback de reconstruction locale.
  MissionAddress? get _address => variant == NavigateVariant.pickup
      ? mission.pickupAddress
      : mission.dropoffAddress;

  /// Label FR conforme `zeet-tone-of-voice-fr` : direct, actionnable.
  String get _label => variant == NavigateVariant.pickup
      ? 'Naviguer vers le restaurant'
      : 'Naviguer vers le client';

  /// Variant ZeetButton : primary (orange ZEET) pour resto, success (vert)
  /// pour client — cohérent avec les boutons d'appel `delivery_call_actions`.
  ZeetButtonVariant get _zeetVariant => variant == NavigateVariant.pickup
      ? ZeetButtonVariant.primary
      : ZeetButtonVariant.success;

  /// Active si on a une URL backend non vide OU des coords valides en
  /// fallback. Sinon le bouton reste affiché mais désactivé pour ne pas
  /// surprendre le rider qui chercherait l'action.
  bool get _isEnabled {
    final resolved = resolveNavUrl(
      backendUrl: _backendUrl,
      lat: _address?.lat,
      lng: _address?.lng,
    );
    return resolved != null;
  }

  @override
  Widget build(BuildContext context) {
    return ZeetButton(
      label: _label,
      variant: _zeetVariant,
      size: ZeetButtonSize.lg,
      icon: Icons.navigation,
      fullWidth: true,
      semanticLabel: _isEnabled
          ? '$_label avec Google Maps'
          : '$_label — coordonnées indisponibles',
      onPressed: _isEnabled
          ? () => launchMapsNavigation(
                backendUrl: _backendUrl,
                lat: _address?.lat,
                lng: _address?.lng,
                context: context,
              )
          : null,
    );
  }
}
