// lib/screens/delivery_details/index.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/core/utils/phone_launcher.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/services/routing_service.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/screens/delivery_details/widgets/mission_logs_sheet.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

class DeliveryDetailsScreen extends ConsumerStatefulWidget {
  /// ID de la mission a charger depuis l'API.
  final String? missionId;

  const DeliveryDetailsScreen({
    super.key,
    this.missionId,
  });

  @override
  ConsumerState<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends ConsumerState<DeliveryDetailsScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Coordonnees
  late LatLng _pickupLocation;
  late LatLng _deliveryLocation;
  late LatLng _currentLocation;

  // Informations de navigation
  String _estimatedArrival = '';
  double _routeDistance = 0.0;
  int _estimatedTime = 0;

  // Etat du bloc d'informations
  bool _isExpanded = true;

  // Points de l'itineraire
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = true;

  // Animation
  late AnimationController _shimmerController;

  // OTP input controller
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _startShimmerAnimation();

    // Charger la mission depuis l'API
    if (widget.missionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(missionDetailProvider.notifier).load(widget.missionId!);
      });
    }

    // Initialiser avec des coordonnees par defaut (Abidjan)
    _pickupLocation = const LatLng(5.3364, -4.0267);
    _deliveryLocation = const LatLng(5.3478, -4.0123);
    _currentLocation = const LatLng(5.3400, -4.0200);

    _estimatedArrival = DateFormat('HH:mm').format(
      DateTime.now().add(const Duration(minutes: 25)),
    );
    _routeDistance = 3.0;
    _estimatedTime = 25;

    _calculateRoute();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startShimmerAnimation() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        await _shimmerController.forward();
        _shimmerController.reset();
      }
    }
  }

  void _toggleExpanded() {
    setState(() => _isExpanded = !_isExpanded);
  }

  void _updateLocationsFromMission(Mission mission) {
    final pickupLat = mission.pickupAddress?.lat ??
        mission.order?.partner?.address?.lat;
    final pickupLng = mission.pickupAddress?.lng ??
        mission.order?.partner?.address?.lng;
    final dropoffLat = mission.dropoffAddress?.lat ??
        mission.order?.customer?.address?.lat;
    final dropoffLng = mission.dropoffAddress?.lng ??
        mission.order?.customer?.address?.lng;

    if (pickupLat != null && pickupLng != null) {
      _pickupLocation = LatLng(pickupLat, pickupLng);
    }
    if (dropoffLat != null && dropoffLng != null) {
      _deliveryLocation = LatLng(dropoffLat, dropoffLng);
    }
    if (mission.distance != null) {
      _routeDistance = mission.distance!;
    }
    if (mission.estimatedTime != null) {
      _estimatedTime = mission.estimatedTime!;
      _estimatedArrival = DateFormat('HH:mm').format(
        DateTime.now().add(Duration(minutes: _estimatedTime)),
      );
    }
  }

  Future<void> _calculateRoute() async {
    setState(() => _isLoadingRoute = true);

    try {
      List<LatLng> waypoints = [_currentLocation, _pickupLocation, _deliveryLocation];

      if (waypoints.length > 1) {
        final result = await RoutingService.getRoute(
          locations: waypoints,
          costing: 'motorcycle',
        );

        if (result != null && mounted) {
          setState(() {
            _routePoints = result.points;
            _routeDistance = result.distanceKm;
            _estimatedTime = result.durationMinutes;
            _estimatedArrival = DateFormat('HH:mm').format(
              DateTime.now().add(Duration(minutes: result.durationMinutes)),
            );
            _isLoadingRoute = false;
          });
        }
      } else {
        setState(() => _isLoadingRoute = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routePoints = [_currentLocation, _pickupLocation, _deliveryLocation];
          _isLoadingRoute = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleAccept() async {
    // Haptic feedback POS : confirme le tap du rider sous gants.
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
    // Haptic plus fort sur action destructive pour alerter le rider.
    await HapticFeedback.heavyImpact();
    final reason = await _showReasonDialog('Refuser la mission', 'Raison du refus');
    if (reason == null || reason.isEmpty) return;

    final result = await ref.read(missionDetailProvider.notifier).reject(reason: reason);
    if (!mounted) return;

    if (result['success'] == true) {
      ref.read(missionsListProvider.notifier).removeMission(int.parse(widget.missionId!));
      AppToast.showSuccess(context: context, message: result['message'] as String);
      Routes.goBack();
    } else {
      AppToast.showError(context: context, message: result['message'] as String);
    }
  }

  Future<void> _handleCollect() async {
    await HapticFeedback.mediumImpact();
    final otp = await _showOtpDialog('Code de collecte', 'Entrez le code OTP du restaurant');
    if (otp == null || otp.isEmpty) return;

    final result = await ref.read(missionDetailProvider.notifier).collect(otpCode: otp);
    if (!mounted) return;

    if (result['success'] == true) {
      ref.read(missionsListProvider.notifier).updateMissionStatus(
        int.parse(widget.missionId!),
        'collected',
      );
      AppToast.showSuccess(context: context, message: result['message'] as String);
    } else {
      AppToast.showError(context: context, message: result['message'] as String);
    }
  }

  Future<void> _handleDeliver() async {
    await HapticFeedback.mediumImpact();
    final otp = await _showOtpDialog('Code de livraison', 'Entrez le code OTP du client');
    if (otp == null || otp.isEmpty) return;

    final result = await ref.read(missionDetailProvider.notifier).deliver(otpCode: otp);
    if (!mounted) return;

    if (result['success'] == true) {
      // Haptic de succès = double medium impact (boucle dopaminergique).
      await HapticFeedback.heavyImpact();
      ref.read(missionsListProvider.notifier).updateMissionStatus(
        int.parse(widget.missionId!),
        'delivered',
      );
      AppToast.showSuccess(context: context, message: result['message'] as String);
    } else {
      AppToast.showError(context: context, message: result['message'] as String);
    }
  }

  Future<void> _handleNotDelivered() async {
    await HapticFeedback.heavyImpact();
    final reason = await _showReasonDialog('Livraison impossible', 'Raison');
    if (reason == null || reason.isEmpty) return;

    final result = await ref.read(missionDetailProvider.notifier).notDelivered(reason: reason);
    if (!mounted) return;

    if (result['success'] == true) {
      ref.read(missionsListProvider.notifier).updateMissionStatus(
        int.parse(widget.missionId!),
        'not-delivered',
      );
      AppToast.showSuccess(context: context, message: result['message'] as String);
      Routes.goBack();
    } else {
      AppToast.showError(context: context, message: result['message'] as String);
    }
  }

  Future<String?> _showReasonDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showOtpDialog(String title, String hint) async {
    _otpController.clear();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: _otpController,
          decoration: InputDecoration(hintText: hint),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_otpController.text),
            child: const Text('Confirmer'),
          ),
        ],
      ),
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
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    AppSizes().initialize(context);

    // Mettre a jour les coordonnees si mission chargee
    if (mission != null) {
      _updateLocationsFromMission(mission);
    }

    // Statut / couleur
    Color statusColor;
    String statusText;

    final status = mission?.status ?? '';
    switch (status) {
      case 'assigned':
      case 'pending':
        statusColor = const Color(0xFFFFA500);
        statusText = 'Nouvelle livraison';
        break;
      case 'accepted':
        statusColor = const Color(0xFF2196F3);
        statusText = 'En route vers le restaurant';
        break;
      case 'collecting':
      case 'collected':
      case 'picked_up':
        statusColor = AppColors.primary;
        statusText = 'En route vers le client';
        break;
      case 'delivering':
        statusColor = AppColors.primary;
        statusText = 'En livraison';
        break;
      case 'delivered':
        statusColor = const Color(0xFF4CD964);
        statusText = 'Livraison terminée';
        break;
      case 'not_delivered':
      case 'not-delivered':
        statusColor = const Color(0xFFFF6B6B);
        statusText = 'Non livrée';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status.isNotEmpty ? status : 'Chargement...';
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: detailState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : detailState.errorMessage != null
              ? _buildErrorView(detailState.errorMessage!, textColor, textLightColor)
              : Stack(
                  children: [
                    // Carte en plein ecran
                    _buildMap(),

                    // Indicateur de chargement de l'itineraire
                    if (_isLoadingRoute)
                      Positioned(
                        top: 100,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Calcul de l\'itinéraire...',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Contenu par-dessus la carte
                    SafeArea(
                      child: Column(
                        children: [
                          _buildHeader(textColor, mission),
                          const Spacer(),
                          GestureDetector(
                            onVerticalDragEnd: (details) {
                              if (details.primaryVelocity! < 0) {
                                if (!_isExpanded) _toggleExpanded();
                              } else if (details.primaryVelocity! > 0) {
                                if (_isExpanded) _toggleExpanded();
                              }
                            },
                            child: AnimatedCrossFade(
                              firstChild: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildNavigationInfo(surfaceColor, textColor, textLightColor),
                                  if (mission != null)
                                    _buildMissionDetails(
                                      mission,
                                      surfaceColor,
                                      textColor,
                                      textLightColor,
                                      statusColor,
                                      statusText,
                                      detailState.isActionLoading,
                                    ),
                                ],
                              ),
                              secondChild: _buildCollapsedView(
                                mission,
                                surfaceColor,
                                textColor,
                                textLightColor,
                                statusColor,
                                statusText,
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

  Widget _buildErrorView(String error, Color textColor, Color textLightColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconManager.getIcon('error', color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(error, style: TextStyle(color: textColor, fontSize: 16.sp)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (widget.missionId != null) {
                ref.read(missionDetailProvider.notifier).load(widget.missionId!);
              }
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation,
        initialZoom: 13.0,
        minZoom: 10.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zeet.rider',
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 5.0,
                color: AppColors.primary,
                borderStrokeWidth: 2.0,
                borderColor: Colors.white.withValues(alpha: 0.5),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: _currentLocation,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.navigation, color: Colors.white, size: 20),
              ),
            ),
            Marker(
              point: _pickupLocation,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
              ),
            ),
            Marker(
              point: _deliveryLocation,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4CD964),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(Color textColor, Mission? mission) {
    return Padding(
      padding: EdgeInsets.all(AppSizes().paddingMedium),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Routes.goBack(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back, color: AppColors.text, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              mission?.orderReference ?? '#...',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // Bouton historique de mission (logs)
          if (mission != null)
            GestureDetector(
              onTap: () => showMissionLogsSheet(
                context,
                missionId: mission.id.toString(),
              ),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: AppColors.text,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationInfo(Color surfaceColor, Color textColor, Color textLightColor) {
    return Container(
      margin: EdgeInsets.only(
        left: AppSizes().paddingLarge,
        right: AppSizes().paddingLarge,
        bottom: 10,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavInfoItem(
                  iconName: 'location_on',
                  value: '${_routeDistance.toStringAsFixed(1)} km',
                  label: 'Distance',
                  color: const Color(0xFF4CD964),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: textLightColor.withValues(alpha: 0.2),
                ),
                _buildNavInfoItem(
                  iconName: 'access_time',
                  value: '$_estimatedTime min',
                  label: 'Temps',
                  color: const Color(0xFFFF6B6B),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: textLightColor.withValues(alpha: 0.2),
                ),
                _buildNavInfoItem(
                  iconName: 'clock',
                  value: _estimatedArrival,
                  label: 'Arrivée',
                  color: AppColors.primary,
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: -20,
            child: GestureDetector(
              onTap: _toggleExpanded,
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: AppColors.primary,
                      size: 24.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavInfoItem({
    required String iconName,
    required String value,
    required String label,
    required Color color,
    required Color textColor,
    required Color textLightColor,
  }) {
    return Column(
      children: [
        IconManager.getIcon(iconName, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: textLightColor,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildMissionDetails(
    Mission mission,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    Color statusColor,
    String statusText,
    bool isActionLoading,
  ) {
    return Container(
      margin: EdgeInsets.all(AppSizes().paddingLarge),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Restaurant
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconManager.getIcon('restaurant', color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.partnerName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mission.pickupAddressDisplay,
                      style: TextStyle(color: textLightColor, fontSize: 13.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (mission.partnerPhone != null)
                IconButton(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await launchPhoneCall(
                      mission.partnerPhone!,
                      context: context,
                    );
                  },
                  tooltip: 'Appeler le restaurant',
                  icon: IconManager.getIcon('phone', color: AppColors.primary, size: 22),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Ligne de separation
          Row(
            children: [
              const SizedBox(width: 20),
              Column(
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textLightColor.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Client
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CD964).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconManager.getIcon('person', color: const Color(0xFF4CD964), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.customerName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mission.dropoffAddressDisplay,
                      style: TextStyle(color: textLightColor, fontSize: 13.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (mission.customerPhone != null)
                IconButton(
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    await launchPhoneCall(
                      mission.customerPhone!,
                      context: context,
                    );
                  },
                  tooltip: 'Appeler le client',
                  icon: IconManager.getIcon('phone', color: const Color(0xFF4CD964), size: 22),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Informations de commande
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Détails de commande',
                      style: TextStyle(color: textLightColor, fontSize: 12.sp),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mission.itemCountText,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Frais de livraison',
                      style: TextStyle(color: textLightColor, fontSize: 12.sp),
                    ),
                    const SizedBox(height: 4),
                    ZeetMoney(
                      amount: mission.fee,
                      currency: ZeetCurrency.fcfa,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Boutons d'action selon le statut
          _buildActionButtons(mission, statusColor, isActionLoading),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Mission mission, Color statusColor, bool isLoading) {
    // Transition fluide entre les CTAs lors du changement de statut mission.
    // Le switcher du design system encapsule fade + slide sur tokens motion
    // (vague 3+ : on a remplacé l'AnimatedSwitcher custom par ZeetStateSwitcher).
    final String stateKey = isLoading ? 'loading' : (mission.status ?? 'none');
    return ZeetStateSwitcher(
      stateKey: stateKey,
      alignment: Alignment.topCenter,
      child: _actionButtonsFor(mission, statusColor, isLoading),
    );
  }

  Widget _actionButtonsFor(Mission mission, Color statusColor, bool isLoading) {
    if (isLoading) {
      return const Center(
        key: ValueKey('buttons_loading'),
        child: CircularProgressIndicator(),
      );
    }

    final status = mission.status ?? '';

    switch (status) {
      case 'assigned':
      case 'pending':
        return Column(
          key: const ValueKey('buttons_assigned'),
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CD964),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Accepter la livraison',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _handleReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                  side: const BorderSide(color: Color(0xFFFF6B6B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Refuser',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );

      case 'accepted':
        return Column(
          key: const ValueKey('buttons_accepted'),
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleCollect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'J\'ai récupéré la commande',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _handleNotDelivered,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                  side: const BorderSide(color: Color(0xFFFF6B6B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Signaler un problème',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );

      case 'collecting':
      case 'collected':
      case 'picked_up':
      case 'delivering':
        return Column(
          key: const ValueKey('buttons_delivering'),
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleDeliver,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CD964),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Livraison effectuée',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: _handleNotDelivered,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                  side: const BorderSide(color: Color(0xFFFF6B6B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Livraison impossible',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );

      case 'delivered':
      case 'not_delivered':
      case 'not-delivered':
      case 'cancelled':
      case 'canceled':
        return SizedBox(
          key: const ValueKey('buttons_final'),
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Routes.goBack(),
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Retour',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
          ),
        );

      default:
        return const SizedBox.shrink(key: ValueKey('buttons_none'));
    }
  }

  Widget _buildCollapsedView(
    Mission? mission,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    Color statusColor,
    String statusText,
  ) {
    return Container(
      margin: EdgeInsets.all(AppSizes().paddingLarge),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle de drag
          GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textLightColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

          // Timeline horizontale avec infos
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CD964).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: IconManager.getIcon('location_on', color: const Color(0xFF4CD964), size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_routeDistance.toStringAsFixed(1)} km',
                            style: TextStyle(color: textColor, fontSize: 15.sp, fontWeight: FontWeight.bold),
                          ),
                          Text('Distance', style: TextStyle(color: textLightColor, fontSize: 11.sp)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: textLightColor.withValues(alpha: 0.2)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: IconManager.getIcon('access_time', color: const Color(0xFFFF6B6B), size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_estimatedTime min',
                            style: TextStyle(color: textColor, fontSize: 15.sp, fontWeight: FontWeight.bold),
                          ),
                          Text('Temps', style: TextStyle(color: textLightColor, fontSize: 11.sp)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: textLightColor.withValues(alpha: 0.2)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: IconManager.getIcon('clock', color: AppColors.primary, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _estimatedArrival,
                            style: TextStyle(color: textColor, fontSize: 15.sp, fontWeight: FontWeight.bold),
                          ),
                          Text('Arrivée', style: TextStyle(color: textLightColor, fontSize: 11.sp)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progression
          _buildProgressLine(textLightColor.withValues(alpha: 0.2), mission?.status),

          // Informations essentielles
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mission?.partnerName ?? 'Restaurant',
                              style: TextStyle(color: textColor, fontSize: 13.sp, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(color: Color(0xFF4CD964), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mission?.customerName ?? 'Client',
                              style: TextStyle(color: textColor, fontSize: 13.sp, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ZeetMoney(
                    amount: mission?.fee ?? 0,
                    currency: ZeetCurrency.fcfa,
                    style: TextStyle(color: AppColors.primary, fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLine(Color dividerColor, String? status) {
    double progress = 0.0;
    if (status == 'accepted') {
      progress = 0.3;
    } else if (status == 'collecting' || status == 'collected' || status == 'picked_up' || status == 'delivering') {
      progress = 0.65;
    } else if (status == 'delivered') {
      progress = 1.0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(color: dividerColor, borderRadius: BorderRadius.circular(1.5)),
              ),
              if (progress > 0)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: Stack(
                      children: [
                        Container(
                          height: 3,
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(1.5)),
                        ),
                        if (_shimmerController.value > 0 && progress < 1.0)
                          Positioned(
                            left: -100 + (_shimmerController.value * 200),
                            child: Container(
                              width: 100,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.6),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (progress > 0 && progress < 1.0)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: IconManager.getIcon('motorcycle', color: Colors.white, size: 12),
                    ),
                  ),
                ),
              if (progress >= 1.0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFF4CD964), shape: BoxShape.circle),
                    child: IconManager.getIcon('check', color: Colors.white, size: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
