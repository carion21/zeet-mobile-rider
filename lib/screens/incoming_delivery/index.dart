// Ecran "Incoming Delivery" — declenche quand une nouvelle offre de livraison
// arrive pour un rider (via push FCM, ou dev trigger en Phase 2).
//
// Principes :
//  - Plein ecran orange ZEET (priming couleur, focus total)
//  - Hierarchie neuro-UX rider : FEE (motivation) → DISTANCE/ETA (effort) →
//    PICKUP/DROPOFF (details)
//  - Sonnerie systeme en boucle (flutter_ringtone_player) — FORT, continu
//  - Minuteur circulaire AVEC deadline backend (rider a le tel sous les yeux,
//    deadline legitime contrairement au partner en cuisine)
//  - Slide-to-accept (anti faux positif sous gants, pluie, volant)
//  - Retour systeme bloque tant que le ringing est actif
//
// Wiring : ecoute [incomingDeliveryProvider].

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/models/incoming_delivery_payload.dart';
import 'package:rider/providers/incoming_delivery_provider.dart';
import 'package:rider/screens/delivery_details/widgets/reason_picker_sheet.dart';
import 'package:rider/screens/incoming_delivery/widgets/first_run_swipe_hint.dart';
import 'package:rider/screens/incoming_delivery/widgets/slide_to_accept.dart';
import 'package:rider/services/incoming_ring_bridge.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class IncomingDeliveryScreen extends ConsumerStatefulWidget {
  const IncomingDeliveryScreen({super.key});

  @override
  ConsumerState<IncomingDeliveryScreen> createState() =>
      _IncomingDeliveryScreenState();
}

