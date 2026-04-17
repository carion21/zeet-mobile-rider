// IncomingDeliveryDispatcher — point d'entree unique pour declencher l'ecran
// "nouvelle livraison".
//
// Appele par :
//  - Le handler FCM (foreground, tap-from-background, cold-start)
//  - Le bouton dev en mode debug
//
// Role :
//  1. Parse le payload brut en [IncomingDeliveryPayload] (defensif)
//  2. Pousse le payload dans [incomingDeliveryProvider]
//  3. Navigue vers [IncomingDeliveryScreen] si pas deja affiche

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rider/models/incoming_delivery_payload.dart';
import 'package:rider/providers/incoming_delivery_provider.dart';
import 'package:rider/screens/incoming_delivery/index.dart';
import 'package:rider/services/navigation_service.dart';

abstract class IncomingDeliveryDispatcher {
  /// Traite un payload brut (map type FCM RemoteMessage.data ou JSON decode).
  /// Retourne `false` si le payload n'est pas une offre "delivery.offer"
  /// exploitable.
  static bool handleRaw(WidgetRef ref, Map<String, dynamic> raw) {
    // Filtre : on accepte `type_value` (officiel) et `type` (alias) pour
    // les events delivery.offer.
    final type = (raw['type_value']?.toString() ?? raw['type']?.toString() ?? '');
    if (!type.startsWith('delivery.offer') && type != 'new_delivery') {
      debugPrint('[IncomingDeliveryDispatcher] skipped: type=$type');
      return false;
    }

    final payload = IncomingDeliveryPayload.tryParse(raw);
    if (payload == null) {
      debugPrint(
        '[IncomingDeliveryDispatcher] failed to parse payload: $raw',
      );
      return false;
    }

    return handle(ref, payload);
  }

  /// Traite un payload deja parse.
  static bool handle(WidgetRef ref, IncomingDeliveryPayload payload) {
    debugPrint('[IncomingDeliveryDispatcher] show $payload');

    final state = ref.read(incomingDeliveryProvider);
    final alreadyShowing =
        state.isActive && state.payload?.deliveryId == payload.deliveryId;

    ref.read(incomingDeliveryProvider.notifier).show(payload);

    if (!alreadyShowing) {
      Routes.push(const IncomingDeliveryScreen());
    }
    return true;
  }

  /// Trigger dev : declenche l'ecran avec un payload bidon. Ne fait rien en release.
  static void triggerDev(WidgetRef ref, {int deliveryId = 421}) {
    if (!kDebugMode) return;
    handle(ref, IncomingDeliveryPayload.fake(deliveryId: deliveryId));
  }
}
