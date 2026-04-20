// lib/screens/delivery_details/widgets/delivery_call_actions.dart
//
// Boutons "appeler" pour client/partenaire. Variant via [variant] :
// - DeliveryCallVariant.partner : couleur primary, tooltip restaurant
// - DeliveryCallVariant.customer : couleur verte, tooltip client
//
// Le numero est sanitize et lance via `launchPhoneCall`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/utils/phone_launcher.dart';
import 'package:zeet_ui/zeet_ui.dart';

enum DeliveryCallVariant { partner, customer }

class DeliveryCallButton extends StatelessWidget {
  final String? phoneNumber;
  final DeliveryCallVariant variant;

  const DeliveryCallButton({
    super.key,
    required this.phoneNumber,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    if (phoneNumber == null) return const SizedBox.shrink();

    final isPartner = variant == DeliveryCallVariant.partner;
    final color = isPartner ? AppColors.primary : ZeetColors.success;
    final tooltip = isPartner ? 'Appeler le restaurant' : 'Appeler le client';

    return IconButton(
      onPressed: () async {
        HapticFeedback.selectionClick();
        await launchPhoneCall(phoneNumber!, context: context);
      },
      tooltip: tooltip,
      icon: IconManager.getIcon('phone', color: color, size: 22),
    );
  }
}
