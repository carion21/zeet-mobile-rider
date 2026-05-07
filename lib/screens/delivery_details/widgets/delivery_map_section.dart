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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:rider/core/config/app_config.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/services/routing_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

// Debounce avant chaque appel a Valhalla — evite de spammer le serveur de
// routing en zone urbaine ou les positions GPS arrivent toutes les ~50m.
const Duration _kRouteDebounce = Duration(seconds: 5);

/// TileProvider qui utilise [CachedNetworkImageProvider] pour persister les
/// tiles OSM sur disque (cache geré par flutter_cache_manager). Reduit le
/// blanc map de 5-10s sur Edge/3G a ~0s pour les zones deja visitees.
///
/// Note : flutter_map injecte automatiquement le User-Agent dans `headers`
/// a partir de `userAgentPackageName` du [TileLayer], on le forwarde tel quel.
class _CachedTileProvider extends TileProvider {
  _CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: headers,
    );
  }
}

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

  // Fallback Abidjan (centre Plateau) — utilisé SEULEMENT si Geolocator est
  // indisponible (permissions refusées, indoor, etc.). Source : AppConfig.
  LatLng _pickupLocation = const LatLng(5.3364, -4.0267);
  LatLng _deliveryLocation = AppConfig.demoDropoff;
  LatLng _currentLocation = AppConfig.abidjanFallback;
  bool _hasRealPosition = false;

  List<LatLng> _routePoints = [];

  StreamSubscription<Position>? _positionSubscription;
  // Coalesce les recalculs de route : si une nouvelle position arrive avant
  // que le timer ne se declenche, on annule et on reprogramme. Cf. plan §3.9.
  Timer? _routeDebounceTimer;

  @override
  void initState() {
    super.initState();
    _applyMission(widget.mission);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLoadingChanged?.call(true);
      _initLocationTracking();
      // Premier calcul immediat (mount) — pas de debounce a l'ouverture
      // sinon l'utilisateur attend 5s avant de voir une polyline.
      _calculateRoute();
    });
  }

  @override
  void dispose() {
    _routeDebounceTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// Programme un recalcul de route en debounce. Si un timer est deja en
  /// cours, on l'annule pour reprogrammer — evite N requetes Valhalla quand
  /// le rider se deplace en continu (50m toutes les ~30s en centre-ville).
  void _scheduleRouteRecalc() {
    _routeDebounceTimer?.cancel();
    _routeDebounceTimer = Timer(_kRouteDebounce, () {
      if (!mounted) return;
      _calculateRoute();
    });
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
      // Premiere position : recalcul immediat (l'utilisateur attend la map).
      _applyPosition(
        initial.latitude,
        initial.longitude,
        recalc: true,
        debounce: false,
      );

      // Stream pour les updates suivantes — debounce 5s pour coalesce les
      // mouvements continus (cf. _scheduleRouteRecalc).
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50, // tracking GPS reste a 50m pres
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

  void _applyPosition(
    double lat,
    double lng, {
    bool recalc = false,
    bool debounce = true,
  }) {
    final next = LatLng(lat, lng);
    final didChange =
        !_hasRealPosition || _distanceMeters(_currentLocation, next) >= 50;
    setState(() {
      _currentLocation = next;
      _hasRealPosition = true;
    });
    if (didChange && recalc) {
      // Premiere position (debounce=false) → calcul immediat.
      // Updates suivantes du stream → debounce 5s pour ne pas spammer Valhalla.
      if (debounce) {
        _scheduleRouteRecalc();
      } else {
        _calculateRoute();
      }
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
          // Cache disque ~30j (defaut flutter_cache_manager) — tiles deja
          // chargees s'affichent en <100ms meme en zone Edge/3G.
          tileProvider: _CachedTileProvider(),
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
