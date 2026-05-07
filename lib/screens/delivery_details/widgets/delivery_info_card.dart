// lib/screens/delivery_details/widgets/delivery_info_card.dart
//
// Carte detaillee de la mission (mode deplie) : statut + restaurant + client +
// recap commande + boutons d'action selon le statut.
//
// Pure UI. Les callbacks d'action sont fournis par l'orchestrateur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/models/mission_log_model.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/models/rider_action_model.dart';
import 'package:rider/providers/mission_logs_provider.dart';
import 'package:rider/providers/rider_actions_provider.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_call_actions.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_navigate_button.dart';
import 'package:rider/screens/delivery_details/widgets/mission_logs_sheet.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Vrai si le statut delivery est terminal (livre / non-livre / annule).
bool _isMissionTerminal(String? status) {
  final s = status?.replaceAll('_', '-');
  return s == 'delivered' ||
      s == 'not-delivered' ||
      s == 'cancelled' ||
      s == 'canceled';
}

class DeliveryInfoCard extends StatelessWidget {
  final Mission mission;
  final Color statusColor;
  final String statusText;
  final bool isActionLoading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCollect;
  final VoidCallback onDeliver;
  final VoidCallback onNotDelivered;
  final VoidCallback onClose;

  /// Quand `true`, masque les boutons primaires `collect` et `deliver`
  /// de la liste d'actions — l'orchestrateur les remplace par un
  /// `PrimaryStepAction` (slide-to-confirm) rendu en dehors de la card.
  /// Add-only, défaut `false` pour préserver le rendu historique.
  final bool hidePrimaryStepActions;

