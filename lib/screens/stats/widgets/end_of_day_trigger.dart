// EndOfDayTrigger — helper reutilisable pour declencher le peak moment
// "fin de journee" depuis plusieurs points d'entree (profile toggle
// online->offline, bouton home "Terminer la journee").
//
// Responsabilite :
//   - Charger `riderStatsProvider` pour la journee courante si pas cache,
//     avec timeout court (3s) pour ne pas bloquer l'UI.
//   - Si au moins 1 mission livree, ouvrir le recap bottom sheet
//     (`showEndOfDayRecapSheet`) avec les stats disponibles.
//   - Si rien a montrer, no-op silencieux.
//
// Source des donnees :
//   - `/v1/rider/stats?date_from=today&date_to=today` (via
//     `riderStatsProvider`). Si endpoint HS, on skip le recap.
//   - Distance totale : non livree par le backend (cf. BACKEND_WORK_
//     ORDER_REPORT tache 6). On n'affiche pas le KPI distance.
//   - Note moyenne : `ratingAvg` de `RiderStats`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rider/providers/stats_provider.dart';
import 'package:rider/screens/stats/widgets/end_of_day_recap_sheet.dart';

/// Helper reutilisable. A appeler depuis un widget consumer / avec un ref.
abstract class EndOfDayTrigger {
  /// Declenche le recap si conditions OK. Retourne `true` si le sheet
  /// a ete affiche, `false` sinon (pas de missions livrees aujourd'hui,
  /// context unmounted, ou stats indisponibles).
  static Future<bool> maybeShow(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var stats = ref.read(riderStatsProvider).stats;

    if (stats == null) {
      // Force un load rapide pour la periode "aujourd'hui" — timeout court
      // pour ne pas bloquer l'UI si l'API rame.
      final today = DateTime.now();
      final iso =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      await ref
          .read(riderStatsProvider.notifier)
          .load(dateFrom: iso, dateTo: iso)
          .timeout(const Duration(seconds: 3), onTimeout: () {});
      if (!context.mounted) return false;
      stats = ref.read(riderStatsProvider).stats;
    }

    if (stats == null || stats.deliveredCount <= 0) return false;
    if (!context.mounted) return false;

    await showEndOfDayRecapSheet(
      context,
      deliveries: stats.deliveredCount,
      earnings: stats.totalEarnings,
      // Distance : non dispo backend (cf. doc modele rider_stats_model).
      distanceKm: null,
      // Note moyenne — affichee uniquement si strictement positive.
      ratingAvg: stats.ratingAvg > 0 ? stats.ratingAvg : null,
      // Record : a calculer plus tard (besoin d'historique). Pour l'instant
      // on laisse false pour rester factuel.
      isRecord: false,
    );
    return true;
  }
}
