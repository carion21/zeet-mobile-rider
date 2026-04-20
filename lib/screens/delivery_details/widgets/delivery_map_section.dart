// lib/screens/delivery_details/widgets/delivery_map_section.dart
//
// Section carte plein-ecran : OSM tiles + markers pickup/current/delivery +
// polyline route Valhalla. Calcule l'itineraire au mount et apres chaque
// changement de mission.
//
// Position GPS REELLE injectee via Geolocator (skill `zeet-pos-ergonomics`
// — un rider doit faire confiance a sa position sur la map). Fallback
// Abidjan uniquement si la position ne peut pas etre obtenue.
//
// Notifie l'exterieur via [onRouteResolved] (distance/time/arrival) et
// [onLoadingChanged] pour l'overlay "calcul de l'itineraire".

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/services/routing_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class DeliveryRouteInfo {
  final double distanceKm;
  final int durationMinutes;
  final String estimatedArrival;

  const DeliveryRouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    required this.estimatedArrival,
  });
}

class DeliveryMapSection extends StatefulWidget {
  final Mission? mission;
  final ValueChanged<DeliveryRouteInfo>? onRouteResolved;
  final ValueChanged<bool>? onLoadingChanged;

  const DeliveryMapSection({
    super.key,
    required this.mission,
    this.onRouteResolved,
    this.onLoadingChanged,
  });

  @override
  State<DeliveryMapSection> createState() => _DeliveryMapSectionState();
}

class _DeliveryMapSectionState extends State<DeliveryMapSection> {
  final MapController _mapController = MapController();

  // Coordonnees par defaut (Abidjan) — SEULEMENT en fallback si Geolocator
  // est indisponible (permissions refusees, indoor, etc.).
  static const LatLng _kAbidjanFallback = LatLng(5.3400, -4.0200);

  LatLng _pickupLocation = const LatLng(5.3364, -4.0267);
  LatLng _deliveryLocation = const LatLng(5.3478, -4.0123);
  LatLng _currentLocation = _kAbidjanFallback;
  bool _hasRealPosition = false;

  List<LatLng> _routePoints = [];

  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _applyMission(widget.mission);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLoadingChanged?.call(true);
      _initLocationTracking();
      _calculateRoute();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// Initialise la position reelle. Tente d'abord un getCurrentPosition
  /// rapide, puis ouvre un stream pour suivre les deplacements (recalcul
  /// route si > 50m). Best-effort : si Geolocator echoue, on garde le
  /// fallback Abidjan + on n'affiche pas d'erreur (la map reste utilisable).
  Future<void> _initLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // pas de position : on garde le fallback
      }
      // Premiere position rapide (last known si dispo, sinon current).
      final initial = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          ).timeout(
            const Duration(seconds: 6),
            onTimeout: () => throw TimeoutException('getCurrentPosition'),
          );
      if (!mounted) return;
      _applyPosition(initial.latitude, initial.longitude, recalc: true);

      // Stream pour les updates suivantes.
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50, // recalcul si > 50m de deplacement
        ),
      ).listen(
        (Position pos) {
          if (!mounted) return;
          _applyPosition(pos.latitude, pos.longitude, recalc: true);
        },
        onError: (Object e) {
          debugPrint('[DeliveryMap] position stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[DeliveryMap] location init failed: $e (fallback Abidjan)');
    }
  }

  void _applyPosition(double lat, double lng, {bool recalc = false}) {
    final next = LatLng(lat, lng);
    final didChange =
        !_hasRealPosition || _distanceMeters(_currentLocation, next) >= 50;
    setState(() {
      _currentLocation = next;
      _hasRealPosition = true;
    });
    if (didChange && recalc) {
      _calculateRoute();
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  @override
  void didUpdateWidget(covariant DeliveryMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mission != oldWidget.mission && widget.mission != null) {
      final changed = _applyMission(widget.mission);
      if (changed) {
        widget.onLoadingChanged?.call(true);
        _calculateRoute();
      }
    }
  }

  /// Applique pickup/dropoff de la mission. Retourne true si ca a change.
  bool _applyMission(Mission? mission) {
    if (mission == null) return false;

    final pickupLat = mission.pickupAddress?.lat ??
        mission.order?.partner?.address?.lat;
    final pickupLng = mission.pickupAddress?.lng ??
        mission.order?.partner?.address?.lng;
    final dropoffLat = mission.dropoffAddress?.lat ??
        mission.order?.customer?.address?.lat;
    final dropoffLng = mission.dropoffAddress?.lng ??
        mission.order?.customer?.address?.lng;

    bool changed = false;
    if (pickupLat != null && pickupLng != null) {
      final next = LatLng(pickupLat, pickupLng);
      if (next != _pickupLocation) {
        _pickupLocation = next;
        changed = true;
      }
    }
    if (dropoffLat != null && dropoffLng != null) {
      final next = LatLng(dropoffLat, dropoffLng);
      if (next != _deliveryLocation) {
        _deliveryLocation = next;
        changed = true;
      }
    }
    return changed;
  }

  Future<void> _calculateRoute() async {
    try {
      final waypoints = [_currentLocation, _pickupLocation, _deliveryLocation];
      final result = await RoutingService.getRoute(
        locations: waypoints,
        costing: 'motorcycle',
      );

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _routePoints = result.points;
        });
        widget.onRouteResolved?.call(
          DeliveryRouteInfo(
            distanceKm: result.distanceKm,
            durationMinutes: result.durationMinutes,
            estimatedArrival: DateFormat('HH:mm').format(
              DateTime.now().add(Duration(minutes: result.durationMinutes)),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routePoints = [_currentLocation, _pickupLocation, _deliveryLocation];
      });
    } finally {
      if (mounted) {
        widget.onLoadingChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: ZeetColors.info,
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
                  color: ZeetColors.success,
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
}
