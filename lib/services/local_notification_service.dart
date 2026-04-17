// LocalNotificationService — Phase 3 du flow "Incoming Delivery".
//
// Role :
//  - Creer un canal de notification HIGH importance avec son d'alarme et
//    bypass du mode silencieux. Ce canal sert aussi au FCM natif Android
//    pour les pushes avec `notification:{}` envoyes en background.
//  - Afficher une notification FullScreenIntent quand un FCM arrive alors
//    que l'app est killed : Android reveille l'ecran (comme un appel),
//    affiche le titre/body, et au tap lance MainActivity qui routera sur
//    IncomingDeliveryScreen.
//  - Router le tap utilisateur vers un callback fourni par l'appelant.
//
// Ce service doit etre initialisable DEPUIS LES DEUX ISOLATES (main + FCM
// background handler). init() est idempotente.

import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const int kIncomingDeliveryNotificationId = 2001;

const String kIncomingDeliveryChannelId = 'zeet_rider_incoming_delivery';
const String kIncomingDeliveryChannelName = 'Nouvelles livraisons';
const String kIncomingDeliveryChannelDesc =
    'Alertes prioritaires avec sonnerie forte pour les nouvelles offres de livraison.';

typedef NotificationTapHandler = Future<void> Function(
  Map<String, dynamic> payload,
);

NotificationTapHandler? _onTap;

@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) {
  final payloadStr = response.payload;
  if (payloadStr == null || payloadStr.isEmpty) return;
  try {
    final decoded = jsonDecode(payloadStr);
    if (decoded is Map) {
      _onTap?.call(Map<String, dynamic>.from(decoded));
    }
  } catch (e) {
    debugPrint('[LocalNotifService] payload parse failed: $e');
  }
}

@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  debugPrint(
    '[LocalNotifService.bg] notification tapped (payload=${response.payload})',
  );
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init({NotificationTapHandler? onTap}) async {
    if (onTap != null) _onTap = onTap;

    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    await _createChannel();

    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('[LocalNotifService] permission request failed: $e');
    }
  }

  static Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      kIncomingDeliveryChannelId,
      kIncomingDeliveryChannelName,
      description: kIncomingDeliveryChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: null,
      showBadge: true,
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(channel);
  }

  /// Affiche une notification FullScreenIntent pour une nouvelle livraison.
  static Future<void> showIncomingDelivery({
    required String title,
    required String body,
    required Map<String, dynamic> payloadData,
  }) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      kIncomingDeliveryChannelId,
      kIncomingDeliveryChannelName,
      channelDescription: kIncomingDeliveryChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(
        const [0, 800, 400, 800, 400, 800, 400, 800],
      ),
      color: const Color(0xFFFF5A1F),
      colorized: true,
      ticker: title,
    );
    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      kIncomingDeliveryNotificationId,
      title,
      body,
      details,
      payload: jsonEncode(payloadData),
    );
  }

  static Future<void> cancelIncomingDelivery() async {
    try {
      await _plugin.cancel(kIncomingDeliveryNotificationId);
    } catch (e) {
      debugPrint('[LocalNotifService] cancel failed: $e');
    }
  }

  /// Recupere le payload d'une notification qui a lance l'app (cold-start).
  static Future<Map<String, dynamic>?> getLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      final payloadStr = details?.notificationResponse?.payload;
      if (payloadStr == null || payloadStr.isEmpty) return null;
      final decoded = jsonDecode(payloadStr);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('[LocalNotifService] getLaunchPayload failed: $e');
    }
    return null;
  }
}
