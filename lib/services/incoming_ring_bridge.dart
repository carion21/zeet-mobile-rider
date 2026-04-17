// IncomingRingBridge — wrapper Dart pour le MethodChannel "zeet/incoming_ring"
// qui controle le service natif [IncomingRingService] cote Android.
//
// Phase 4 : la sonnerie forte en boucle est gere par un ForegroundService natif
// (MediaPlayer en loop) declenche directement par [ZeetFirebaseMessagingService]
// quand un push FCM `delivery.offer` arrive en background/killed.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class IncomingRingBridge {
  static const MethodChannel _channel = MethodChannel('zeet/incoming_ring');

  /// Arrete la sonnerie native et ferme la notification FSI.
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (e) {
      debugPrint('[IncomingRingBridge] stop failed: $e');
    } catch (e) {
      debugPrint('[IncomingRingBridge] stop unavailable: $e');
    }
  }

  /// Demarre la sonnerie native (dev trigger — n'utilise pas de payload FCM).
  static Future<void> startFake({
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('start', {
        'title': title,
        'body': body,
      });
    } on PlatformException catch (e) {
      debugPrint('[IncomingRingBridge] start failed: $e');
    } catch (e) {
      debugPrint('[IncomingRingBridge] start unavailable: $e');
    }
  }
}
