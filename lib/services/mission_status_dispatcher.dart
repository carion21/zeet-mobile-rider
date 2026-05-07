// MissionStatusDispatcher — point d'entree unique pour traiter les events
// push lies aux missions sur la surface rider.
//
// Appele par :
//   - FcmService (foreground, tap-from-background, cold-start)
//
// Role :
//   1. Filtrer les payloads non rider (sans short-circuit aux types stricts :
//      on accepte tout prefix `rider.` / `delivery.` / `order.` connu).
//   2. Pour les events "incoming offer" -> deleguer a IncomingDeliveryDispatcher
//      (preserve sonnerie + ringtone + plein ecran + idempotence deliveryId).
//   3. Pour les autres events -> silentRefresh() sur la liste de missions et,
//      si le detail mission affiche correspond a l'eventId, sur le detail.
//
// Le dispatcher ne navigue jamais (sauf pour le cas offer, delegue) :
// la navigation tap est geree par FcmService.onMessageTap cote main.dart.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rider/providers/mission_provider.dart';
import 'package:rider/services/incoming_delivery_dispatcher.dart';

abstract class MissionStatusDispatcher {
  /// Types d'events que le backend peut emettre vers la surface rider.
  /// On matche aussi sur prefix `rider.` / `delivery.` / `order.` ci-dessous.
  static const Set<String> _missionTypes = <String>{
    // Offre nouvelle livraison (existant cote core).
    'delivery.offer',
    'rider.mission_assigned',
    'new_delivery',
    // Annulation / commande prete (a anticiper cote core, cf plan 1.4).
    'rider.mission_cancelled',
    'rider.mission_canceled',
    'rider.mission_reassigned',
    'rider.order_ready',
    // Status changes generiques (relayes pour la liste/detail).
    'delivery.status_changed',
    'order.cancelled',
    'order.canceled',
    'order.status_changed',
  };

  /// Types signalant une "incoming offer" -> delegate vers
  /// IncomingDeliveryDispatcher (conserve la mecanique de presentation).
  static const Set<String> _incomingOfferTypes = <String>{
    'delivery.offer',
    'rider.mission_assigned',
    'new_delivery',
  };

  /// Traite un payload brut (map type FCM `RemoteMessage.data`).
  /// Retourne `false` si le payload n'est pas un event mission exploitable.
  static bool handleRaw(WidgetRef ref, Map<String, dynamic> raw) {
    final String type = (raw['type_value']?.toString() ??
            raw['type']?.toString() ??
            '')
        .toLowerCase();

    if (!_isMissionType(type)) {
      debugPrint('[MissionStatusDispatcher] skipped: type=$type');
      return false;
    }

    final int? eventId = _extractMissionId(raw);
    debugPrint(
      '[MissionStatusDispatcher] type=$type id=$eventId',
    );

    // Cas 1 : incoming offer -> delegate (preserve ring + plein ecran).
    if (_isIncomingOfferType(type)) {
      return IncomingDeliveryDispatcher.handleRaw(ref, raw);
    }

    // Cas 2 : autres events -> silent refresh sur la liste, et sur le detail
    // si l'ecran ouvert correspond a la mission ciblee.
    ref.read(missionsListProvider.notifier).silentRefresh();

    if (eventId != null) {
      final int? currentDetailId = ref.read(missionDetailProvider).mission?.id;
      if (currentDetailId == eventId) {
        ref.read(missionDetailProvider.notifier).silentRefresh(eventId);
      }
    }

    return true;
  }

  static bool _isMissionType(String type) {
    if (_missionTypes.contains(type)) return true;
    // `rider.*` et `delivery.*` concernent toujours le rider en cours.
    // Pour `order.*` on N'accepte PAS le prefix : seuls les types listes
    // dans `_missionTypes` (cancelled, canceled, status_changed) sont
    // pertinents — `order.created`, `order.preparing`, `order.confirmed`
    // ne le concernent pas et declencheraient un silentRefresh inutile.
    return type.startsWith('rider.') || type.startsWith('delivery.');
  }

  static bool _isIncomingOfferType(String type) {
    if (_incomingOfferTypes.contains(type)) return true;
    return type.startsWith('delivery.offer');
  }

  /// Extrait un id mission/delivery du payload (tolerant aux alias :
  /// `mission_id`, `delivery_id`, `entity_id`, `id`). Retourne `null` si rien.
  static int? _extractMissionId(Map<String, dynamic> raw) {
    final candidates = <dynamic>[
      raw['mission_id'],
      raw['delivery_id'],
      raw['entity_id'],
      raw['id'],
    ];
    for (final c in candidates) {
      if (c == null) continue;
      if (c is int) return c;
      if (c is String) {
        final parsed = int.tryParse(c);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
