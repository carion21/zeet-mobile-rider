// lib/screens/delivery_details/index.dart
//
// Orchestrateur de l'ecran detail de livraison. Compose les sous-widgets
// autonomes situes dans `widgets/`. La logique des 5 actions critiques
// (accept/reject/collect/deliver/notDelivered) reste ici car elle pilote
// `missionDetailProvider` + `missionsListProvider`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/mission_status.dart';
import 'package:rider/core/widgets/app_popup.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:rider/providers/earnings_provider.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_collapsed_card.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_error_view.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_header.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_info_card.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_loading_pill.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_map_section.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_nav_info_bar.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_otp_section.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_progress_header.dart';
import 'package:rider/screens/delivery_details/widgets/mission_completed_sheet.dart';
import 'package:rider/screens/delivery_details/widgets/primary_step_action.dart';
import 'package:rider/screens/delivery_details/widgets/report_issue_sheet.dart';

class DeliveryDetailsScreen extends ConsumerStatefulWidget {
  /// ID de la mission a charger depuis l'API.
  final String? missionId;

  const DeliveryDetailsScreen({
    super.key,
    this.missionId,
  });

  @override
  ConsumerState<DeliveryDetailsScreen> createState() =>
      _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends ConsumerState<DeliveryDetailsScreen>
    with WidgetsBindingObserver {
  // Infos de navigation calculees par le map child via callback.
  String _estimatedArrival = '--:--';
  double _routeDistance = 0.0;
  int _estimatedTime = 0;
  bool _isLoadingRoute = true;

  // Etat du bloc d'informations (deplie / replie).
  bool _isExpanded = true;

  // Anti-double-tap : verrou local pour les 5 actions critiques. Empeche les
  // re-entrees pendant qu'une action est en vol (audit C5 / Phase 2.2).
  bool _busy = false;

  // ID memoisé au mount (audit C5 + Phase 1.3) — evite les `int.parse` repetes.
  int? _missionIdInt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _missionIdInt = int.tryParse(widget.missionId ?? '');
    if (widget.missionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(missionDetailProvider.notifier).load(widget.missionId!);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refetch silencieux au retour foreground (Phase 1.3).
    if (state == AppLifecycleState.resumed && widget.missionId != null) {
      final id = _missionIdInt ?? -1;
      if (id != -1) {
        ref.read(missionDetailProvider.notifier).silentRefresh(id);
      }
    }
  }

  void _toggleExpanded() => setState(() => _isExpanded = !_isExpanded);

  /// Garde-fou commun aux 5 actions : verifie l'ID + acquiert le verrou.
  /// Retourne `null` si la mission est invalide (toast + back ont ete declenches).
  /// Sinon retourne l'ID parse, et bascule `_busy=true`.
  int? _beginAction() {
    if (_busy) return null;
    final id = _missionIdInt;
    if (id == null) {
      AppToast.showError(context: context, message: 'Mission invalide');
      Routes.goBack();
      return null;
    }
    setState(() => _busy = true);
    return id;
  }

  void _endAction() {
    if (mounted) setState(() => _busy = false);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleAccept() async {
    final id = _beginAction();
    if (id == null) return;
    try {
      await ZeetHaptics.warning();
      final result = await ref.read(missionDetailProvider.notifier).accept();
      if (!mounted) return;

      if (result['success'] == true) {
        ref
            .read(missionsListProvider.notifier)
            .updateMissionStatus(id, 'accepted');
        AppToast.showSuccess(
            context: context, message: result['message'] as String);
      } else {
        AppToast.showError(
            context: context, message: result['message'] as String);
      }
    } finally {
      _endAction();
    }
  }

  Future<void> _handleReject() async {
    final id = _beginAction();
    if (id == null) return;
    try {
      await ZeetHaptics.heavy();
      if (!mounted) return;

      // Confirmation prealable (Phase 3.7) — refus = action irreversible.
      final confirmed = await AppPopup.showConfirmation(
        context: context,
        title: 'Refuser la mission ?',
        message: "Tu ne pourras plus l'accepter ensuite.",
        confirmLabel: 'Refuser',
        cancelLabel: 'Annuler',
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;

      final reason = await DeliveryOtpDialogs.showLegacyReasonDialog(
        context: context,
        title: 'Refuser la mission',
        hint: 'Raison du refus',
      );
      if (reason == null || reason.isEmpty) return;

      final result =
          await ref.read(missionDetailProvider.notifier).reject(reason: reason);
      if (!mounted) return;

      if (result['success'] == true) {
        ref.read(missionsListProvider.notifier).removeMission(id);
        AppToast.showSuccess(
            context: context, message: result['message'] as String);
        Routes.goBack();
      } else {
        AppToast.showError(
            context: context, message: result['message'] as String);
      }
    } finally {
      _endAction();
    }
  }

  Future<void> _handleCollect() async {
    final id = _beginAction();
    if (id == null) return;
    try {
      await ZeetHaptics.warning();
      if (!mounted) return;
      // OTP 4 cases avec auto-submit + tentatives.
      final otp = await DeliveryOtpDialogs.showOtpDialog(
        context: context,
        title: 'Code de collecte',
        subtitle: 'Le partenaire te le donne — 4 chiffres',
        length: 4,
        onValidate: (code) async {
          final result = await ref
              .read(missionDetailProvider.notifier)
              .collect(otpCode: code);
          if (result['success'] == true) {
            // Optimistic: on retourne null pour fermer le dialog.
            return null;
          }
          return (result['message'] as String?) ?? 'Code invalide';
        },
      );
      if (otp == null || !mounted) return;
      // Update local + toast (l'optimistic + queue gere le sync).
      ref
          .read(missionsListProvider.notifier)
          .updateMissionStatus(id, 'collected');
      AppToast.showSuccess(context: context, message: 'Commande recuperee');
    } finally {
      _endAction();
    }
  }

  Future<void> _handleDeliver() async {
    final id = _beginAction();
    if (id == null) return;
    try {
      await ZeetHaptics.warning();
      if (!mounted) return;
      final num fee = ref.read(missionDetailProvider).mission?.fee ?? 0;

      final otp = await DeliveryOtpDialogs.showOtpDialog(
        context: context,
        title: 'Code de livraison',
        subtitle: 'Le client te le donne — 4 chiffres',
        length: 4,
        onValidate: (code) async {
          final result = await ref
              .read(missionDetailProvider.notifier)
              .deliver(otpCode: code);
          if (result['success'] == true) return null;
          return (result['message'] as String?) ?? 'Code invalide';
        },
      );
      if (otp == null || !mounted) return;

      ZeetHaptics.heavy();
      ref
          .read(missionsListProvider.notifier)
          .updateMissionStatus(id, 'delivered');
      // Plan §3.5 : compte courses jour pour amplifier le jalon (5e/10e/20e).
      // +1 car on vient d'en valider une (le provider n'a pas encore rafraîchi).
      final summary = ref.read(earningsSummaryProvider).summary;
      final int countToday = (summary?.completedDeliveries ?? 0) + 1;
      // Peak moment puis pop l'ecran : 1 tap au lieu de 2 pour quitter
      // (skill `zeet-3-clicks-rule` — actions recurrentes en 1 tap).
      await showMissionCompletedSheet(
        context,
        fee: fee,
        success: true,
        deliveriesToday: countToday,
      );
      if (!mounted) return;
      Routes.goBack();
    } finally {
      _endAction();
    }
  }

  Future<void> _handleNotDelivered() async {
    final id = _beginAction();
    if (id == null) return;
    try {
      await ZeetHaptics.heavy();
      if (!mounted) return;
      final result = await DeliveryOtpDialogs.showReasonDialog(
        context: context,
        title: 'Livraison impossible',
        includeGeo: true,
      );
      if (result == null || result.reason.isEmpty) return;

      final apiResult =
          await ref.read(missionDetailProvider.notifier).notDelivered(
                reason: result.reason,
                lat: result.geoLat,
                lng: result.geoLng,
              );
      if (!mounted) return;

      if (apiResult['success'] == true) {
        ref
            .read(missionsListProvider.notifier)
            .updateMissionStatus(id, 'not-delivered');
        await showMissionCompletedSheet(context, fee: 0, success: false);
        if (!mounted) return;
        Routes.goBack();
      } else {
        AppToast.showError(
            context: context, message: apiResult['message'] as String);
      }
    } finally {
      _endAction();
    }
  }

  void _handleClose() => Routes.goBack();

  // ---------------------------------------------------------------------------
  // Skeleton loader (Phase 3.8) — remplace le CircularProgressIndicator plein
  // ecran par une silhouette de la page (header pill, map placeholder, info
  // card avec boutons d'action). Reduit l'effet "vide" pendant le fetch et
  // mime la structure attendue.
  // ---------------------------------------------------------------------------

  Widget _buildLoadingSkeleton(bool isDarkMode) {
    final Color base = isDarkMode
        ? AppColors.darkSurface
        : ZeetColors.surfaceAlt;
    return Stack(
      children: [
        // Map placeholder full screen.
        Positioned.fill(
          child: Container(color: base),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header pill (titre + bouton report).
                Row(
                  children: const [
                    ZeetSkeleton.circle(size: 36),
                    SizedBox(width: 12),
                    Expanded(
                      child: ZeetSkeleton(height: 18),
                    ),
                    SizedBox(width: 12),
                    ZeetSkeleton.circle(size: 36),
                  ],
                ),
                const Spacer(),
                // Nav info bar (distance / duree / arrivee).
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.darkBackground
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: const [
                      Expanded(child: ZeetSkeleton(height: 14)),
                      SizedBox(width: 12),
                      Expanded(child: ZeetSkeleton(height: 14)),
                      SizedBox(width: 12),
                      Expanded(child: ZeetSkeleton(height: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Info card + boutons d'action.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.darkBackground
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ZeetSkeleton(width: 140, height: 16),
                      SizedBox(height: 12),
                      ZeetSkeleton(height: 14),
                      SizedBox(height: 8),
                      ZeetSkeleton(width: 220, height: 14),
                      SizedBox(height: 20),
                      ZeetSkeleton(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(missionDetailProvider);
    final mission = detailState.mission;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : Colors.white;

    if (mission?.distance != null) {
      _routeDistance = mission!.distance!;
    }

    final MissionStatusVisual visual =
        MissionStatusVisual.resolve(mission?.status);
    // Couleur pilotee par le backend (`last_delivery_status.color`).
    // Fallback neutre du design system si null (pas de switch local).
    final Color statusColor = mission?.statusColor ?? ZeetColors.inkMuted;
    // Edge case : pas de statut (mission encore en chargement) -> on remplace
    // le label « inconnu » par « Chargement... » pour rester coherent avec
    // l'ancien helper local, sans toucher au mapping global.
    final String statusLabel = (mission?.status == null ||
            (mission?.status?.isEmpty ?? true))
        ? 'Chargement...'
        : (mission?.lastDeliveryStatus?.label ??
            mission?.order?.lastOrderStatus?.label ??
            visual.label);

    // PopScope : bloque le swipe back accidentel pendant qu'une action
    // critique est en cours (collect/deliver/OTP). Skill `zeet-gesture-grammar`
    // §PopScope. canPop=false dès qu'on est en busy.
    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || !_busy) return;
        // Feedback minimal pour signaler que l'action est en cours.
        ZeetHaptics.success();
      },
      child: Scaffold(
      backgroundColor: backgroundColor,
      body: detailState.isLoading
          ? _buildLoadingSkeleton(isDarkMode)
          : detailState.errorMessage != null
              ? DeliveryErrorView(
                  message: detailState.errorMessage!,
                  textColor: textColor,
                  onRetry: widget.missionId == null
                      ? null
                      : () => ref
                          .read(missionDetailProvider.notifier)
                          .load(widget.missionId!),
                )
              : Stack(
                  children: [
                    DeliveryMapSection(
                      mission: mission,
                      onLoadingChanged: (loading) {
                        if (!mounted || loading == _isLoadingRoute) return;
                        setState(() => _isLoadingRoute = loading);
                      },
                      onRouteResolved: (info) {
                        if (!mounted) return;
                        setState(() {
                          _routeDistance = info.distanceKm;
                          _estimatedTime = info.durationMinutes;
                          _estimatedArrival = info.estimatedArrival;
                        });
                      },
                    ),
                    if (_isLoadingRoute) const DeliveryLoadingPill(),
                    SafeArea(
                      child: Column(
                        children: [
                          DeliveryHeader(
                            missionId: widget.missionId,
                            deliveryCode: mission?.displayCode,
                            deliveryCodeShort: mission?.shortDeliveryCode,
                            orderCode: mission?.orderCode,
                            orderCodeShort: mission?.shortOrderCode,
                            statusLabel: mission?.statusLabel,
                            statusColor: statusColor,
                            missionDbId: mission?.id,
                            // Bouton "Signaler un souci" disponible uniquement
                            // sur une mission active (pas sur les terminees).
                            // Skill `zeet-3-clicks-rule` — support a 2 taps.
                            onReportIssue: mission == null
                                ? null
                                : () => showReportIssueSheet(
                                      context,
                                      missionRef: mission.orderReference,
                                      missionId: mission.id.toString(),
                                      addressContext:
                                          mission.dropoffAddress?.label ??
                                              mission.pickupAddress?.label,
                                    ),
                          ),
                          // Progression 3 segments : Récup → Trajet → Livraison.
                          // Stateless / tokens uniquement, animé en ZeetMotion.md
                          // sur changement de status.
                          DeliveryProgressHeader(
                            missionStatus: mission?.status,
                          ),
                          const Spacer(),
                          GestureDetector(
                            onVerticalDragEnd: (details) {
                              final v = details.primaryVelocity ?? 0;
                              if (v < 0 && !_isExpanded) _toggleExpanded();
                              if (v > 0 && _isExpanded) _toggleExpanded();
                            },
                            child: AnimatedCrossFade(
                              firstChild: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DeliveryNavInfoBar(
                                    routeDistance: _routeDistance,
                                    estimatedTime: _estimatedTime,
                                    estimatedArrival: _estimatedArrival,
                                    isExpanded: _isExpanded,
                                    onToggle: _toggleExpanded,
                                  ),
                                  if (mission != null) ...[
                                    // CTA primaire slide-to-confirm pour les
                                    // étapes Récup (accepted) et Trajet
                                    // (collected/on-the-way). Sur les autres
                                    // statuts → SizedBox.shrink, et la card
                                    // ci-dessous gère les boutons (accept,
                                    // reject, terminal). On masque ici la
                                    // double action en passant
                                    // `hidePrimaryStepActions: true`.
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          ZeetSpacing.x4,
                                          ZeetSpacing.x2,
                                          ZeetSpacing.x4,
                                          ZeetSpacing.x0),
                                      child: PrimaryStepAction(
                                        missionStatus: mission.status,
                                        enabled: !(detailState.isActionLoading ||
                                            _busy),
                                        onConfirm: () {
                                          final s = (mission.status ?? '')
                                              .replaceAll('_', '-');
                                          if (s == 'accepted') {
                                            _handleCollect();
                                          } else {
                                            _handleDeliver();
                                          }
                                        },
                                      ),
                                    ),
                                    // Verrou local OR isActionLoading global :
                                    // disable visuellement les boutons +
                                    // ignore les taps pendant un in-flight
                                    // (Phase 2.2).
                                    IgnorePointer(
                                      ignoring: _busy,
                                      child: DeliveryInfoCard(
                                        mission: mission,
                                        statusColor: statusColor,
                                        statusText: statusLabel,
                                        isActionLoading:
                                            detailState.isActionLoading ||
                                                _busy,
                                        hidePrimaryStepActions: true,
                                        onAccept: _handleAccept,
                                        onReject: _handleReject,
                                        onCollect: _handleCollect,
                                        onDeliver: _handleDeliver,
                                        onNotDelivered: _handleNotDelivered,
                                        onClose: _handleClose,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              secondChild: DeliveryCollapsedCard(
                                mission: mission,
                                routeDistance: _routeDistance,
                                estimatedTime: _estimatedTime,
                                estimatedArrival: _estimatedArrival,
                                onExpand: _toggleExpanded,
                              ),
                              crossFadeState: _isExpanded
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              duration: ZeetMotion.md,
                              firstCurve: ZeetCurves.standard,
                              secondCurve: ZeetCurves.standard,
                              sizeCurve: ZeetCurves.standard,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
