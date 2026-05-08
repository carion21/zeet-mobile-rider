// FcmService — branche Firebase Cloud Messaging sur l'app rider.
//
// Responsabilites :
//  - Recuperer le token FCM et l'injecter dans DeviceTokenManager
//  - Ecouter onTokenRefresh (rotation de token)
//  - Router les messages recus (foreground, tap-from-background, cold-start)
//    vers un callback fourni par l'appelant (zero filtre dans le service)
//  - Quand un message arrive en background profond / app killed, afficher
//    une notification FullScreenIntent via LocalNotificationService
//    (reveille l'ecran + sonne fort) — specifique rider, critique mission.
//
// Cote rider, le callback sera typiquement `MissionStatusDispatcher.handleRaw`
// qui patche les providers Riverpod (silentRefresh) et delegue les "incoming
// offer" a `IncomingDeliveryDispatcher`.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:rider/models/incoming_delivery_payload.dart';
import 'package:rider/services/device_token_manager.dart';
import 'package:rider/services/local_notification_service.dart';

/// Signature du callback appele pour dispatcher un payload recu.
typedef FcmDataHandler = Future<void> Function(Map<String, dynamic> data);

/// Handler background top-level obligatoire pour FirebaseMessaging.
/// Specifique rider : on declenche systematiquement la notif locale
/// FullScreenIntent pour les "delivery.offer" / "new_delivery" afin de
/// reveiller un livreur en background profond (3s pour accepter une mission).
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

  // Aligne sur MissionStatusDispatcher._incomingOfferTypes (foreground) :
  // tout event "offre/assignation a accepter" doit declencher FSI + ring en
  // background/killed. Sans `rider.mission_assigned`, l'app ratait silencieusement
  // les missions assignees quand le tel etait verrouille.
  if (type.startsWith('delivery.offer') ||
      type == 'new_delivery' ||
      type == 'rider.mission_assigned') {
    final data = Map<String, dynamic>.from(message.data);
    final notif = message.notification;
    if (notif != null) {
      data['title'] ??= notif.title;
      data['body'] ??= notif.body;
    }

    // Plan §3.4 : titre/body formatés lock-screen friendly à partir du
    // payload typé. Fallback sur les champs bruts si parse échoue.
    final parsed = IncomingDeliveryPayload.tryParse(data);
    final title = parsed?.lockScreenTitle ??
        ((data['title']?.toString().isNotEmpty ?? false)
            ? data['title'].toString()
            : 'Nouvelle livraison');
    final body = parsed?.lockScreenBody ??
        ((data['body']?.toString().isNotEmpty ?? false)
            ? data['body'].toString()
            : 'Appuyez pour voir les details');

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
  FcmDataHandler? _onMessageTap;
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
  /// [onDataMessage] : invoque pour tous les messages recus en foreground.
  /// [onMessageTap]  : invoque quand l'utilisateur tape une notification
  ///   (background ou cold-start). Si absent, `onDataMessage` est utilise
  ///   par defaut.
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
    FcmDataHandler? onMessageTap,
    bool promptPermission = false,
  }) async {
    if (_initialized) {
      _onDataMessage = onDataMessage;
      _onMessageTap = onMessageTap;
      return;
    }
    _initialized = true;
    _onDataMessage = onDataMessage;
    _onMessageTap = onMessageTap;

    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await LocalNotificationService.init(
      onTap: (payload) async {
        debugPrint(
          '[FcmService] local notif tapped: '
          'type=${payload['type_value'] ?? payload['type']}',
        );
        // Tap d'une notif locale -> traite comme un tap utilisateur.
        final FcmDataHandler? handler = _onMessageTap ?? _onDataMessage;
        await handler?.call(payload);
      },
    );

    // iOS : on NE force PAS la banniere FCM systeme en foreground. Le
    // dispatcher foreground gere l'affichage in-app (toast / IncomingDelivery
    // plein ecran) — coherent avec le design ZEET, evite le doublon.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    if (promptPermission) {
      await requestPushPermission();
    }

    _onTokenRefreshSub = messaging.onTokenRefresh.listen((token) {
      debugPrint(
        '[FcmService] token refreshed: ${token.substring(0, 16)}...',
      );
      DeviceTokenManager.instance.setPushToken(token);
      // Fire-and-forget : ne JAMAIS bloquer sur le register.
      unawaited(DeviceTokenManager.instance.registerCurrentDevice());
    });

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FcmService] foreground message: '
        'type=${message.data['type_value'] ?? message.data['type']}',
      );
      _dispatch(message, tap: false);
    });

    _onOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[FcmService] opened from background: '
        'type=${message.data['type_value'] ?? message.data['type']}',
      );
      _dispatch(message, tap: true);
    });

    // Cold-start : laisser splash/auth se resoudre avant de dispatcher.
    // Note : cote rider, le `NotificationLaunchRouter.capture()` (appele
    // dans main() AVANT runApp) capture deja le payload offer pour le
    // SplashScreen. On garde malgre tout `getInitialMessage()` ici pour
    // les types non-offer (status_changed, mission_cancelled...) qui ne
    // sont pas captes par le router cold-start.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _dispatch(initial, tap: true);
      });
    }
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
      // iOS : l'APNs token est le maillon critique. S'il est null, Firebase
      // ne pourra JAMAIS livrer de push, meme si getToken() retourne une
      // string. Cause typique : entitlement `aps-environment` manquant,
      // App ID sans capability Push, ou provisioning profile non regenere.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apns = await messaging.getAPNSToken();
        debugPrint(
          '[FcmService] APNs token: ${apns ?? "NULL (iOS push KO)"}',
        );
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        DeviceTokenManager.instance.setPushToken(token);
        debugPrint('[FcmService] FCM token: ${token.substring(0, 16)}...');
        // Fire-and-forget (cf. note sur registerCurrentDevice).
        unawaited(DeviceTokenManager.instance.registerCurrentDevice());
      } else {
        debugPrint('[FcmService] getToken() returned null or empty');
      }
    } catch (e) {
      debugPrint('[FcmService] getToken failed: $e');
    }

    return settings.authorizationStatus;
  }

  void _dispatch(RemoteMessage message, {required bool tap}) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(message.data);

    final notif = message.notification;
    if (notif != null) {
      data['title'] ??= notif.title;
      data['body'] ??= notif.body;
    }

    // Hide la notif locale "incoming delivery" si elle etait affichee :
    // l'utilisateur revient au foreground via un autre canal.
    LocalNotificationService.cancelIncomingDelivery();

    // Tap -> handler dedie (navigation) ; fallback sur onDataMessage.
    // Foreground -> handler data (silent refresh + presentation in-app).
    final FcmDataHandler? handler =
        tap ? (_onMessageTap ?? _onDataMessage) : _onDataMessage;
    handler?.call(data);
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
