// lib/services/location_tracking_service.dart
//
// Tracking GPS continu pendant qu'une mission est en cours, ET cadence
// idle quand le rider est en ligne sans mission active.
//
// Cadences (skill ORDERS_RIDER_FLOW.md §3.3) :
//  - Mission active (accepted / collected / on-the-way) : 5-10 s
//  - Idle online (statut online sans mission)            : 30-60 s
//
// Stack :
//  - Android : flutter_foreground_task avec foregroundServiceType="location"
//    (Android 14+). Continue de tourner app killed.
//  - iOS : geolocator + significant-change via Position stream avec
//    distanceFilter. UIBackgroundModes "location" autorise le delivery en
//    background tant que l'app est en running (ou via significant change).
//
// L'API expose 3 modes :
//   start(missionId)   -> mission active, cadence 5s
//   startIdle()        -> en ligne sans mission, cadence 60s
//   stop()             -> arrete tout
//
// Le service appelle StatusService.updateLocation a chaque tick.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'package:rider/services/status_service.dart';

/// Mode courant du tracking. Sert a savoir si on doit reconfigurer le
/// service (bascule entre mission active et idle online).
enum LocationTrackingMode {
  stopped,
  idleOnline,
  missionActive,
}

class LocationTrackingService {
  LocationTrackingService._();

  static final LocationTrackingService instance = LocationTrackingService._();

  // Cadences (en secondes) — voir ORDERS_RIDER_FLOW.md §3.3.
  static const int _kMissionActiveIntervalSec = 7; // 5-10s
  static const int _kIdleOnlineIntervalSec = 45;   // 30-60s

  LocationTrackingMode _mode = LocationTrackingMode.stopped;
  String? _missionId;

  StreamSubscription<Position>? _iosSubscription;
  Timer? _iosFallbackTimer;
  final StatusService _statusService = StatusService();

  LocationTrackingMode get mode => _mode;
  bool get isRunning => _mode != LocationTrackingMode.stopped;
  String? get currentMissionId => _missionId;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Demarre le tracking en mode mission active (cadence ~7s).
  Future<void> startTracking({required String missionId}) async {
    if (_mode == LocationTrackingMode.missionActive && _missionId == missionId) {
      return; // idempotent
    }
    await stopTracking();
    _missionId = missionId;
    _mode = LocationTrackingMode.missionActive;
    debugPrint(
      '[LocationTracking] start MISSION mission=$missionId cadence=${_kMissionActiveIntervalSec}s',
    );
    await _startPlatformService(_kMissionActiveIntervalSec);
  }

  /// Demarre le tracking en mode idle online (cadence ~45s).
  /// A utiliser quand le rider est online mais sans mission active.
  Future<void> startIdleTracking() async {
    if (_mode == LocationTrackingMode.idleOnline) return; // idempotent
    await stopTracking();
    _mode = LocationTrackingMode.idleOnline;
    _missionId = null;
    debugPrint(
      '[LocationTracking] start IDLE cadence=${_kIdleOnlineIntervalSec}s',
    );
    await _startPlatformService(_kIdleOnlineIntervalSec);
  }

  /// Arrete tout tracking. Idempotent.
  Future<void> stopTracking() async {
    if (_mode == LocationTrackingMode.stopped) return;
    debugPrint('[LocationTracking] stop mode=$_mode mission=$_missionId');
    _mode = LocationTrackingMode.stopped;
    _missionId = null;
    await _stopPlatformService();
  }

  // ---------------------------------------------------------------------------
  // Platform binding
  // ---------------------------------------------------------------------------

  Future<void> _startPlatformService(int intervalSec) async {
    if (Platform.isAndroid) {
      await _startAndroidForegroundService(intervalSec);
    } else {
      await _startIosBackgroundStream(intervalSec);
    }
  }

