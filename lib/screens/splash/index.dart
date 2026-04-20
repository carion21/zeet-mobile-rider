// lib/screens/splash/index.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/screens/main_scaffold/index.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/services/notification_launch_router.dart';
import 'package:rider/services/permissions_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _liquidController;
  late AnimationController _fadeController;
  late Animation<double> _liquidAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation du liquide qui monte. Réduit à 1500ms (vs 3000) pour
    // diviser par 2 le cold-start time : skill `zeet-performance-budget`
    // §9 — first interactive < 2s.
    _liquidController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _liquidAnimation = Tween<double>(begin: 0.0, end: 1.1).animate(
      CurvedAnimation(parent: _liquidController, curve: Curves.easeInOut),
    );

    // Animation de fade pour le sous-texte (raccourci 600ms)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Démarrer l'animation du liquide immédiatement
    _liquidController.forward();

    // Sous-texte démarré rapidement (250ms vs 500ms)
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _fadeController.forward();
      }
    });

    // Vérifier l'état d'authentification et naviguer après l'animation
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    debugPrint('🏍️ [Splash] Début checkAuthAndNavigate');

    try {
      // Auth check parallèle avec un floor de 1500ms (= durée anim) pour
      // ne pas couper l'animation si l'auth est instantanée. Si l'auth
      // prend 5s, on attend 5s (cap timeout 8s). Avant : floor 4s fixe.
      await Future.wait([
        ref.read(authProvider.notifier).checkAuthStatus().timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                debugPrint('🏍️ [Splash] checkAuthStatus timeout');
              },
            ),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);
    } catch (e) {
      debugPrint('🏍️ [Splash] Erreur checkAuthStatus: $e');
    }

    debugPrint('🏍️ [Splash] Auth check terminé, navigation...');

    if (!mounted) return;

    final authState = ref.read(authProvider);
    debugPrint('🏍️ [Splash] Status: ${authState.status}');

    if (authState.status == AuthStatus.authenticated) {
      final bool onboarded =
          await PermissionsService.instance.isOnboarded();
      if (!mounted) return;
      if (onboarded) {
        // Cold-start deep-link : si l'utilisateur a tape une notif alors
        // que l'app etait killed, router DIRECTEMENT vers l'ecran cible
        // sans flash home au milieu. Le home reste en dessous dans la
        // stack pour que le back fonctionne naturellement.
        final LaunchTarget? target = NotificationLaunchRouter.pop();
        if (target != null) {
          _routeToNotifTarget(target);
          return;
        }
        debugPrint('🏍️ [Splash] → MainScaffold');
        Routes.navigateAndReplace(Routes.mainScaffold);
      } else {
        debugPrint('🏍️ [Splash] → Permissions');
        Routes.navigateAndReplace(Routes.permissions);
      }
    } else {
      debugPrint('🏍️ [Splash] → Login');
      Routes.navigateAndReplace(Routes.login);
    }
  }

  /// Route directement vers l'ecran cible depuis le splash apres auth OK.
  /// On remplace d'abord la stack par `HomeScreen` (pour que le back
  /// retourne au home), puis on push l'ecran cible.
  void _routeToNotifTarget(LaunchTarget target) {
    debugPrint('🏍️ [Splash] cold-start deep-link → $target');

    // Etape 1 : placer le MainScaffold comme racine de la stack (plus de
    // splash). Le back depuis l'ecran cible ramenera naturellement sur
    // l'onglet Home (index par defaut du MainScaffold).
    Routes.pushAndRemoveAll(const MainScaffold());

    // Etape 2 : apres la premiere frame de home, pousser l'ecran cible.
    // Le back ramenera naturellement au home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (target.isOffer) {
        // Pour une offre en cold-start, passe par le dispatcher standard :
        // le FcmService `_onDataMessage` n'a pas encore ete branche quand
        // le splash execute, on invoque donc la route incoming_delivery
        // directement. Le payload brut est re-propage a
        // IncomingDeliveryDispatcher via un event differe — voir main.dart.
        // Ici on se contente de push l'ecran Home : l'ecran Incoming sera
        // bien declenche par FcmService une fois init via le callback
        // onDataMessage branche dans `_MyAppState.initState`.
        _deferIncomingOffer(target);
      } else if (target.missionId != null) {
        Routes.pushMissionDetails(missionId: '${target.missionId}');
      }
    });
  }

  /// Pour les offres cold-start, on differe leur prise en charge au FCM
  /// service pour reutiliser la mecanique FullScreenIntent + sonnerie.
  /// On stocke temporairement le payload dans une var top-level pour que
  /// le callback `FcmService.init.onDataMessage` puisse le recuperer.
  void _deferIncomingOffer(LaunchTarget target) {
    // On repousse le payload afin que FcmService.init.onDataMessage
    // (branche dans main) le consomme via IncomingDeliveryDispatcher
    // .handleRaw une fois le ProviderScope pret.
    _pendingColdStartOffer = target;
    // L'IncomingDeliveryScreen sera declenche quand le callback
    // FcmService sera branche (quelques ms apres le first frame du home).
  }

  @override
  void dispose() {
    _liquidController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    // Le texte a la même couleur que le fond pour être invisible au départ
    // et devient visible uniquement quand le liquide coloré passe derrière
    final textColor = backgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Animation de liquide en arrière-plan
          AnimatedBuilder(
            animation: _liquidAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: LiquidPainter(
                  animationValue: _liquidAnimation.value,
                  color: primaryColor,
                ),
                child: Container(),
              );
            },
          ),

          // Contenu au-dessus de l'animation
          SafeArea(
            child: Column(
              children: [
                // Spacer pour centrer le contenu verticalement
                const Spacer(flex: 5),

                // Logo "ZEET" avec "rider" en exposé
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Texte "ZEET"
                    Text(
                      'ZEET',
                      style: GoogleFonts.outfit(
                        fontSize: 64.sp,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: 3.w,
                        height: 1.0,
                      ),
                    ),
                    // "rider" en exposé (superscript)
                    Padding(
                      padding: EdgeInsets.only(top: 6.h, left: 6.w),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          'rider',
                          style: GoogleFonts.outfit(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: textColor.withValues(alpha: 0.85),
                            letterSpacing: 1.2.w,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 32.h),

                // Sous-texte animé
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48.w),
                    child: Text(
                      'Livrez avec rapidité et efficacité',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.8),
                        letterSpacing: 0.8.w,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),

                // Spacer pour équilibrer la disposition
                const Spacer(flex: 5),

                // Texte en bas pour l'équilibre
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 32.h),
                    child: Text(
                      'Propulsé par ZEET © 2025',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: textColor.withValues(alpha: 0.6),
                        letterSpacing: 0.5.w,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Payload d'offre cold-start en attente d'etre consomme par le handler
/// FCM (cf. `_MyAppState.initState` dans main.dart). Declaration
/// top-level pour etre accessible par [consumeColdStartOfferPayload].
LaunchTarget? _pendingColdStartOffer;

/// API publique minimale : main.dart appelle ceci apres le premier
/// `postFrameCallback` du home (via `FcmService.init`) pour dispatcher
/// l'offre cold-start eventuelle via `IncomingDeliveryDispatcher`.
///
/// Consomable une seule fois.
Map<String, dynamic>? consumeColdStartOfferPayload() {
  final LaunchTarget? t = _pendingColdStartOffer;
  _pendingColdStartOffer = null;
  if (t == null) return null;
  return Map<String, dynamic>.from(t.rawPayload);
}

// Custom Painter pour l'animation de liquide
class LiquidPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  LiquidPainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Hauteur du liquide (monte du bas vers le haut)
    final liquidHeight = size.height * animationValue;
    final waveHeight = 20.0;
    final waveLength = size.width / 2;

    // Si le liquide a atteint le haut, remplir tout l'écran
    if (liquidHeight >= size.height) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(path, paint);
      return;
    }

    // Commencer du coin inférieur gauche
    path.moveTo(0, size.height);

    // Ligne gauche jusqu'à la hauteur du liquide
    path.lineTo(0, size.height - liquidHeight + waveHeight);

    // Créer des vagues sur le dessus du liquide
    for (double i = 0; i <= size.width; i++) {
      final wave1 = sin((i / waveLength) * 2 * pi) * waveHeight;
      final wave2 = sin((i / waveLength) * 2 * pi + pi / 2) * (waveHeight / 2);
      final waveY = size.height - liquidHeight + wave1 + wave2;
      // S'assurer que les vagues ne dépassent pas le haut de l'écran
      path.lineTo(i, waveY.clamp(0, size.height));
    }

    // Ligne droite jusqu'au coin inférieur droit
    path.lineTo(size.width, size.height);

    // Fermer le chemin
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(LiquidPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
