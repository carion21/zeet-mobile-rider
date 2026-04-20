// lib/main.dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:rider/core/constants/themes.dart';
import 'package:rider/core/widgets/active_missions_fab_overlay.dart';
import 'package:rider/providers/connectivity_provider.dart';
import 'package:rider/providers/offline_queue_provider.dart';
import 'package:rider/providers/theme_provider.dart';
import 'package:rider/screens/splash/index.dart' show consumeColdStartOfferPayload;
import 'package:rider/services/fcm_service.dart';
import 'package:rider/services/incoming_delivery_dispatcher.dart';
import 'package:rider/services/local_notification_service.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/services/notification_launch_router.dart';
import 'package:rider/services/offline_queue_service.dart';
import 'package:rider/services/token_service.dart';

void main() async {
  // Assurer que l'initialisation des widgets est complète
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser le service de tokens avant le lancement de l'app
  await TokenService.instance.init();

  // Hydrate la queue offline depuis SharedPreferences avant runApp pour
  // que toute action persistée d'une session précédente soit visible
  // immédiatement (skill `zeet-offline-first` §11 — kill app + reboot).
  await OfflineQueueService.instance.init();

  // Firebase — requis avant runApp pour que le handler background puisse
  // reinitialiser Firebase dans son propre isolate.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Non fatal en dev local si google-services.json est absent.
    debugPrint('[main] Firebase init failed: $e');
  }

  // Declare les channels Android AU BOOT (pas lazy a la 1ere notif) :
  // les channels doivent exister avant que le backend ne cible un push
  // avec un `channel_id` donne. Cf. skill `zeet-notification-strategy` §3
  // (declarer tous les channels au lancement de l'app).
  await LocalNotificationService.bootstrapChannels();

  // Capture toute notif cold-start (FCM + local) AVANT runApp pour que
  // SplashScreen puisse router directement vers l'ecran cible au lieu
  // d'un flash home -> mission. Cf. skill §7 "app killed".
  await NotificationLaunchRouter.capture();

  // Définir l'orientation de l'application
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Lancer l'application avec ProviderScope pour Riverpod
  runApp(
    const ProviderScope(
      child: MyApp(initialRoute: Routes.splash),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Observer du cycle de vie pour déclencher la sync au foreground
    // (skill `zeet-offline-first` §5 — triggers de sync).
    WidgetsBinding.instance.addObserver(this);

    // Init FCM apres la premiere frame (le NavigatorState doit exister pour
    // pouvoir pusher l'IncomingDeliveryScreen depuis un cold-start notif tap).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.instance.init(
        onDataMessage: (data) async {
          IncomingDeliveryDispatcher.handleRaw(ref, data);
        },
      );

      // Cold-start deep-link — offer :
      // Si une offre delivery.offer a reveille l'app depuis killed, on
      // la redispatch via le dispatcher standard (meme chemin qu'en
      // foreground) une fois le SplashScreen a termine son auth check.
      // On poll toutes les 500ms pendant 10s max : le splash peut mettre
      // jusqu'a 1.5s (anim) + 8s (timeout auth) avant de pousser le home
      // et de deposer le payload via `_deferIncomingOffer`.
      _waitForColdStartOffer(ref);

      // Sync best-effort au boot si on a une connexion (rattrape les
      // actions persistées d'une session précédente).
      unawaited(OfflineQueueService.instance.sync());
    });

    // Trigger #1 — connectivity restored (offline → online).
    ref.listenManual<AsyncValue<bool>>(
      connectivityStatusProvider,
      (previous, next) {
        final bool wasOffline =
            previous?.maybeWhen(data: (v) => !v, orElse: () => false) ?? false;
        final bool isOnline =
            next.maybeWhen(data: (v) => v, orElse: () => false);
        if (wasOffline && isOnline) {
          debugPrint('[OfflineQueue] connectivity restored → sync');
          unawaited(OfflineQueueService.instance.sync());
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Attend que le splash pose eventuellement un payload d'offre
  /// cold-start (via `_deferIncomingOffer`). Poll 500ms, 10s max.
  /// Consomme au plus 1 payload.
  Future<void> _waitForColdStartOffer(WidgetRef readyRef) async {
    const int maxAttempts = 20; // 20 * 500ms = 10s.
    for (int i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final Map<String, dynamic>? cold = consumeColdStartOfferPayload();
      if (cold != null) {
        debugPrint('[main] cold-start offer dispatched after ${i * 500}ms');
        IncomingDeliveryDispatcher.handleRaw(readyRef, cold);
        return;
      }
    }
    debugPrint('[main] no cold-start offer within 10s window');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Trigger #2 — app revient au foreground.
    if (state == AppLifecycleState.resumed) {
      debugPrint('[OfflineQueue] app resumed → sync');
      unawaited(OfflineQueueService.instance.sync());
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return ScreenUtilInit(
      // Design size basé sur iPhone 11 Pro (375x812)
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ToastificationWrapper(
          child: MaterialApp(
            // Utiliser la même clé de navigation globale pour toute l'application
            navigatorKey: Routes.navigatorKey,
            title: 'ZEET Rider',
            // Configuration des thèmes
            theme: AppTheme.lightTheme(context),
            darkTheme: AppTheme.darkTheme(context),
            themeMode: themeMode,
            // Configuration des routes
            initialRoute: widget.initialRoute,
            onGenerateRoute: Routes.onGenerateRoute,
            debugShowCheckedModeBanner: false,
            // Overlay global : ConnectivityBanner visible sur TOUTES les
            // routes dès qu'on perd la connexion. Aligned top, SafeArea
            // intégrée. Évite la duplication par écran.
            builder: (context, navigator) {
              return Stack(
                children: [
                  if (navigator != null) navigator,
                  // FAB persistant Zeigarnik : "Course en cours" visible
                  // dès qu'au moins une mission est ongoing.
                  const ActiveMissionsFabOverlay(),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _GlobalConnectivityBanner(),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Banner global hors-ligne enrichi, branché sur `connectivityStatusProvider`
/// + `pendingActionsCountProvider` + `failedActionsCountProvider`.
///
/// 4 cas couverts :
/// - offline & 0 actions     → bandeau rouge "Mode hors ligne"
/// - offline & N actions     → bandeau rouge "Hors ligne · N actions en attente"
/// - online  & N actions     → bandeau orange "Synchronisation · N actions"
/// - online  & N échecs      → bandeau rouge "N action(s) en échec [Voir]"
/// - online  & 0 actions     → invisible (SizedBox.shrink)
///
/// Skill `zeet-offline-first` §7 (Indicateur visuel offline) + §9 (queue
/// visible et gérable par l'utilisateur).
class _GlobalConnectivityBanner extends ConsumerWidget {
  const _GlobalConnectivityBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isOnline = ref.watch(connectivityStatusProvider).maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );
    final int pending = ref.watch(pendingActionsCountProvider);
    final int failed = ref.watch(failedActionsCountProvider);

    // Cas dégradé prioritaire : actions échouées (dead letter).
    if (failed > 0) {
      return _RiderSyncBanner(
        color: ZeetColors.danger,
        icon: Icons.error_outline_rounded,
        message: failed == 1
            ? '1 action en échec · vérifier'
            : '$failed actions en échec · vérifier',
        onTap: () => Routes.navigateTo(Routes.offlineQueue),
      );
    }

    // Hors ligne : on signale + compteur d'actions en attente.
    if (!isOnline) {
      final String msg = pending == 0
          ? 'Mode hors ligne'
          : (pending == 1
              ? 'Hors ligne · 1 action en attente'
              : 'Hors ligne · $pending actions en attente');
      return _RiderSyncBanner(
        color: ZeetColors.danger,
        icon: Icons.wifi_off_rounded,
        message: msg,
        onTap: pending > 0
            ? () => Routes.navigateTo(Routes.offlineQueue)
            : null,
      );
    }

    // Online avec sync en cours.
    if (pending > 0) {
      return _RiderSyncBanner(
        color: ZeetColors.warning,
        icon: Icons.sync_rounded,
        message: pending == 1
            ? 'Synchronisation · 1 action'
            : 'Synchronisation · $pending actions',
        onTap: () => Routes.navigateTo(Routes.offlineQueue),
      );
    }

    // Online + queue vide → invisible.
    return const SizedBox.shrink();
  }
}

/// Bandeau visuel commun. Sticky top, SafeArea intégrée. Texte centré.
/// Cliquable si [onTap] non null → ouvre l'écran "Actions en attente".
class _RiderSyncBanner extends StatelessWidget {
  const _RiderSyncBanner({
    required this.color,
    required this.icon,
    required this.message,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      button: onTap != null,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZeetSpacing.x4,
                vertical: ZeetSpacing.x2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 16, color: ZeetColors.surface),
                  const SizedBox(width: ZeetSpacing.x2),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: ZeetColors.surface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: ZeetSpacing.x2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: ZeetColors.surface,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
