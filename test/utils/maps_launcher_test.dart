// test/utils/maps_launcher_test.dart
//
// Tests unitaires pour la construction d'URL Google Maps et la résolution
// backend > fallback local. Le launchUrl natif n'est pas testé ici (dépend
// d'un plugin natif), juste la logique de décision et le format d'URL.

import 'package:flutter_test/flutter_test.dart';
import 'package:rider/core/utils/maps_launcher.dart';

void main() {
  group('buildLocalNavUrl', () {
    test('construit URL avec coords valides', () {
      final url = buildLocalNavUrl(14.7167, -17.4677);
      expect(
        url,
        'https://www.google.com/maps/dir/?api=1&destination=14.7167,-17.4677&travelmode=driving',
      );
    });

    test('retourne null si lat null', () {
      expect(buildLocalNavUrl(null, -17.4677), isNull);
    });

    test('retourne null si lng null', () {
      expect(buildLocalNavUrl(14.7167, null), isNull);
    });

    test('retourne null si lat NaN', () {
      expect(buildLocalNavUrl(double.nan, -17.4677), isNull);
    });

    test('retourne null si lng infini', () {
      expect(buildLocalNavUrl(14.7167, double.infinity), isNull);
    });

    test('accepte 0,0 (équateur / Greenwich)', () {
      final url = buildLocalNavUrl(0, 0);
      expect(url, contains('destination=0.0,0.0'));
    });

    test('accepte coords négatives (Sud/Ouest)', () {
      final url = buildLocalNavUrl(-33.8688, 151.2093);
      expect(url, contains('destination=-33.8688,151.2093'));
    });

    test('contient toujours travelmode=driving', () {
      final url = buildLocalNavUrl(14.7167, -17.4677);
      expect(url, contains('travelmode=driving'));
    });
  });

  group('resolveNavUrl', () {
    const backendUrl =
        'https://www.google.com/maps/dir/?api=1&destination=14.7167,-17.4677&travelmode=driving';

    test('préfère backendUrl quand non vide', () {
      final url = resolveNavUrl(
        backendUrl: backendUrl,
        lat: 0, // Coords différentes — doivent être ignorées.
        lng: 0,
      );
      expect(url, backendUrl);
    });

    test('fallback local si backendUrl null', () {
      final url = resolveNavUrl(
        backendUrl: null,
        lat: 14.7167,
        lng: -17.4677,
      );
      expect(url, contains('destination=14.7167,-17.4677'));
    });

    test('fallback local si backendUrl est string vide', () {
      final url = resolveNavUrl(
        backendUrl: '',
        lat: 14.7167,
        lng: -17.4677,
      );
      expect(url, isNotNull);
      expect(url, contains('destination=14.7167,-17.4677'));
    });

    test('retourne null si backendUrl null et coords null', () {
      final url = resolveNavUrl(
        backendUrl: null,
        lat: null,
        lng: null,
      );
      expect(url, isNull);
    });

    test('retourne null si backendUrl vide et coords NaN', () {
      final url = resolveNavUrl(
        backendUrl: '',
        lat: double.nan,
        lng: -17.4677,
      );
      expect(url, isNull);
    });
  });
}
