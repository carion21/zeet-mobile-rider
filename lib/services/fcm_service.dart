// FcmService — branche Firebase Cloud Messaging sur l'app rider.
//
// Responsabilites :
//  - Demander la permission notifications (Android 13+)
//  - Recuperer le token FCM et l'injecter dans DeviceTokenManager
//  - Ecouter onTokenRefresh (rotation de token)
//  - Router les messages recus (foreground, tap-from-background, cold-start)
//    vers un callback fourni par l'appelant
//  - En Phase 3 : quand un message arrive alors que l'app est killed ou
//    en background profond, afficher une notification FullScreenIntent
//    via LocalNotificationService (reveille l'ecran + sonne fort).

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:rider/services/device_token_manager.dart';
import 'package:rider/services/local_notification_service.dart';

typedef FcmDataHandler = Future<void> Function(Map<String, dynamic> data);

/// Handler background top-level obligatoire pour FirebaseMessaging.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotificationService.init();

  final type = (message.data['type_value']?.toString() ??
      message.data['type']?.toString() ??
      '');
  debugPrint(
    '[FcmService.bg] received: type=$type entity=${message.data['entity_id']}',
  );

  if (type.startsWith('delivery.offer') || type == 'new_delivery') {
    final data = Map<String, dynamic>.from(message.data);
    final notif = message.notification;
    if (notif != null) {
      data['title'] ??= notif.title;
      data['body'] ??= notif.body;
    }

    final title = (data['title']?.toString().isNotEmpty ?? false)
        ? data['title'].toString()
        : 'Nouvelle livraison';
    final body = (data['body']?.toString().isNotEmpty ?? false)
        ? data['body'].toString()
        : 'Appuyez pour voir les details';

    await LocalNotificationService.showIncomingDelivery(
      title: title,
      body: body,
      payloadData: data,
    );
  }
}

class FcmService {
  static FcmService? _instance;

  FcmDataHandler? _onDataMessage;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  bool _initialized = false;

  FcmService._();

  static FcmService get instance {
    _instance ??= FcmService._();
    return _instance!;
  }

  /// Initialise les listeners FCM + local notifications + channels.
  ///
  /// Par défaut **ne demande PAS** la permission système (`promptPermission:
  /// false`) — le pre-prompt custom `NotifRationaleSheet` doit être affiché
  /// avant, côté écran d'accueil post-auth. Cela évite de brûler la chance
  /// iOS (one-shot) au cold-start quand le rider n'est pas encore connecté.
  ///
  /// Pour backward compat, passer `promptPermission: true` reproduit
  /// l'ancien comportement (permission demandée immédiatement).
  ///
  /// Cf. zeet-notification-strategy §8 — "ask in context".
  Future<void> init({
    required FcmDataHandler onDataMessage,
    bool promptPermission = false,
  }) async {
    if (_initialized) {
      _onDataMessage = onDataMessage;
      return;
    }
    _initialized = true;
    _onDataMessage = onDataMessage;

    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await LocalNotificationService.init(
      onTap: (payload) async {
        debugPrint(
          '[FcmService] local notif tapped: '
          'type=${payload['type_value'] ?? payload['type']}',
        );
        await _onDataMessage?.call(payload);
      },
    );

    if (promptPermission) {
      await requestPushPermission();
    }

    _onTokenRefreshSub = messaging.onTokenRefresh.listen((token) async {
      debugPrint(
        '[FcmService] token refreshed: ${token.substring(0, 16)}...',
      );
      DeviceTokenManager.instance.setPushToken(token);
      await DeviceTokenManager.instance.registerCurrentDevice();
    });

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FcmService] foreground message: '
        'type=${message.data['type_value'] ?? message.data['type']}',
      );
      _dispatch(message);
    });

    _onOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[FcmService] opened from background: '
        'type=${message.data['type_value'] ?? message.data['type']}',
      );
      _dispatch(message);
    });

    // Note : le cold-start (getInitialMessage / getLaunchPayload) est
    // desormais gere AVANT runApp par `NotificationLaunchRouter.capture()`
    // et route par le SplashScreen. Evite un double dispatch qui ferait
    // clignoter le home entre le splash et l'ecran cible.
  }

  /// Déclenche la demande de permission notification système + enregistrement
  /// du token FCM. À appeler **après** le pre-prompt `NotifRationaleSheet`
  /// depuis l'écran d'accueil post-auth.
  ///
  /// Idempotent : si la permission est déjà accordée, récupère juste le
  /// token et le synchronise côté serveur.
  Future<AuthorizationStatus> requestPushPermission() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      '[FcmService] permission status: ${settings.authorizationStatus}',
    );

    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        DeviceTokenManager.instance.setPushToken(token);
        debugPrint('[FcmService] FCM token: ${token.substring(0, 16)}...');
        await DeviceTokenManager.instance.registerCurrentDevice();
      }
    } catch (e) {
      debugPrint('[FcmService] getToken failed: $e');
    }

    return settings.authorizationStatus;
  }

  void _dispatch(RemoteMessage message) {
    final handler = _onDataMessage;
    if (handler == null) return;
    final data = Map<String, dynamic>.from(message.data);

    final notif = message.notification;
    if (notif != null) {
      data['title'] ??= notif.title;
      data['body'] ??= notif.body;
    }

    LocalNotificationService.cancelIncomingDelivery();

    handler(data);
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onOpenedAppSub = null;
    _onTokenRefreshSub = null;
    _initialized = false;
  }
}
