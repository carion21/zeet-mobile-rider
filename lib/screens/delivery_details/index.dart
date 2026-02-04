// lib/screens/delivery_details/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/services/routing_service.dart';
import 'package:rider/models/delivery_model.dart';
import 'package:intl/intl.dart';

class DeliveryDetailsScreen extends StatefulWidget {
  final Delivery delivery;

  const DeliveryDetailsScreen({
    super.key,
    required this.delivery,
  });

  @override
  State<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends State<DeliveryDetailsScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Coordonnées simulées pour la démo
  // TODO: Remplacer par les vraies coordonnées depuis l'API
  late LatLng _pickupLocation;
  late LatLng _deliveryLocation;
  late LatLng _currentLocation;

  // Informations de navigation
  String _estimatedArrival = '';
  double _routeDistance = 0.0;
  int _estimatedTime = 0;

  // État du bloc d'informations (réduit ou agrandi)
  bool _isExpanded = true;

  // Points de l'itinéraire
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = true;

  // Animation de la timeline
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _initializeLocations();
    _calculateRoute();

    // Initialiser l'animation de la timeline (effet de lumière)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Démarrer l'animation shimmer toutes les 5 secondes
    _startShimmerAnimation();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
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
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _initializeLocations() {
    // Coordonnées simulées pour Abidjan
    _pickupLocation = const LatLng(5.3364, -4.0267); // Restaurant (Cocody)
    _deliveryLocation = const LatLng(5.3478, -4.0123); // Client (Riviera)
    _currentLocation = const LatLng(5.3400, -4.0200); // Position actuelle du rider

    // Calculer l'heure d'arrivée estimée
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(minutes: widget.delivery.estimatedTime));
    _estimatedArrival = DateFormat('HH:mm').format(arrivalTime);

