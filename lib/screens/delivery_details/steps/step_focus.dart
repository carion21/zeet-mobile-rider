// lib/screens/delivery_details/steps/step_focus.dart
//
// Architecture 3 step-screens du flow rider (plan §2 Flow C, §4.P4.1).
//
// Le rider parcourt la mission en 3 étapes mentales distinctes :
//
//   ┌──────────┬──────────┬──────────────┐
//   │  OFFER   │  RECUP   │   TRAJET     │
//   ├──────────┼──────────┼──────────────┤
//   │ assigned │ accepted │ collected    │
//   │          │          │ on-the-way   │
//   │          │          │ collecting   │
//   │          │          │ delivering   │
//   │          │          │ picked-up    │
//   ├──────────┼──────────┼──────────────┤
//   │ Décide   │ Va vers  │ Va vers      │
//   │ accept/  │ pickup,  │ dropoff,     │
//   │ reject   │ collecte │ livre        │
//   └──────────┴──────────┴──────────────┘
//
// Chaque step a :
//   - Un focus map différent (pickup pour Récup, dropoff pour Trajet)
//   - Une action primaire dédiée (slide-to-collect, slide-to-deliver)
//   - Des actions secondaires contextuelles (appel resto vs appel client)
//   - Une carte d'info focusée (détails commerce vs détails client)
//
// Cette enum est la source de vérité pour le routage step. Toute logique
// step-specific la consulte plutôt que de matcher des strings de status.
//
// Skill `zeet-3-clicks-rule` : 1 action primaire évidente par étape.
// Skill `zeet-pos-ergonomics` : pas d'ambiguïté sur l'action courante.

/// Étape mentale courante du rider.
///
/// Mappée depuis `mission.status` via [DeliveryStepFocusX.fromStatus].
enum DeliveryStepFocus {
  /// `assigned` — offre reçue, décision accept/reject.
  offer,

  /// `accepted` — récupération en cours, direction commerce.
  recup,

  /// `collected` / `on-the-way` / variantes — trajet vers client.
  trajet,

  /// `delivered` / `not-delivered` / `cancelled` / `canceled` — terminal.
  terminal,
}

extension DeliveryStepFocusX on DeliveryStepFocus {
  /// Construit le focus depuis le statut delivery brut.
  /// Tolère `null`, `_` au lieu de `-`, et statuts inconnus → [terminal].
  static DeliveryStepFocus fromStatus(String? raw) {
    if (raw == null || raw.isEmpty) return DeliveryStepFocus.terminal;
    final s = raw.replaceAll('_', '-');
    switch (s) {
      case 'assigned':
      case 'pending':
        return DeliveryStepFocus.offer;
      case 'accepted':
        return DeliveryStepFocus.recup;
      case 'collected':
      case 'collecting':
      case 'on-the-way':
      case 'picked-up':
      case 'delivering':
        return DeliveryStepFocus.trajet;
      case 'delivered':
      case 'not-delivered':
      case 'cancelled':
      case 'canceled':
        return DeliveryStepFocus.terminal;
    }
    return DeliveryStepFocus.terminal;
  }

  /// Libellé court FR pour debug ou breadcrumbs internes.
  String get debugLabel {
    switch (this) {
      case DeliveryStepFocus.offer:
        return 'Offer';
      case DeliveryStepFocus.recup:
        return 'Récup.';
      case DeliveryStepFocus.trajet:
        return 'Trajet';
      case DeliveryStepFocus.terminal:
        return 'Terminal';
    }
  }

  /// Vrai si cette étape attend une décision/action active du rider
  /// (donc `slide-to-confirm` ou boutons accept/reject visibles).
  bool get isActive => this != DeliveryStepFocus.terminal;
}