  Future<void> _stopPlatformService() async {
    if (Platform.isAndroid) {
      try {
        if (await FlutterForegroundTask.isRunningService) {
          await FlutterForegroundTask.stopService();
        }
      } catch (e) {
        debugPrint('[LocationTracking] stopService error: $e');
      }
    } else {
      await _iosSubscription?.cancel();
      _iosSubscription = null;
      _iosFallbackTimer?.cancel();
      _iosFallbackTimer = null;
    }
  }

  // --- Android : flutter_foreground_task ---

  Future<void> _startAndroidForegroundService(int intervalSec) async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'zeet_rider_location',
          channelName: 'Suivi de mission',
          channelDescription:
              'Partage votre position pendant les livraisons en cours.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(intervalSec * 1000),
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );

      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          notificationTitle: _mode == LocationTrackingMode.missionActive
              ? 'Livraison en cours'
              : 'En ligne',
          notificationText: _mode == LocationTrackingMode.missionActive
              ? 'On suit ta course en temps reel.'
              : 'On t\'envoie des missions des qu\'elles arrivent.',
          callback: locationTaskCallback,
        );
      }
    } catch (e) {
      debugPrint(
        '[LocationTracking] Android FG service start failed: $e — fallback timer',
      );
      // Fallback timer in-process si le service natif refuse (ex: device
      // sans Google Services). Ne survit pas a l'app killed mais evite
      // un blocage total.
      _iosFallbackTimer?.cancel();
      _iosFallbackTimer = Timer.periodic(
        Duration(seconds: intervalSec),
        (_) => _pingLocation(),
      );
    }
  }

  // --- iOS : geolocator stream + fallback timer ---

  Future<void> _startIosBackgroundStream(int intervalSec) async {
    try {
      // Utilise un distanceFilter pour eviter de polluer en stationnaire.
      // En mission active : 25m ; en idle : 100m (significant-change like).
      final distanceFilter =
          _mode == LocationTrackingMode.missionActive ? 25 : 100;
      _iosSubscription = Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: distanceFilter,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
          pauseLocationUpdatesAutomatically: false,
        ),
      ).listen(
        (Position pos) {
          unawaited(_postLocation(pos.latitude, pos.longitude));
        },
        onError: (Object e) {
          debugPrint('[LocationTracking] iOS stream error: $e');
        },
      );

      // Timer de garde (au cas ou la stream ne deborderait pas
      // assez vite — surtout en idle 45s avec distanceFilter 100m).
      _iosFallbackTimer?.cancel();
      _iosFallbackTimer = Timer.periodic(
        Duration(seconds: intervalSec),
        (_) => _pingLocation(),
      );
    } catch (e) {
      debugPrint('[LocationTracking] iOS stream start failed: $e');
    }
  }

  Future<void> _pingLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 8));
      await _postLocation(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('[LocationTracking] _pingLocation error: $e');
    }
  }

  Future<void> _postLocation(double lat, double lng) async {
    try {
      await _statusService.updateLocation(
        lat: lat.toStringAsFixed(6),
        lng: lng.toStringAsFixed(6),
      );
    } catch (e) {
      // Best-effort : la position est throttle backend ; pas grave si on rate.
      debugPrint('[LocationTracking] post location failed: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Android Foreground Task callback (top-level, isolate separe)
// ---------------------------------------------------------------------------
//
// IMPORTANT : ce callback s'execute dans un ISOLATE distinct de l'app.
// Il ne peut pas acceder a Riverpod, aux providers, ni au state de l'UI.
// Il appelle directement StatusService (qui s'auto-init via TokenService).

@pragma('vm:entry-point')
void locationTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_LocationTaskHandler());
}

class _LocationTaskHandler extends TaskHandler {
  StatusService? _service;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _service = StatusService();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 8));
      await _service?.updateLocation(
        lat: pos.latitude.toStringAsFixed(6),
        lng: pos.longitude.toStringAsFixed(6),
      );
    } catch (e) {
      debugPrint('[LocationTask isolate] tick error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _service = null;
  }
}