class _IncomingDeliveryScreenState extends ConsumerState<IncomingDeliveryScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bg = ZeetColors.primary;
  static const Color _bgDark = ZeetColors.primaryDark;
  static const Color _ink = Colors.white;

  static final _currency = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  late final AnimationController _pulseController;
  Timer? _hapticTicker;
  bool _ringtonePlaying = false;
  bool _dismissing = false;
  int _lastSecondsRemainingHapticed = -1;
  // Suivi de la derniere version d'erreur traitee (pour ne pas declencher
  // le toast 409 plusieurs fois sur le meme evenement).
  int _lastHandledErrorVersion = 0;

  @override
  void initState() {
    super.initState();
    // Pulse breathing du ring de countdown. La cadence reste à 900ms
    // (bord rythmique du ringtone). reduceMotion : on suspend la repeat
    // dans `didChangeDependencies` pour respecter `MediaQuery.disableAnimations`
    // (skill `zeet-motion-system` §reduceMotion).
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _startRinging());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Toggle du pulse selon reduceMotion. En reduceMotion, on garde le ring
    // à l'état neutre (sans pulse) pour ne pas créer de mouvement parasite.
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0.5;
      }
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _startRinging() async {
    if (_ringtonePlaying) return;
    _ringtonePlaying = true;

    final payload = ref.read(incomingDeliveryProvider).payload;
    final title = payload?.title ?? 'Nouvelle livraison';
    final body = payload?.body ?? '';

    // Source de verite Phase 4 : service natif (MediaPlayer + loop).
    await IncomingRingBridge.startFake(title: title, body: body);

    // Fallback in-process (iOS / dev simulator / echec du channel).
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: IosSounds.alarm,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    } catch (e) {
      debugPrint('[IncomingDeliveryScreen] ringtone fallback failed: $e');
    }

    await ZeetHaptics.heavy();
    _hapticTicker?.cancel();
    // 1100ms hors échelle ZeetMotion : cadence de pulse alignée sur la sonnerie.
    _hapticTicker = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted) return;
      ZeetHaptics.heavy();
    });
  }

  Future<void> _stopRinging() async {
    _hapticTicker?.cancel();
    _hapticTicker = null;
    if (!_ringtonePlaying) return;
    _ringtonePlaying = false;

    // Stop natif (source de verite) + fallback Flutter.
    await IncomingRingBridge.stop();
    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('[IncomingDeliveryScreen] ringtone fallback stop failed: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopRinging();
    super.dispose();
  }

  void _listenForAutoClose(IncomingDeliveryState state) {
    if (_dismissing) return;

    // Haptic medium quand il reste 1s avant deadline (urgence finale).
    // Skill zeet-pos-ergonomics : feedback haptic obligatoire pour
    // moments critiques.
    if (state.phase == IncomingDeliveryPhase.ringing &&
        state.secondsRemaining == 1 &&
        _lastSecondsRemainingHapticed != 1) {
      _lastSecondsRemainingHapticed = 1;
      ZeetHaptics.warning();
    } else if (state.secondsRemaining > 1) {
      _lastSecondsRemainingHapticed = -1;
    }

    if (state.phase != IncomingDeliveryPhase.ringing && _ringtonePlaying) {
      _stopRinging();
    }

    // Bug C4 — phase `error` post-accept : si 409 (mission deja prise), on
    // ferme l'ecran avec un toast d'erreur. Pour les autres 4xx, on laisse
    // le banner d'erreur visible (l'utilisateur peut retry) et le slide
    // s'est deja reset via la nouvelle Key (errorResetVersion).
    if (state.phase == IncomingDeliveryPhase.error &&
        state.errorResetVersion != _lastHandledErrorVersion) {
      _lastHandledErrorVersion = state.errorResetVersion;
      if (state.errorStatusCode == 409) {
        _dismissing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Routes.goBack();
          final ctx = Routes.navigatorKey.currentContext;
          if (ctx != null) {
            AppToast.showError(
              context: ctx,
              message: 'Mission déjà prise par un autre rider',
            );
          }
          ref.read(incomingDeliveryProvider.notifier).dismiss();
        });
      }
    }

    if (state.phase == IncomingDeliveryPhase.accepted ||
        state.phase == IncomingDeliveryPhase.rejected) {
      _dismissing = true;
      final wasAccepted = state.phase == IncomingDeliveryPhase.accepted;
      final code = state.payload?.deliveryCode ?? '';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Routes.goBack();
        final ctx = Routes.navigatorKey.currentContext;
        if (ctx != null) {
          if (wasAccepted) {
            AppToast.showSuccess(
              context: ctx,
              message: code.isNotEmpty
                  ? 'Livraison $code acceptee'
                  : 'Livraison acceptee',
            );
          } else {
            AppToast.showWarning(
              context: ctx,
              message: code.isNotEmpty
                  ? 'Livraison $code refusee'
                  : 'Livraison refusee',
            );
          }
        }
        ref.read(incomingDeliveryProvider.notifier).dismiss();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incomingDeliveryProvider);
    _listenForAutoClose(state);

    final payload = state.payload;
    if (payload == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Routes.goBack();
      });
      return const Scaffold(
        backgroundColor: _bg,
        body: SizedBox.shrink(),
      );
    }

    return PopScope(
      canPop: !state.isActive,
      child: Scaffold(
        backgroundColor: _bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bg, _bgDark],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(state, payload),
                  SizedBox(height: 18.h),
                  _buildFeeBlock(payload),
                  SizedBox(height: 18.h),
                  Expanded(child: _buildAddressesCard(payload)),
                  SizedBox(height: 16.h),
                  if (state.errorMessage != null) _buildErrorBanner(state),
                  _buildActions(state),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header — "NOUVELLE LIVRAISON" + code + minuteur circulaire
  // ---------------------------------------------------------------------------

  Widget _buildHeader(IncomingDeliveryState state, IncomingDeliveryPayload p) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NOUVELLE LIVRAISON',
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.75),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                p.deliveryCode.isNotEmpty ? p.deliveryCode : '#${p.deliveryId}',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        _buildCountdownRing(state),
      ],
    );
  }

  Widget _buildCountdownRing(IncomingDeliveryState state) {
    final size = 68.w;
    // Degrade vert -> orange -> rouge selon le temps restant.
    // progress = 1 = full, 0 = expire.
    final ringColor = _resolveRingColor(state.progress);
    // Isole le repaint du ring -> evite de repaint le reste de l'ecran a
    // chaque tick (cf. zeet-performance-budget §3 RepaintBoundary).
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _ink.withValues(alpha: 0.18),
                ),
              ),
            ),
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: state.progress,
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${state.secondsRemaining}',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  'sec',
                  style: TextStyle(
                    color: _ink.withValues(alpha: 0.75),
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Interpole _ink (full) -> warning -> danger (expire) selon `progress`.
  /// progress in [0, 1]. Transition lissée par interpolation linéaire entre
  /// les 3 couleurs cible (skill `zeet-neuro-ux` §13 — pas de saut brutal).
  Color _resolveRingColor(double progress) {
    final double p = progress.clamp(0.0, 1.0);
    // Mapping : p=1.0 -> _ink ; p=0.5 -> warning ; p=0.0 -> danger.
    if (p >= 0.5) {
      // Segment haut : _ink → warning sur [0.5, 1.0].
      // t=0 quand p=0.5 (warning), t=1 quand p=1 (ink).
      final double t = (p - 0.5) / 0.5;
      return Color.lerp(ZeetColors.warning, _ink, t) ?? _ink;
    }
    // Segment bas : danger → warning sur [0.0, 0.5].
    // t=0 quand p=0 (danger), t=1 quand p=0.5 (warning).
    final double t = p / 0.5;
    return Color.lerp(ZeetColors.danger, ZeetColors.warning, t) ??
        ZeetColors.danger;
  }

  // ---------------------------------------------------------------------------
  // Fee block — motivation financiere (neuro-UX rider)
  // ---------------------------------------------------------------------------

  Widget _buildFeeBlock(IncomingDeliveryPayload p) {
    final formatted = _currency.format(p.deliveryFeeFcfa);

    return Column(
      children: [
        Text(
          'TU GAGNES',
          style: TextStyle(
            color: _ink.withValues(alpha: 0.75),
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        SizedBox(height: 6.h),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatted,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 56.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              height: 1,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        // Pill: distance · eta
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.route_rounded, color: _ink, size: 16.sp),
              SizedBox(width: 6.w),
              Text(
                '${p.distanceKm.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                width: 3.w,
                height: 3.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ink.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(width: 10.w),
              Icon(Icons.access_time_rounded, color: _ink, size: 16.sp),
              SizedBox(width: 6.w),
              Text(
                '${p.etaMinutes} min',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Addresses card — pickup + dropoff avec icones + separateur timeline
  // ---------------------------------------------------------------------------

  Widget _buildAddressesCard(IncomingDeliveryPayload p) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _ink.withValues(alpha: 0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AddressRow(
            icon: Icons.storefront_rounded,
            label: 'Ramassage',
            address: p.pickupAddress.isNotEmpty
                ? p.pickupAddress
                : 'Adresse de ramassage',
          ),
          // Timeline separator
          Padding(
            padding: EdgeInsets.only(left: 24.w, top: 8.h, bottom: 8.h),
            child: Column(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  child: Container(
                    width: 3.w,
                    height: 3.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _ink.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _AddressRow(
            icon: Icons.location_on_rounded,
            label: 'Livraison',
            address: p.dropoffAddress.isNotEmpty
                ? p.dropoffAddress
                : 'Adresse de livraison',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error banner
  // ---------------------------------------------------------------------------

  Widget _buildErrorBanner(IncomingDeliveryState state) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: _bgDark, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              state.errorMessage ?? 'Erreur',
              style: TextStyle(
                color: _bgDark,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(incomingDeliveryProvider.notifier).retryAfterError(),
            style: TextButton.styleFrom(
              foregroundColor: _bgDark,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              minimumSize: Size(48.w, 36.h),
            ),
            child: Text(
              'Réessayer',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Widget _buildActions(IncomingDeliveryState state) {
    final busy = state.isBusy;

    return Column(
      children: [
        // Coach-mark first-run : fleche animee + "Glisse vers la droite".
        // Disparait apres 6s ou definitivement apres 1ere apparition.
        // Skill `zeet-gesture-grammar` §6 (discoverability).
        const FirstRunSwipeHint(),
        SlideToAcceptButton(
          // Bug C4 — la Key inclut errorResetVersion : a chaque erreur
          // 4xx non transient, le widget est re-mount → le slide revient
          // a 0 (reset visuel garanti).
          key: ValueKey(
            '${state.payload?.deliveryId ?? 0}_${state.errorResetVersion}',
          ),
          label: busy ? 'CONFIRMATION...' : 'GLISSER POUR ACCEPTER',
          enabled: !busy && state.phase == IncomingDeliveryPhase.ringing,
          onCompleted: () {
            ref.read(incomingDeliveryProvider.notifier).accept();
          },
        ),
        SizedBox(height: 12.h),
        TextButton(
          onPressed: busy ? null : _showRejectDialog,
          style: TextButton.styleFrom(
            foregroundColor: _ink,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            minimumSize: Size(120.w, 48.h),
          ),
          child: Text(
            'Refuser la livraison',
            style: TextStyle(
              color: _ink.withValues(alpha: 0.85),
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: _ink.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showRejectDialog() async {
    await _stopRinging();
    if (!mounted) return;

    // ReasonPickerSheet (presets + champ libre + swipe-to-confirm)
    // — remplace l'ancien AlertDialog. Skill ZEET zeet-gesture-grammar
    // §swipe-to-confirm pour action irreversible.
    final result = await ReasonPickerSheet.show(
      context: context,
      title: 'Refuser la livraison',
      description:
          'Choisis un motif. La course sera proposee a un autre rider.',
      presets: const <String>[
        'Trop loin',
        'Pneu creve',
        'Fin de service',
        'Autre',
      ],
      includeGeo: false,
    );

    if (!mounted) return;

    if (result != null && result.reason.isNotEmpty) {
      await ref
          .read(incomingDeliveryProvider.notifier)
          .reject(reason: result.reason);
    } else {
      // Annulation du sheet → on relance la sonnerie, la livraison est
      // toujours active.
      if (ref.read(incomingDeliveryProvider).phase ==
          IncomingDeliveryPhase.ringing) {
        await _startRinging();
      }
    }
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;

  const _AddressRow({
    required this.icon,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Icon(icon, color: ZeetColors.primary, size: 22.sp),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
