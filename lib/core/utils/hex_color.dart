// lib/core/utils/hex_color.dart
//
// Utilitaire d'affichage : convertit un hex `#RRGGBB` renvoye par le core
// API en [Color] Flutter. Les endpoints ZEET (mission, delivery, order,
// ticket, priority) exposent leur status sous la forme
// `{id, label, value, color}` ou `color` est une chaine `#RRGGBB`. Cette
// fonction est la source de verite cote rider pour parser ce champ.
//
// Renvoie `null` si null/vide/invalide afin que l'appelant puisse
// appliquer son propre fallback du design system.

import 'package:flutter/material.dart';

/// Parse une couleur au format `#RRGGBB` (ou `RRGGBB`) renvoyee par l'API.
///
/// - Retourne `null` si la chaine est vide, `null`, ou invalide.
/// - Tolere les variations de casse et le prefixe `#` optionnel.
/// - Force l'alpha a `FF` si absent.
Color? hexToColor(String? hex) {
  if (hex == null) return null;
  final cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.isEmpty) return null;
  final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  if (normalized.length != 8) return null;
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}
