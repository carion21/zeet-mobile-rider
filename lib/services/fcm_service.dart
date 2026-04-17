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

  Future<void> init({required FcmDataHandler onDataMessage}) async {
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

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      debugPrint(
        '[FcmService] cold-start FCM message: '
        'type=${initial.data['type_value'] ?? initial.data['type']}',
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        _dispatch(initial);
      });
    }

    final launchPayload = await LocalNotificationService.getLaunchPayload();
    if (launchPayload != null && launchPayload.isNotEmpty) {
      debugPrint(
        '[FcmService] cold-start local notif: '
        'type=${launchPayload['type_value'] ?? launchPayload['type']}',
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        _onDataMessage?.call(launchPayload);
      });
    }
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
