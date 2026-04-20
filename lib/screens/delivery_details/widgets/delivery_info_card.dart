// lib/screens/delivery_details/widgets/delivery_info_card.dart
//
// Carte detaillee de la mission (mode deplie) : statut + restaurant + client +
// recap commande + boutons d'action selon le statut.
//
// Pure UI. Les callbacks d'action sont fournis par l'orchestrateur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/models/rider_action_model.dart';
import 'package:rider/providers/rider_actions_provider.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_call_actions.dart';
import 'package:zeet_ui/zeet_ui.dart';

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
          _OrderRecap(
            mission: mission,
            textColor: textColor,
            textLightColor: textLightColor,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 20),
          _ActionButtons(
            mission: mission,
            statusColor: statusColor,
            isLoading: isActionLoading,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Détails de commande',
                  style: TextStyle(color: textLightColor, fontSize: 12.sp)),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Frais de livraison',
                  style: TextStyle(color: textLightColor, fontSize: 12.sp)),
              const SizedBox(height: 4),
              ZeetMoney(
                amount: mission.fee,
                currency: ZeetCurrency.fcfa,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16.sp,
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

    // Etat terminal : pas d'action API a charger.
    if (_isTerminal(status)) {
      return SizedBox(
        key: const ValueKey('buttons_final'),
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onClose,
          style: ElevatedButton.styleFrom(
            backgroundColor: statusColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Retour',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
        ),
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

  _ActionBinding? _resolveBinding(String key) {
    switch (key) {
      case 'accept':
      case 'accept-mission':
        return _ActionBinding(
          isPrimary: true,
          color: ZeetColors.success,
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
                color: ZeetColors.success,
                onPressed: onAccept),
            const SizedBox(height: 10),
            _OutlineButton(label: 'Refuser', onPressed: onReject),
          ],
        );
      case 'accepted':
        return Column(
          key: const ValueKey('buttons_accepted'),
          children: [
            _PrimaryButton(
                label: "J'ai récupéré la commande",
                color: AppColors.primary,
                onPressed: onCollect),
            const SizedBox(height: 10),
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
            _PrimaryButton(
                label: 'Livraison effectuée',
                color: ZeetColors.success,
                onPressed: onDeliver),
            const SizedBox(height: 10),
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