  const DeliveryInfoCard({
    super.key,
    required this.mission,
    required this.statusColor,
    required this.statusText,
    required this.isActionLoading,
    required this.onAccept,
    required this.onReject,
    required this.onCollect,
    required this.onDeliver,
    required this.onNotDelivered,
    required this.onClose,
    this.hidePrimaryStepActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    return Container(
      margin: EdgeInsets.all(AppSizes().paddingLarge),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _PartyRow(
            iconName: 'restaurant',
            iconColor: AppColors.primary,
            name: mission.partnerName,
            address: mission.pickupAddressDisplay,
            phone: mission.partnerPhone,
            variant: DeliveryCallVariant.partner,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          const SizedBox(height: 16),
          _DottedConnector(textLightColor: textLightColor),
          const SizedBox(height: 16),
          _PartyRow(
            iconName: 'person',
            iconColor: ZeetColors.success,
            name: mission.customerName,
            address: mission.dropoffAddressDisplay,
            phone: mission.customerPhone,
            variant: DeliveryCallVariant.customer,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          const SizedBox(height: 20),
          // Peak-end card pour mission terminee : "Livre en X min · +XXX FCFA"
          // + mini-timeline (skill `zeet-neuro-ux` peak-end rule).
          // Affiche AVANT l'order recap pour etre le premier element vu.
          if (_isMissionTerminal(mission.status)) ...<Widget>[
            _TerminalRecapCard(
              mission: mission,
              statusColor: statusColor,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),
          ],
          _OrderRecap(
            mission: mission,
            textColor: textColor,
            textLightColor: textLightColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 20),
          // CTA contextuel "Naviguer" : pickup si rider en route vers
          // resto, dropoff si en route vers client. Ouvre Google Maps
          // externe en navigation guidée. Self-contained, masqué sur les
          // statuts terminaux ou intermédiaires non navigables.
          _NavigationCTA(mission: mission),
          _ActionButtons(
            mission: mission,
            statusColor: statusColor,
            isLoading: isActionLoading,
            hidePrimaryStepActions: hidePrimaryStepActions,
            onAccept: onAccept,
            onReject: onReject,
            onCollect: onCollect,
            onDeliver: onDeliver,
            onNotDelivered: onNotDelivered,
            onClose: onClose,
          ),
        ],
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  final String iconName;
  final Color iconColor;
  final String name;
  final String address;
  final String? phone;
  final DeliveryCallVariant variant;
  final Color textColor;
  final Color textLightColor;

  const _PartyRow({
    required this.iconName,
    required this.iconColor,
    required this.name,
    required this.address,
    required this.phone,
    required this.variant,
    required this.textColor,
    required this.textLightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconManager.getIcon(iconName, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(color: textLightColor, fontSize: 13.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        DeliveryCallButton(phoneNumber: phone, variant: variant),
      ],
    );
  }
}

class _DottedConnector extends StatelessWidget {
  final Color textLightColor;
  const _DottedConnector({required this.textLightColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 20),
        Column(
          children: List.generate(
            3,
            (index) => Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: textLightColor.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderRecap extends StatelessWidget {
  final Mission mission;
  final Color textColor;
  final Color textLightColor;
  final bool isDarkMode;

  const _OrderRecap({
    required this.mission,
    required this.textColor,
    required this.textLightColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final int itemCount = mission.order?.itemCount ?? mission.order?.items.length ?? 0;
    final double totalAmount = mission.order?.amounts?.total ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Ligne articles : masquee quand itemCount = 0 (skill
          // `zeet-empty-loading-error` — pas d'affichage "0 article").
          if (itemCount > 0) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Détails de commande',
                        style:
                            TextStyle(color: textLightColor, fontSize: 12.sp)),
                    const SizedBox(height: 4),
                    Text(
                      mission.itemCountText,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (totalAmount > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text('Total commande',
                          style: TextStyle(
                              color: textLightColor, fontSize: 12.sp)),
                      const SizedBox(height: 4),
                      ZeetMoney(
                        amount: totalAmount,
                        currency: ZeetCurrency.fcfa,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: textLightColor.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
          ],
          // Frais rider : toujours affiches, en gros — peak info pour
          // le rider (skill `zeet-neuro-ux` peak-end rule).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                'Tu gagnes',
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ZeetMoney(
                amount: mission.fee,
                currency: ZeetCurrency.fcfa,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Composant boutons d'action — bind sur GET /v1/rider/deliveries/actions.
/// Skill ZEET : "ne jamais hardcoder statut -> boutons" (cf. ORDERS_RIDER_FLOW
/// §3.7-3.8). Fallback hardcode prudent si l'endpoint echoue.
class _ActionButtons extends ConsumerWidget {
  final Mission mission;
  final Color statusColor;
  final bool isLoading;
  final bool hidePrimaryStepActions;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCollect;
  final VoidCallback onDeliver;
  final VoidCallback onNotDelivered;
  final VoidCallback onClose;

  const _ActionButtons({
    required this.mission,
    required this.statusColor,
    required this.isLoading,
    required this.hidePrimaryStepActions,
    required this.onAccept,
    required this.onReject,
    required this.onCollect,
    required this.onDeliver,
    required this.onNotDelivered,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _normalizeStatus(mission.status);
    final stateKey = isLoading ? 'loading' : status;

    return ZeetStateSwitcher(
      stateKey: stateKey,
      alignment: Alignment.topCenter,
      child: _resolveChild(ref, status),
    );
  }

  Widget _resolveChild(WidgetRef ref, String status) {
    if (isLoading) {
      return const Center(
        key: ValueKey('buttons_loading'),
        child: CircularProgressIndicator(),
      );
    }

    // Etat terminal : pas d'action API a charger. CTA pluriel
    // (skill `zeet-3-clicks-rule`) — "Historique" outline (acces 1 tap a
    // l'audit trail sans devoir trouver l'icone discrete top-right) +
    // "Retour" textuel discret. "Retour" reste neutre — jamais teinte
    // par la couleur du statut (skill `zeet-design-system`).
    if (_isTerminal(status)) {
      return Column(
        key: const ValueKey('buttons_final'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => showMissionLogsSheet(
                ref.context,
                missionId: mission.id.toString(),
              ),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: Text(
                'Voir l\'historique',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onClose,
            child: Text(
              'Retour',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      );
    }

    if (status.isEmpty) {
      return const SizedBox.shrink(key: ValueKey('buttons_none'));
    }

    // Bind API : on watch les actions delivery pour ce statut.
    final actionsAsync = ref.watch(deliveryActionsProvider(status));

    return actionsAsync.when(
      loading: () => _buildHardcodedFallback(status),
      error: (err, _) => _buildHardcodedFallback(status),
      data: (actions) {
        if (actions.isEmpty) {
          // Backend dit "aucune action" → on respecte (probablement etat
          // terminal ou inconnu). On affiche le retour.
          return SizedBox(
            key: const ValueKey('buttons_no_actions'),
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: onClose,
              child: Text('Retour',
                  style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.w600)),
            ),
          );
        }
        return _buildFromActions(actions);
      },
    );
  }

  /// Mapping action.key -> handler local + couleur primaire/secondaire.
  Widget _buildFromActions(List<RiderAction> actions) {
    final List<Widget> buttons = <Widget>[];
    for (final RiderAction a in actions) {
      // Filtre : quand l'orchestrateur rend déjà un slide-to-confirm
      // primaire au-dessus de la card (PrimaryStepAction), on évite la
      // double action en masquant les boutons `collect`/`deliver` ici.
      if (hidePrimaryStepActions && _isPrimaryStepKey(a.key)) {
        continue;
      }
      final binding = _resolveBinding(a.key);
      if (binding == null) continue; // skip cles inconnues du client

      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(height: 10));
      }
      if (binding.isPrimary) {
        buttons.add(_PrimaryButton(
          label: a.label.isNotEmpty ? a.label : binding.fallbackLabel,
          color: binding.color,
          onPressed: binding.onPressed,
        ));
      } else {
        buttons.add(_OutlineButton(
          label: a.label.isNotEmpty ? a.label : binding.fallbackLabel,
          onPressed: binding.onPressed,
        ));
      }
    }
    if (buttons.isEmpty) return const SizedBox.shrink(key: ValueKey('buttons_empty'));
    return Column(
      key: const ValueKey('buttons_dynamic'),
      children: buttons,
    );
  }

  /// Vrai si la clé correspond à une action primaire désormais rendue par
  /// le `PrimaryStepAction` (slide-to-confirm) côté orchestrateur.
  static bool _isPrimaryStepKey(String key) {
    return key == 'collect' || key == 'deliver';
  }

  _ActionBinding? _resolveBinding(String key) {
    switch (key) {
      case 'accept':
      case 'accept-mission':
        // Bleu `info` (pas vert) : accept → statut `accepted`, pas final.
        // Garder `success` pour `deliver` (état terminal vert) évite que le
        // rider swipe/tape par réflexe sans réaliser l'étape — cf. skill
        // neuro-ux "couleur = signal sémantique".
        return _ActionBinding(
          isPrimary: true,
          color: ZeetColors.info,
          onPressed: onAccept,
          fallbackLabel: 'Accepter la livraison',
        );
      case 'reject':
      case 'reject-mission':
        return _ActionBinding(
          isPrimary: false,
          color: ZeetColors.danger,
          onPressed: onReject,
          fallbackLabel: 'Refuser',
        );
      case 'collect':
        return _ActionBinding(
          isPrimary: true,
          color: AppColors.primary,
          onPressed: onCollect,
          fallbackLabel: "J'ai récupéré la commande",
        );
      case 'deliver':
        return _ActionBinding(
          isPrimary: true,
          color: ZeetColors.success,
          onPressed: onDeliver,
          fallbackLabel: 'Livraison effectuée',
        );
      case 'not-delivered':
      case 'not_delivered':
        return _ActionBinding(
          isPrimary: false,
          color: ZeetColors.danger,
          onPressed: onNotDelivered,
          fallbackLabel: 'Signaler un souci',
        );
    }
    return null;
  }

  /// Fallback hardcode si l'endpoint actions echoue (offline, 500...).
  Widget _buildHardcodedFallback(String status) {
    switch (status) {
      case 'assigned':
      case 'pending':
        return Column(
          key: const ValueKey('buttons_assigned'),
          children: [
            _PrimaryButton(
                label: 'Accepter la livraison',
                color: ZeetColors.info,
                onPressed: onAccept),
            const SizedBox(height: 10),
            _OutlineButton(label: 'Refuser', onPressed: onReject),
          ],
        );
      case 'accepted':
        return Column(
          key: const ValueKey('buttons_accepted'),
          children: [
            if (!hidePrimaryStepActions) ...[
              _PrimaryButton(
                  label: "J'ai récupéré la commande",
                  color: AppColors.primary,
                  onPressed: onCollect),
              const SizedBox(height: 10),
            ],
            _OutlineButton(
                label: 'Signaler un souci', onPressed: onNotDelivered),
          ],
        );
      case 'collected':
      case 'on-the-way':
      case 'on_the_way':
      case 'delivering':
      case 'collecting':
      case 'picked_up':
        return Column(
          key: const ValueKey('buttons_delivering'),
          children: [
            if (!hidePrimaryStepActions) ...[
              _PrimaryButton(
                  label: 'Livraison effectuée',
                  color: ZeetColors.success,
                  onPressed: onDeliver),
              const SizedBox(height: 10),
            ],
            _OutlineButton(
                label: 'Livraison impossible', onPressed: onNotDelivered),
          ],
        );
      default:
        return const SizedBox.shrink(key: ValueKey('buttons_none'));
    }
  }

  String _normalizeStatus(String? raw) {
    if (raw == null) return '';
    return raw.replaceAll('_', '-');
  }

  bool _isTerminal(String status) {
    return status == 'delivered' ||
        status == 'not-delivered' ||
        status == 'cancelled' ||
        status == 'canceled';
  }
}

/// Card peak-end affichee uniquement sur les missions terminales.
/// Met en avant le gain + la duree totale + une mini-timeline derivee
/// des logs (skill `zeet-neuro-ux` peak-end rule).
class _TerminalRecapCard extends ConsumerWidget {
  const _TerminalRecapCard({
    required this.mission,
    required this.statusColor,
    required this.isDarkMode,
  });

  final Mission mission;
  final Color statusColor;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isSuccess = mission.status?.replaceAll('_', '-') == 'delivered';
    final logsAsync = ref.watch(missionLogsProvider(mission.id.toString()));
    final Color accent =
        isSuccess ? ZeetColors.success : ZeetColors.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_rounded : Icons.close_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isSuccess ? 'Course terminée' : 'Course non livrée',
                      style: TextStyle(
                        color: accent,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (logsAsync.asData?.value != null)
                      Builder(builder: (_) {
                        final dur = _totalDuration(logsAsync.asData!.value);
                        if (dur == null) return const SizedBox.shrink();
                        return Text(
                          isSuccess
                              ? 'Livré en ${_formatDuration(dur)}'
                              : 'Échouée après ${_formatDuration(dur)}',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),
                  ],
                ),
              ),
              if (isSuccess)
                ZeetMoney(
                  amount: mission.fee,
                  currency: ZeetCurrency.fcfa,
                  prefix: '+',
                  style: TextStyle(
                    color: accent,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          logsAsync.when(
            data: (logs) => _MiniTimeline(logs: logs, accent: accent),
            loading: () => const ZeetSkeleton(
              height: 36,
              borderRadius: ZeetRadius.brSm,
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Duree entre le premier log et le log terminal.
  Duration? _totalDuration(List<MissionLogEntry> logs) {
    if (logs.length < 2) return null;
    final start = logs.first.createdAt;
    final end = logs.last.createdAt;
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    return diff.isNegative ? null : diff;
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '${h}h' : '${h}h$m';
  }
}

/// Mini timeline horizontale 4 etapes : assigne → accepte → collecte →
/// livre. Chaque etape = dot colore + heure HH:mm en dessous. Les etapes
/// non franchies restent grisees (accessibilite : reduce-motion-safe).
class _MiniTimeline extends StatelessWidget {
  const _MiniTimeline({required this.logs, required this.accent});

  final List<MissionLogEntry> logs;
  final Color accent;

  static const List<_TimelineStep> _steps = <_TimelineStep>[
    _TimelineStep(value: 'assigned', label: 'Assigné'),
    _TimelineStep(value: 'accepted', label: 'Accepté'),
    _TimelineStep(value: 'collected', label: 'Collecté'),
    _TimelineStep(value: 'delivered', label: 'Livré'),
  ];

  /// Premiere occurrence d'un statut donne dans les logs.
  DateTime? _findStepTime(String value) {
    for (final entry in logs) {
      final v = entry.deliveryStatus?.value;
      if (v == value) return entry.createdAt;
    }
    return null;
  }

  /// Pour les missions echouees, on remplace la derniere etape par
  /// `not-delivered` afin d'afficher l'echec a la fin du parcours.
  List<_TimelineStep> _resolveSteps() {
    final hasFailure = logs.any(
      (e) => e.deliveryStatus?.value == 'not-delivered',
    );
    if (!hasFailure) return _steps;
    return <_TimelineStep>[
      ..._steps.take(_steps.length - 1),
      const _TimelineStep(value: 'not-delivered', label: 'Échouée'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _resolveSteps();
    final fmt = DateFormat('HH:mm');

    return Row(
      children: <Widget>[
        for (int i = 0; i < steps.length; i++) ...<Widget>[
          Expanded(
            child: _TimelineDot(
              label: steps[i].label,
              time: _findStepTime(steps[i].value),
              done: _findStepTime(steps[i].value) != null,
              accent: accent,
              fmt: fmt,
            ),
          ),
          if (i < steps.length - 1)
            _TimelineSegment(
              done: _findStepTime(steps[i + 1].value) != null,
              accent: accent,
            ),
        ],
      ],
    );
  }
}

class _TimelineStep {
  const _TimelineStep({required this.value, required this.label});
  final String value;
  final String label;
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({
    required this.label,
    required this.time,
    required this.done,
    required this.accent,
    required this.fmt,
  });

  final String label;
  final DateTime? time;
  final bool done;
  final Color accent;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context) {
    final Color dotColor = done ? accent : AppColors.textLight.withValues(alpha: 0.3);
    final Color textColor =
        done ? AppColors.text : AppColors.textLight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          time != null ? fmt.format(time!) : '--:--',
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 10.sp,
            fontFeatures: const <FontFeature>[
              FontFeature.tabularFigures(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineSegment extends StatelessWidget {
  const _TimelineSegment({required this.done, required this.accent});

  final bool done;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Container(
        width: 16,
        height: 2,
        color: done ? accent : AppColors.textLight.withValues(alpha: 0.3),
      ),
    );
  }
}

class _ActionBinding {
  final bool isPrimary;
  final Color color;
  final VoidCallback onPressed;
  final String fallbackLabel;
  const _ActionBinding({
    required this.isPrimary,
    required this.color,
    required this.onPressed,
    required this.fallbackLabel,
  });
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _OutlineButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ZeetColors.danger,
          side: const BorderSide(color: ZeetColors.danger),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// CTA contextuel de navigation externe. Choisit pickup ou dropoff selon
/// le statut de la mission. Sur statuts terminaux, intermédiaires non
/// navigables ou inconnus → ne rend rien.
///
/// Statuts → variant :
/// - accepted                                    → pickup (vers resto)
/// - collected, on-the-way, picked_up, delivering → dropoff (vers client)
/// - autre                                        → masqué
class _NavigationCTA extends StatelessWidget {
  final Mission mission;
  const _NavigationCTA({required this.mission});

  NavigateVariant? _variantForStatus(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final s = raw.replaceAll('_', '-');
    switch (s) {
      case 'accepted':
        return NavigateVariant.pickup;
      case 'collected':
      case 'on-the-way':
      case 'picked-up':
      case 'delivering':
      case 'collecting':
        return NavigateVariant.dropoff;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final variant = _variantForStatus(mission.status);
    if (variant == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DeliveryNavigateButton(
        mission: mission,
        variant: variant,
      ),
    );
  }
}
