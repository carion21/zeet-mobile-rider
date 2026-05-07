// lib/core/utils/maps_launcher.dart
//
// Helper minimal pour lancer Google Maps en navigation guidée externe.
// Préfère l'URL fournie par le backend (déjà construite via
// buildGoogleMapsNavigationUrl côté core), fallback construction locale
// à partir de lat/lng si l'URL backend est absente.
//
// Usage :
//   await launchMapsNavigation(
//     backendUrl: mission.navigationDeliveryUrl,
//     lat: mission.dropoffAddress?.lat,
//     lng: mission.dropoffAddress?.lng,
//     context: context,
//   );

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rider/core/widgets/toastification.dart';

/// Construit le deep-link Google Maps de navigation guidée à partir de
/// coords valides. Format universel — fonctionne Android (ouvre l'app
/// G Maps si installée) et iOS (universal link). Retourne null si lat/lng
/// invalides (null, NaN, infini).
///
/// Visible publiquement pour tests unitaires et fallback explicite si un
/// caller veut construire l'URL sans tenter de la lancer.
String? buildLocalNavUrl(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  if (!lat.isFinite || !lng.isFinite) return null;
  return 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
}

/// Résout l'URL effective à utiliser pour la navigation : préfère
/// [backendUrl] (string non vide), sinon reconstruit via [buildLocalNavUrl].
/// Retourne null si aucune source n'est utilisable.
String? resolveNavUrl({
  String? backendUrl,
  double? lat,
  double? lng,
}) {
  if (backendUrl != null && backendUrl.isNotEmpty) return backendUrl;
  return buildLocalNavUrl(lat, lng);
}

/// Lance Google Maps en navigation guidée vers la destination.
///
/// Source primaire : [backendUrl] (URL déjà construite par le core via
/// `buildGoogleMapsNavigationUrl`). Fallback : reconstruction locale à
/// partir de [lat]/[lng]. Si les deux sources sont absentes/invalides →
/// toast erreur + retour `false`.
///
/// Retourne `true` si l'OS a accepté de lancer l'intent, `false` sinon.
/// En cas d'échec et si un [BuildContext] est fourni, affiche un toast
/// d'erreur via [AppToast].
Future<bool> launchMapsNavigation({
  String? backendUrl,
  double? lat,
  double? lng,
  BuildContext? context,
}) async {
  // 1. Choix de l'URL : backend > fallback local. String vide traitée
  //    comme null pour ne pas tenter de lancer une URL invalide.
  final String? url = resolveNavUrl(backendUrl: backendUrl, lat: lat, lng: lng);

  if (url == null) {
    if (context != null && context.mounted) {
      AppToast.showError(
        context: context,
        message: 'Coordonnées indisponibles pour la navigation',
      );
    }
    return false;
  }

  // 2. Lancement externe : force l'ouverture de l'app G Maps native
  //    si installée, sinon le navigateur (universal link).
  final Uri uri = Uri.parse(url);
  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context != null && context.mounted) {
      AppToast.showError(
        context: context,
        message: 'Impossible d\'ouvrir Google Maps',
      );
    }
    return launched;
  } catch (_) {
    if (context != null && context.mounted) {
      AppToast.showError(
        context: context,
        message: 'Impossible d\'ouvrir Google Maps',
      );
    }
    return false;
  }
}