    _routeDistance = widget.delivery.distance;
    _estimatedTime = widget.delivery.estimatedTime;
  }

  Future<void> _calculateRoute() async {
    setState(() => _isLoadingRoute = true);

    try {
      // Définir les points de l'itinéraire en fonction du statut
      List<LatLng> waypoints = [];

      if (widget.delivery.status == 'new' || widget.delivery.status == 'accepted') {
        // Rider → Restaurant → Client
        waypoints = [_currentLocation, _pickupLocation, _deliveryLocation];
      } else if (widget.delivery.status == 'picked_up') {
        // Rider → Client (commande déjà récupérée)
        waypoints = [_currentLocation, _deliveryLocation];
      } else {
        // Livraison terminée - juste afficher la position finale
        waypoints = [_currentLocation];
      }

      if (waypoints.length > 1) {
        // Appeler l'API Valhalla
        final result = await RoutingService.getRoute(
          locations: waypoints,
          costing: 'motorcycle',
        );

        if (result != null && mounted) {
          setState(() {
            _routePoints = result.points;
            _routeDistance = result.distanceKm;
            _estimatedTime = result.durationMinutes;

            // Recalculer l'heure d'arrivée avec les données réelles
            final now = DateTime.now();
            final arrivalTime = now.add(Duration(minutes: result.durationMinutes));
            _estimatedArrival = DateFormat('HH:mm').format(arrivalTime);

            _isLoadingRoute = false;
          });
        }
      } else {
        setState(() => _isLoadingRoute = false);
      }
    } catch (e) {
      // En cas d'erreur, utiliser les données du modèle
      if (mounted) {
        setState(() {
          _routePoints = [_currentLocation, _pickupLocation, _deliveryLocation];
          _isLoadingRoute = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    AppSizes().initialize(context);

    // Déterminer la couleur et le texte du statut
    Color statusColor;
    String statusText;
    String actionButtonText;

    switch (widget.delivery.status) {
      case 'new':
        statusColor = const Color(0xFFFFA500);
        statusText = 'Nouvelle livraison';
        actionButtonText = 'Accepter la livraison';
        break;
      case 'accepted':
        statusColor = const Color(0xFF2196F3);
        statusText = 'En route vers le restaurant';
        actionButtonText = 'J\'ai récupéré la commande';
        break;
      case 'picked_up':
        statusColor = AppColors.primary;
        statusText = 'En route vers le client';
        actionButtonText = 'Livraison effectuée';
        break;
      case 'delivered':
        statusColor = const Color(0xFF4CD964);
        statusText = 'Livraison terminée';
        actionButtonText = 'Retour';
        break;
      default:
        statusColor = Colors.grey;
        statusText = widget.delivery.status;
        actionButtonText = 'Continuer';
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Carte en plein écran
          _buildMap(),

          // Indicateur de chargement de l'itinéraire
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
                // Header avec bouton retour
                _buildHeader(textColor),

                const Spacer(),

                // Bloc d'informations avec animation (réduit ou agrandi)
                GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity! < 0) {
                      // Glissement vers le haut - agrandir
                      if (!_isExpanded) _toggleExpanded();
                    } else if (details.primaryVelocity! > 0) {
                      // Glissement vers le bas - réduire
                      if (_isExpanded) _toggleExpanded();
                    }
                  },
                  child: AnimatedCrossFade(
                    firstChild: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNavigationInfo(surfaceColor, textColor, textLightColor),
                        _buildDeliveryDetails(surfaceColor, textColor, textLightColor, statusColor, statusText, actionButtonText),
                      ],
                    ),
                    secondChild: _buildCollapsedView(surfaceColor, textColor, textLightColor, statusColor, statusText),
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

        // Polyline pour l'itinéraire (tracé réel depuis Valhalla)
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

        // Marqueurs
        MarkerLayer(
          markers: [
            // Position actuelle du rider
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
                child: const Icon(
                  Icons.navigation,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            // Restaurant (pickup)
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
                child: const Icon(
                  Icons.restaurant,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            // Client (delivery)
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
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(Color textColor) {
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
              child: Icon(
                Icons.arrow_back,
                color: AppColors.text,
                size: 22,
              ),
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
              '#${widget.delivery.id}',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
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
        bottom: 10, // Espace pour le cercle (réduit)
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

          // Cercle avec icône pour toggle
          Positioned(
            bottom: -20,
            child: GestureDetector(
              onTap: _toggleExpanded,
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
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

  Widget _buildDeliveryDetails(
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    Color statusColor,
    String statusText,
    String actionButtonText,
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
                child: IconManager.getIcon(
                  'restaurant',
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.delivery.restaurantName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.delivery.pickupAddress,
                      style: TextStyle(
                        color: textLightColor,
                        fontSize: 13.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  AppToast.showInfo(
                    context: context,
                    message: 'Appel au restaurant',
                  );
                },
                icon: IconManager.getIcon(
                  'phone',
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ligne de séparation avec points
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
                child: IconManager.getIcon(
                  'person',
                  color: const Color(0xFF4CD964),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.delivery.customerName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.delivery.deliveryAddress,
                      style: TextStyle(
                        color: textLightColor,
                        fontSize: 13.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  AppToast.showInfo(
                    context: context,
                    message: 'Appel au client',
                  );
                },
                icon: IconManager.getIcon(
                  'phone',
                  color: const Color(0xFF4CD964),
                  size: 22,
                ),
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
                      style: TextStyle(
                        color: textLightColor,
                        fontSize: 12.sp,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.delivery.orderDetails,
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
                      style: TextStyle(
                        color: textLightColor,
                        fontSize: 12.sp,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.delivery.deliveryFee.toStringAsFixed(0)} F',
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

          // Bouton d'action
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                if (widget.delivery.status == 'delivered') {
                  Routes.goBack();
                } else {
                  AppToast.showSuccess(
                    context: context,
                    message: 'Statut mis à jour',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionButtonText,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedView(
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
                // Info 1: Distance
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CD964).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: IconManager.getIcon(
                                'location_on',
                                color: const Color(0xFF4CD964),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_routeDistance.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Distance',
                                style: TextStyle(
                                  color: textLightColor,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Ligne de connexion
                Container(
                  width: 1,
                  height: 32,
                  color: textLightColor.withValues(alpha: 0.2),
                ),

                // Info 2: Temps
                Expanded(
                  child: Column(
                    children: [
                      Row(
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
                              child: IconManager.getIcon(
                                'access_time',
                                color: const Color(0xFFFF6B6B),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_estimatedTime min',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Temps',
                                style: TextStyle(
                                  color: textLightColor,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Ligne de connexion
                Container(
                  width: 1,
                  height: 32,
                  color: textLightColor.withValues(alpha: 0.2),
                ),

                // Info 3: Arrivée
                Expanded(
                  child: Column(
                    children: [
                      Row(
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
                              child: IconManager.getIcon(
                                'clock',
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _estimatedArrival,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Arrivée',
                                style: TextStyle(
                                  color: textLightColor,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Timeline de progression
          _buildProgressLine(textLightColor.withValues(alpha: 0.2)),

          // Informations essentielles
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Restaurant et client
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.delivery.restaurantName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
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
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CD964),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.delivery.customerName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Frais de livraison
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.delivery.deliveryFee.toStringAsFixed(0)} F',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
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

  Widget _buildProgressLine(Color dividerColor) {
    // Calculer le pourcentage de progression en fonction du statut
    double progress = 0.0;

    if (widget.delivery.status == 'accepted') {
      progress = 0.3; // En route vers le restaurant
    } else if (widget.delivery.status == 'picked_up') {
      progress = 0.65; // Commande récupérée, en route vers le client
    } else if (widget.delivery.status == 'delivered') {
      progress = 1.0; // Livraison terminée
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              // COUCHE 1: Ligne de fond (grise)
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: dividerColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),

              // COUCHE 2: Ligne de progression (colorée)
              if (progress > 0)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: Stack(
                      children: [
                        // Ligne de base
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                        // Effet de lumière qui traverse
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

              // COUCHE 3: Icône de moto au bout de la ligne
              if (progress > 0 && progress < 1.0)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconManager.getIcon(
                        'motorcycle',
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),

              // Icône de check si livraison terminée
              if (progress >= 1.0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CD964),
                      shape: BoxShape.circle,
                    ),
                    child: IconManager.getIcon(
                      'check',
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
