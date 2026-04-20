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
const int kMissionUpdateNotificationIdBase = 3000;

// ─── Channels Android (skill `zeet-notification-strategy` §3) ─────
//
// L'utilisateur peut désactiver chaque channel indépendamment depuis les
// settings système. La hiérarchie respecte la matrice de priorité
// (Critical > Important > Info > Marketing).
//
// IMPORTANT : les IDs ci-dessous sont le contrat avec le backend
// (service de push). Ne pas les renommer sans coordination serveur.

// 🔴 Critical / Operational — sonnerie alarme + bypass silencieux.
// AudioAttributesUsage.alarm : autorise Android 8+ à franchir le DND si
// l'utilisateur a coché "Autoriser les interruptions" pour ZEET dans les
// settings Do-Not-Disturb (cf. zeet-notification-strategy §2-3).
const String kIncomingDeliveryChannelId = 'zeet_rider_incoming_delivery';
const String kIncomingDeliveryChannelName = 'Nouvelles missions';
const String kIncomingDeliveryChannelDesc =
    'Alerte prioritaire sonore pour chaque nouvelle offre de livraison.';

// 🔴 Critical / Operational — transitions standards d'une mission déjà
// acceptée (assignée, annulée, forcée par le support, etc.). Importance
// high : bruit + vibration modérés, pas de FullScreenIntent (on ne
// réveille pas le téléphone comme pour une offre).
const String kMissionUpdatesChannelId = 'zeet_rider_missions';
const String kMissionUpdatesChannelName = 'Mises à jour mission';
const String kMissionUpdatesChannelDesc =
    'Changements d\'état de tes courses en cours : assignation, arrivée, annulation.';

// 🟡 Important / Contextual — alertes de zone (forte demande, bonus).
const String kZoneAlertsChannelId = 'zeet_rider_zone_alerts';
const String kZoneAlertsChannelName = 'Alertes zone';
const String kZoneAlertsChannelDesc =
    'Notifications contextuelles : forte demande dans ta zone, bonus, météo.';

// 🟢 Info / Passive — récap journalier, gains.
const String kStatsChannelId = 'zeet_rider_stats';
const String kStatsChannelName = 'Récaps & statistiques';
const String kStatsChannelDesc =
    'Synthèse de fin de journée et notifications de gains.';

// ⚪ Marketing / Promo (opt-in) — campagnes ZEET.
const String kPromoChannelId = 'zeet_rider_promo';
const String kPromoChannelName = 'Offres ZEET';
const String kPromoChannelDesc =
    'Bonus weekend, défis, nouveautés produit. Désactivable.';

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
    // iOS Darwin init : permissions gérées en amont par FcmService pour
    // respecter le pre-prompt (zeet-notification-strategy §8).
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    await ensureChannels();

    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('[LocalNotifService] permission request failed: $e');
    }
  }

  /// Crée/met à jour tous les channels Android requis par le backend.
  ///
  /// Appelée par [init] mais peut aussi être invoquée directement au boot
  /// de l'app (avant `runApp`) pour s'assurer que les channels existent
  /// **avant** la première notif FCM.
  static Future<void> ensureChannels() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    // 🔴 Critical : nouvelles missions (offer). Max + alarm usage pour
    // franchir DND si l'utilisateur l'autorise dans les settings système.
    // vibrationPattern = pattern "appel" 4 pulses de 800ms — reconnaissable.
    await androidImpl.createNotificationChannel(
      AndroidNotificationChannel(
        kIncomingDeliveryChannelId,
        kIncomingDeliveryChannelName,
        description: kIncomingDeliveryChannelDesc,
        importance: Importance.max,
        playSound: true,
        // Son custom `mission_alert` : raw resource Android. Si le fichier
        // n'est pas packagé dans res/raw/, Android retombe sur le son
        // système par défaut sans crash.
        sound: const RawResourceAndroidNotificationSound('mission_alert'),
        // AudioAttributesUsage.alarm : la catégorie "alarme" est celle qui
        // peut franchir le DND (si user opt-in). Cf. skill §2 et §4.
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern:
            Int64List.fromList(const [0, 800, 400, 800, 400, 800, 400, 800]),
        enableLights: true,
        ledColor: const Color(0xFFFF5A1F),
        showBadge: true,
      ),
    );

    // 🔴 Critical : mises à jour mission (post-accept). Pas de FSI mais
    // son + vibration standard pour que le rider en mouvement perçoive
    // un changement d'état. Importance high.
    await androidImpl.createNotificationChannel(
      AndroidNotificationChannel(
        kMissionUpdatesChannelId,
        kMissionUpdatesChannelName,
        description: kMissionUpdatesChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(const [0, 300, 150, 300]),
        showBadge: true,
      ),
    );

    // 🟡 Important : alertes de zone.
    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        kZoneAlertsChannelId,
        kZoneAlertsChannelName,
        description: kZoneAlertsChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // 🟢 Info : récap journalier.
    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        kStatsChannelId,
        kStatsChannelName,
        description: kStatsChannelDesc,
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      ),
    );

    // ⚪ Marketing : promos (opt-in, silencieux).
    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        kPromoChannelId,
        kPromoChannelName,
        description: kPromoChannelDesc,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  /// Init bas niveau sans UI handler : utile pour déclarer les channels
  /// au boot de l'app (avant `runApp`), avant que FcmService ne soit prêt.
  static Future<void> bootstrapChannels() async {
    if (_initialized) {
      // Channels déjà créés via init() — idempotent, rien à faire.
      return;
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    try {
      await _plugin.initialize(initSettings);
      await ensureChannels();
    } catch (e) {
      debugPrint('[LocalNotifService] bootstrapChannels failed: $e');
    }
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
    // iOS : `timeSensitive` permet de percer le Focus Mode si l'utilisateur
    // l'autorise. Critical alerts nécessitent l'entitlement Apple (rare et
    // peu probable d'être accordé pour la livraison). Cf.
    // zeet-notification-strategy §4 (bypass DND et focus).
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: 'zeet.rider.mission',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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

  /// Affiche une notification "mise à jour mission" (non-offre) : mission
  /// assignée après acceptation, annulée par le support, client rappelé,
  /// etc. Channel `zeet_rider_missions` (high priority, pas de FSI).
  ///
  /// [missionId] sert à générer un id stable pour qu'une mise à jour sur
  /// la même mission écrase la précédente plutôt que d'empiler les notifs.
  static Future<void> showMissionUpdate({
    required String title,
    required String body,
    required Map<String, dynamic> payloadData,
    int? missionId,
  }) async {
    if (!_initialized) await init();

    final int notifId = missionId != null
        ? (kMissionUpdateNotificationIdBase + (missionId.abs() % 1000))
        : kMissionUpdateNotificationIdBase;

    final androidDetails = AndroidNotificationDetails(
      kMissionUpdatesChannelId,
      kMissionUpdatesChannelName,
      channelDescription: kMissionUpdatesChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      vibrationPattern:
          Int64List.fromList(const [0, 300, 150, 300]),
      color: const Color(0xFFFF5A1F),
      ticker: title,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: 'zeet.rider.mission_update',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      notifId,
      title,
      body,
      details,
      payload: jsonEncode(payloadData),
    );
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
