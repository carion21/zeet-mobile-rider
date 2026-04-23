// lib/screens/delivery_details/index.dart
//
// Orchestrateur de l'ecran detail de livraison. Compose les sous-widgets
// autonomes situes dans `widgets/`. La logique des 5 actions critiques
// (accept/reject/collect/deliver/notDelivered) reste ici car elle pilote
// `missionDetailProvider` + `missionsListProvider`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/mission_status.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_collapsed_card.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_error_view.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_header.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_info_card.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_loading_pill.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_map_section.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_nav_info_bar.dart';
import 'package:rider/screens/delivery_details/widgets/delivery_otp_section.dart';
import 'package:rider/screens/delivery_details/widgets/mission_completed_sheet.dart';
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

class _DeliveryDetailsScreenState extends ConsumerState<DeliveryDetailsScreen> {
  // Infos de navigation calculees par le map child via callback.
  String _estimatedArrival = '--:--';
  double _routeDistance = 0.0;
  int _estimatedTime = 0;
  bool _isLoadingRoute = true;

  // Etat du bloc d'informations (deplie / replie).
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    if (widget.missionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(missionDetailProvider.notifier).load(widget.missionId!);
      });
    }
  }

  void _toggleExpanded() => setState(() => _isExpanded = !_isExpanded);

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleAccept() async {
    await HapticFeedback.mediumImpact();
    final result = await ref.read(missionDetailProvider.notifier).accept();
    if (!mounted) return;

    if (result['success'] == true) {
      ref.read(missionsListProvider.notifier).updateMissionStatus(
            int.parse(widget.missionId!),
            'accepted',
          );
      AppToast.showSuccess(context: context, message: result['message'] as String);
    } else {
      AppToast.showError(context: context, message: result['message'] as String);
    }
  }

  Future<void> _handleReject() async {
    await HapticFeedback.heavyImpact();
    if (!mounted) return;
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
      ref
          .read(missionsListProvider.notifier)
          .removeMission(int.parse(widget.missionId!));
      AppToast.showSuccess(context: context, message: result['message'] as String);
      Routes.goBack();
    } else {
      AppToast.showError(context: context, message: result['message'] as String);
    }
  }

  Future<void> _handleCollect() async {
    await HapticFeedback.mediumImpact();
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
    ref.read(missionsListProvider.notifier).updateMissionStatus(
          int.parse(widget.missionId!),
          'collected',
        );
    AppToast.showSuccess(context: context, message: 'Commande recuperee');
  }

  Future<void> _handleDeliver() async {
    await HapticFeedback.mediumImpact();
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

    HapticFeedback.heavyImpact();
    ref.read(missionsListProvider.notifier).updateMissionStatus(
          int.parse(widget.missionId!),
          'delivered',
        );
    // Peak moment puis pop l'ecran : 1 tap au lieu de 2 pour quitter
    // (skill `zeet-3-clicks-rule` — actions recurrentes en 1 tap).
    await showMissionCompletedSheet(context, fee: fee, success: true);
    if (!mounted) return;
    Routes.goBack();
  }

  Future<void> _handleNotDelivered() async {
    await HapticFeedback.heavyImpact();
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
      ref.read(missionsListProvider.notifier).updateMissionStatus(
            int.parse(widget.missionId!),
            'not-delivered',
          );
      await showMissionCompletedSheet(context, fee: 0, success: false);
      if (!mounted) return;
      Routes.goBack();
    } else {
      AppToast.showError(
          context: context, message: apiResult['message'] as String);
    }
  }

  void _handleClose() => Routes.goBack();

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

    return Scaffold(
      backgroundColor: backgroundColor,
      body: detailState.isLoading
          ? const Center(child: CircularProgressIndicator())
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
                            orderReference: mission?.orderReference,
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
                                  if (mission != null)
                                    DeliveryInfoCard(
                                      mission: mission,
                                      statusColor: statusColor,
                                      statusText: statusLabel,
                                      isActionLoading:
                                          detailState.isActionLoading,
                                      onAccept: _handleAccept,
                                      onReject: _handleReject,
                                      onCollect: _handleCollect,
                                      onDeliver: _handleDeliver,
                                      onNotDelivered: _handleNotDelivered,
                                      onClose: _handleClose,
                                    ),
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
                              duration: const Duration(milliseconds: 300),
                              firstCurve: Curves.easeInOut,
                              secondCurve: Curves.easeInOut,
                              sizeCurve: Curves.easeInOut,
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
