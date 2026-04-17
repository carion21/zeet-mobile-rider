// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:toastification/toastification.dart';
import 'package:rider/core/constants/themes.dart';
import 'package:rider/services/fcm_service.dart';
import 'package:rider/services/incoming_delivery_dispatcher.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/providers/theme_provider.dart';
import 'package:rider/services/token_service.dart';

void main() async {
  // Assurer que l'initialisation des widgets est complète
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser le service de tokens avant le lancement de l'app
  await TokenService.instance.init();

  // Firebase — requis avant runApp pour que le handler background puisse
  // reinitialiser Firebase dans son propre isolate.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Non fatal en dev local si google-services.json est absent.
    debugPrint('[main] Firebase init failed: $e');
  }

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

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Init FCM apres la premiere frame (le NavigatorState doit exister pour
    // pouvoir pusher l'IncomingDeliveryScreen depuis un cold-start notif tap).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.instance.init(
        onDataMessage: (data) async {
          IncomingDeliveryDispatcher.handleRaw(ref, data);
        },
      );
    });
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
          ),
        );
      },
    );
  }
}
