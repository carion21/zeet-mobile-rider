// lib/services/routing_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  // URL de l'API Valhalla publique
  static const String _valhallaUrl = 'https://valhalla1.openstreetmap.de/route';

  /// Calcule l'itinéraire entre plusieurs points en utilisant Valhalla
  ///
  /// [locations] - Liste de coordonnées (latitude, longitude)
  /// [costing] - Type de véhicule: 'auto', 'bicycle', 'pedestrian', 'motorcycle'
  ///
  /// Retourne une liste de points LatLng représentant l'itinéraire
  static Future<RouteResult?> getRoute({
    required List<LatLng> locations,
    String costing = 'motorcycle', // Par défaut pour les livreurs
  }) async {
    try {
      // Construire le body de la requête
      final body = {
        'locations': locations.map((loc) => {
          'lat': loc.latitude,
          'lon': loc.longitude,
        }).toList(),
        'costing': costing,
        'directions_options': {
          'units': 'kilometers',
          'language': 'fr-FR',
        },
      };

      // Appel à l'API Valhalla
      final response = await http.post(
        Uri.parse(_valhallaUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extraire les informations de l'itinéraire
        final trip = data['trip'];
        final legs = trip['legs'] as List;

        // Calculer la distance et le temps total
        double totalDistance = 0.0;
        int totalTime = 0;

        for (var leg in legs) {
          totalDistance += (leg['summary']['length'] as num).toDouble();
          totalTime += (leg['summary']['time'] as num).toInt();
        }

        // Décoder la polyline (format encoded)
        final shape = trip['legs'][0]['shape'] as String;
        final routePoints = _decodePolyline(shape);

        return RouteResult(
          points: routePoints,
          distanceKm: totalDistance,
          durationSeconds: totalTime,
        );
      } else {
        print('❌ Erreur Valhalla: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Erreur lors du calcul de l\'itinéraire: $e');
      return null;
    }
  }

  /// Décode une polyline encodée (format Google/Valhalla)
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E6, lng / 1E6));
    }

    return points;
  }
}

/// Résultat d'un calcul d'itinéraire
class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationSeconds;

  RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationSeconds,
  });

  int get durationMinutes => (durationSeconds / 60).round();
}
