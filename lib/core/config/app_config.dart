// lib/core/config/app_config.dart
//
// Constantes au niveau application (fallback, timeouts, seuils).
// Centralise les valeurs qui étaient hardcodées dans les widgets/services
// (plan §1 hardcodes identifiés, §7B critère 7).
//
// Règle : si tu te retrouves à hardcoder un nombre magique (lat/lng, timeout,
// seuil), ajoute-le ici plutôt que dans le widget.

import 'package:latlong2/latlong.dart';

abstract class AppConfig {
  // ─── Géolocalisation ────────────────────────────────────────
  /// Position centre Abidjan (Plateau) — fallback si la localisation rider
  /// est indisponible (permissions refusées, GPS désactivé).
  /// Coords : 5.3400°N, 4.0200°W (place de la République).
  static const LatLng abidjanFallback = LatLng(5.3400, -4.0200);

  /// Position de référence du dropoff client en mode démo / dev.
  /// Cocody, axe nord d'Abidjan.
  static const LatLng demoDropoff = LatLng(5.3478, -4.0123);

  /// Rafraîchissement GPS en mission active (5–10s, pas en dessous de 5s
  /// pour éviter la saturation webhook DE).
  static const Duration gpsActivePeriod = Duration(seconds: 8);

  /// Rafraîchissement GPS hors mission (économie batterie).
  static const Duration gpsIdlePeriod = Duration(seconds: 45);

  // ─── Réseau & timeouts ──────────────────────────────────────
  /// Timeout fallback pour les appels FCM internes (avant que le push
  /// remonte effectivement à l'écran).
  static const Duration fcmFallbackTimeout = Duration(seconds: 30);

  // ─── Mission & UX ───────────────────────────────────────────
  /// Délai max pour accepter une offre rider (côté backend = source de
  /// vérité, mais on peut afficher ce timer si payload absent).
  static const Duration offerAcceptDeadline = Duration(seconds: 30);

  /// Seuil des jalons pour célébration "fin de mission" (subtle confetti).
  /// Skill `zeet-neuro-ux` §completion-satisfaction.
  static const List<int> milestoneCounts = <int>[1, 5, 10, 20, 50];

  // ─── Pagination ─────────────────────────────────────────────
  /// Page size standard pour les listes paginées rider.
  static const int defaultPageSize = 20;

  /// Page size pour les listes denses (notifications, logs).
  static const int densePageSize = 50;
}
