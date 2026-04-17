// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:rider/screens/splash/index.dart';
import 'package:rider/screens/auth/login/index.dart';
import 'package:rider/screens/auth/verify_otp/index.dart';
import 'package:rider/screens/profile/index.dart';
import 'package:rider/screens/home/index.dart';
import 'package:rider/screens/deliveries/index.dart';
import 'package:rider/screens/delivery_details/index.dart';
import 'package:rider/screens/notifications/index.dart';
import 'package:rider/screens/stats/index.dart';
import 'package:rider/screens/settings/index.dart';
import 'package:rider/screens/support/index.dart';
import 'package:rider/screens/deliveries_history/index.dart';
import 'package:rider/screens/availability_log/index.dart';
import 'package:rider/screens/ratings/index.dart';
import 'package:rider/models/delivery_model.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Service de navigation centralisé de l'app Rider.
///
/// Toutes les transitions de page passent par [ZeetPageRoute] (package
/// partagé `zeet_ui`), qui garantit :
/// - une grammaire de transition cohérente avec client/merchant
///   (shared axis horizontal par défaut),
/// - le respect de `MediaQuery.disableAnimations` (reduceMotion),
/// - une durée alignée sur `ZeetMotion.md` (300ms).
///
/// Voir skills : `zeet-motion-system` §4, `zeet-pos-ergonomics` §2bis.
class Routes {
  // GlobalKey unique pour le Navigator
  static final navigatorKey = GlobalKey<NavigatorState>();

  // Définition des routes statiques
  static const String splash = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String profile = '/profile';
  static const String deliveries = '/deliveries';
  static const String notifications = '/notifications';
  static const String stats = '/stats';
  static const String settings = '/settings';
  static const String support = '/support';
  static const String deliveriesHistory = '/deliveries-history';
  static const String availabilityLog = '/availability-log';
  static const String ratings = '/ratings';

  // Définition des constructeurs de widgets pour chaque route
  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    home: (context) => const HomeScreen(),
    login: (context) => const LoginScreen(),
    profile: (context) => const ProfileScreen(),
    deliveries: (context) => const DeliveriesScreen(),
    notifications: (context) => const NotificationsScreen(),
    stats: (context) => const StatsScreen(),
    settings: (context) => const SettingsScreen(),
    support: (context) => const SupportScreen(),
    deliveriesHistory: (context) => const DeliveriesHistoryScreen(),
    availabilityLog: (context) => const AvailabilityLogScreen(),
    ratings: (context) => const RatingsScreen(),
  };

  // ─── Helpers ZeetPageRoute ────────────────────────────────────────

  /// Construit une [ZeetPageRoute] avec le style demandé.
  static ZeetPageRoute<T> _buildRoute<T>(
    WidgetBuilder builder, {
    ZeetTransitionStyle style = ZeetTransitionStyle.sharedAxisHorizontal,
    RouteSettings? settings,
  }) {
    return ZeetPageRoute<T>(
      builder: builder,
      style: style,
      settings: settings,
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────

  /// Navigation vers une route nommée.
  static void navigateTo(String routeName) {
    if (navigatorKey.currentState == null) return;
    navigatorKey.currentState!.pushNamed(routeName);
  }

  /// Push d'un widget avec transition shared axis horizontal.
  static Future<T?> push<T>(
    Widget page, {
    ZeetTransitionStyle style = ZeetTransitionStyle.sharedAxisHorizontal,
  }) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.push<T>(
      _buildRoute<T>((_) => page, style: style),
    );
  }

  /// Remplacement vers une route nommée.
  static void navigateAndReplace(String routeName) {
    if (navigatorKey.currentState == null) return;
    navigatorKey.currentState!.pushReplacementNamed(routeName);
  }

  /// Remplacement d'un widget avec transition ZeetPageRoute.
  static Future<T?> pushReplacement<T>(
    Widget page, {
    ZeetTransitionStyle style = ZeetTransitionStyle.sharedAxisHorizontal,
  }) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.pushReplacement<T, T>(
      _buildRoute<T>((_) => page, style: style),
    );
  }

  /// Navigation avec clear de l'historique.
  static void navigateAndRemoveAll(String routeName) {
    if (navigatorKey.currentState == null) return;
    navigatorKey.currentState!
        .pushNamedAndRemoveUntil(routeName, (Route<dynamic> route) => false);
  }

  /// Clear de l'historique avec un widget.
  static Future<T?> pushAndRemoveAll<T>(
    Widget page, {
    ZeetTransitionStyle style = ZeetTransitionStyle.sharedAxisHorizontal,
  }) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.pushAndRemoveUntil<T>(
      _buildRoute<T>((_) => page, style: style),
      (Route<dynamic> route) => false,
    );
  }

  /// Retour en arrière.
  static void goBack<T>([T? result]) {
    if (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState?.pop<T>(result);
    }
  }

  /// Navigation vers l'écran OTP avec paramètres.
  static Future<T?> pushVerifyOtp<T>({
    required String phoneNumber,
    String? fullName,
    required String type,
  }) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.push<T>(
      _buildRoute<T>((_) => VerifyOtpScreen(
            phoneNumber: phoneNumber,
            fullName: fullName,
            type: type,
          )),
    );
  }

  /// Navigation vers le détail de mission (API).
  static Future<T?> pushMissionDetails<T>({required String missionId}) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.push<T>(
      _buildRoute<T>((_) => DeliveryDetailsScreen(missionId: missionId)),
    );
  }

  /// Navigation vers le détail de livraison (legacy mock, sera supprimé).
  static Future<T?> pushDeliveryDetails<T>({required Delivery delivery}) {
    if (navigatorKey.currentState == null) return Future.value(null);
    return navigatorKey.currentState!.push<T>(
      _buildRoute<T>((_) => const DeliveryDetailsScreen()),
    );
  }

  // ─── Génération des routes (MaterialApp.onGenerateRoute) ──────────

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final routeBuilder = routes[settings.name];

    if (routeBuilder == null) {
      return _buildRoute(
        routes[splash] ??
            (_) => const Scaffold(
                  body: Center(child: Text('Route non trouvée')),
                ),
        settings: const RouteSettings(name: splash),
      );
    }

    return _buildRoute(routeBuilder, settings: settings);
  }
}
