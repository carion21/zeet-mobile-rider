// NotificationLaunchRouter — cold-start deep-linking.
//
// Responsabilite :
//   Quand l'app est killed et que l'utilisateur tape sur une notif FCM,
//   on doit pouvoir router **directement** vers l'ecran cible (mission /
//   offer) SANS passer par le home. Le splash consulte ce router apres
//   auth check et navigue en consequence.
//
// Flow :
//   1. main() appelle [capture] AVANT runApp pour lire
//      `FirebaseMessaging.getInitialMessage()` + `LocalNotificationService
//      .getLaunchPayload()` et stocker le payload eventuel.
//   2. SplashScreen appelle [pop] apres auth OK. Si un payload existe,
//      il retourne la route cible + arguments, sinon null.
//   3. Le splash pousse le home PUIS le detail (pour garder un back
//      coherent vers le home, pas vers splash).
//
// Types de payload supportes :
//   - type `delivery.offer*` / `new_delivery` -> `IncomingDeliveryScreen`
//     (via `IncomingDeliveryDispatcher.handleRaw`). Le payload est
//     conserve brut dans [LaunchTarget.rawPayload].
//   - Autres types ou simple `delivery_id` / `mission_id` dans data ->
//     `DeliveryDetailsScreen(missionId=...)`.
//
// Thread-safety : consomable une seule fois via [pop].

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:rider/services/local_notification_service.dart';

/// Resultat de capture : decrit ce que l'app doit afficher au demarrage.
@immutable
class LaunchTarget {
  /// Type brut de la notif (`delivery.offer`, `delivery.status.assigned`...).
  final String type;

  /// Si la notif cible une mission/livraison precise, l'id est extrait ici.
  final int? missionId;

  /// Pour les offres delivery.offer, on conserve le payload brut pour que
  /// `IncomingDeliveryDispatcher.handleRaw` puisse le reparser sans perdre
  /// d'infos (accept_deadline, distance, fee...).
  final Map<String, dynamic> rawPayload;

  const LaunchTarget({
    required this.type,
    this.missionId,
    this.rawPayload = const <String, dynamic>{},
  });

  bool get isOffer =>
      type.startsWith('delivery.offer') || type == 'new_delivery';

  bool get isMissionUpdate => !isOffer && missionId != null;

  @override
  String toString() =>
      'LaunchTarget(type=$type, missionId=$missionId, '
      'isOffer=$isOffer, isMissionUpdate=$isMissionUpdate)';
}

/// Router cold-start. Consomable une seule fois.
class NotificationLaunchRouter {
  NotificationLaunchRouter._();

  static LaunchTarget? _pending;
  static bool _captured = false;

  /// Consulte `getInitialMessage` (FCM) et `getLaunchPayload` (local notif)
  /// pour detecter une notif de cold-start. A appeler dans `main()` juste
  /// apres `Firebase.initializeApp()`, AVANT `runApp()`.
  ///
  /// Idempotent : les appels successifs sont no-op.
  static Future<void> capture() async {
    if (_captured) return;
    _captured = true;

    try {
      // 1. Priorite : FCM direct (data message envoye par le backend).
      final RemoteMessage? initial =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(initial.data);
        final notif = initial.notification;
        if (notif != null) {
          data['title'] ??= notif.title;
          data['body'] ??= notif.body;
        }
        _pending = _buildTarget(data);
        debugPrint(
          '[NotifLaunchRouter] captured FCM initial message: $_pending',
        );
        return;
      }

      // 2. Fallback : notif locale (FullScreenIntent via
      // LocalNotificationService) tapee par l'utilisateur.
      final Map<String, dynamic>? localPayload =
          await LocalNotificationService.getLaunchPayload();
      if (localPayload != null && localPayload.isNotEmpty) {
        _pending = _buildTarget(localPayload);
        debugPrint(
          '[NotifLaunchRouter] captured local notif launch: $_pending',
        );
      }
    } catch (e) {
      debugPrint('[NotifLaunchRouter] capture failed: $e');
    }
  }

  /// Consomme le payload capture (one-shot). Retourne null si pas de
  /// notif a l'origine du lancement.
  static LaunchTarget? pop() {
    final LaunchTarget? t = _pending;
    _pending = null;
    return t;
  }

  /// Cf. [pop] sans le retirer — utile pour debug.
  static LaunchTarget? peek() => _pending;

  /// Reset pour tests.
  @visibleForTesting
  static void resetForTest() {
    _pending = null;
    _captured = false;
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  static LaunchTarget _buildTarget(Map<String, dynamic> data) {
    final String type = (data['type_value']?.toString() ??
            data['type']?.toString() ??
            '')
        .trim();

    final int? missionId = _extractMissionId(data);

    return LaunchTarget(
      type: type,
      missionId: missionId,
      rawPayload: data,
    );
  }

  static int? _extractMissionId(Map<String, dynamic> data) {
    // Priorite : metadata (arrive en Map ou en JSON string via FCM).
    final dynamic meta = data['metadata'];
    if (meta is Map) {
      final int? id = _asInt(meta['delivery_id'] ??
          meta['mission_id'] ??
          meta['order_id']);
      if (id != null) return id;
    }
    if (meta is String && meta.isNotEmpty) {
      try {
        final decoded = jsonDecode(meta);
        if (decoded is Map) {
          final int? id = _asInt(decoded['delivery_id'] ??
              decoded['mission_id'] ??
              decoded['order_id']);
          if (id != null) return id;
        }
      } catch (_) {
        // metadata malforme -> fallback top-level.
      }
    }
    return _asInt(data['delivery_id'] ??
        data['mission_id'] ??
        data['entity_id']);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
