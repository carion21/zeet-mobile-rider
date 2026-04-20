// lib/services/permissions_service.dart
//
// Service centralise pour les permissions de l'app rider.
// Wrappe `permission_handler` pour :
//  - Notifications          (critique : nouvelles missions)
//  - Location when-in-use   (critique : acceptation mission, navigation)
//  - Location always        (critique : tracking GPS continu en livraison)
//  - Battery optimization   (critique : evite que le FGS tracking soit tue)
//  - Exact alarms           (utile : timers mission a la seconde)
//
// Le flag `permissions_onboarded` est persiste dans SharedPreferences.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ZeetPermission {
  notifications,
  location,
  locationAlways,
  batteryOptimization,
  exactAlarm,
}

enum ZeetPermissionStatus {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  notApplicable,
}

class PermissionsService {
  PermissionsService._();

  static final PermissionsService instance = PermissionsService._();

  static const String _prefKey = 'zeet_rider_permissions_onboarded_v1';

  List<ZeetPermission> get applicablePermissions {
    if (kIsWeb) return const <ZeetPermission>[];
    if (Platform.isAndroid) {
      return const <ZeetPermission>[
        ZeetPermission.notifications,
        ZeetPermission.location,
        ZeetPermission.locationAlways,
        ZeetPermission.batteryOptimization,
        ZeetPermission.exactAlarm,
      ];
    }
    if (Platform.isIOS) {
      return const <ZeetPermission>[
        ZeetPermission.notifications,
        ZeetPermission.location,
        ZeetPermission.locationAlways,
      ];
    }
    return const <ZeetPermission>[];
  }

  Set<ZeetPermission> get criticalPermissions => const <ZeetPermission>{
        ZeetPermission.notifications,
        ZeetPermission.location,
        ZeetPermission.locationAlways,
        ZeetPermission.batteryOptimization,
      };

  Future<ZeetPermissionStatus> getStatus(ZeetPermission p) async {
    if (!applicablePermissions.contains(p)) {
      return ZeetPermissionStatus.notApplicable;
    }
    switch (p) {
      case ZeetPermission.notifications:
        return _map(await Permission.notification.status);
      case ZeetPermission.location:
        return _map(await Permission.locationWhenInUse.status);
      case ZeetPermission.locationAlways:
        return _map(await Permission.locationAlways.status);
      case ZeetPermission.batteryOptimization:
        return _map(await Permission.ignoreBatteryOptimizations.status);
      case ZeetPermission.exactAlarm:
        try {
          return _map(await Permission.scheduleExactAlarm.status);
        } catch (_) {
          return ZeetPermissionStatus.notApplicable;
        }
    }
  }

  Future<ZeetPermissionStatus> request(ZeetPermission p) async {
    if (!applicablePermissions.contains(p)) {
      return ZeetPermissionStatus.notApplicable;
    }
    switch (p) {
      case ZeetPermission.notifications:
        return _map(await Permission.notification.request());
      case ZeetPermission.location:
        return _map(await Permission.locationWhenInUse.request());
      case ZeetPermission.locationAlways:
        // iOS+Android : Permission.locationAlways.request() ouvre la system
        // prompt "Always allow". Sur Android 10+, il faut d'abord avoir
        // whenInUse, donc on l'accorde en prerequis.
        final whenInUse = await Permission.locationWhenInUse.status;
        if (!whenInUse.isGranted) {
          await Permission.locationWhenInUse.request();
        }
        return _map(await Permission.locationAlways.request());
      case ZeetPermission.batteryOptimization:
        return _map(await Permission.ignoreBatteryOptimizations.request());
      case ZeetPermission.exactAlarm:
        try {
          return _map(await Permission.scheduleExactAlarm.request());
        } catch (_) {
          return ZeetPermissionStatus.notApplicable;
        }
    }
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> markOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  String labelFor(ZeetPermission p) {
    switch (p) {
      case ZeetPermission.notifications:
        return 'Notifications';
      case ZeetPermission.location:
        return 'Localisation';
      case ZeetPermission.locationAlways:
        return 'Localisation en continu';
      case ZeetPermission.batteryOptimization:
        return 'Batterie';
      case ZeetPermission.exactAlarm:
        return 'Alarmes precises';
    }
  }

  String descriptionFor(ZeetPermission p) {
    switch (p) {
      case ZeetPermission.notifications:
        return 'Recevez les missions en temps reel, meme ecran eteint.';
      case ZeetPermission.location:
        return 'Necessaire pour accepter une mission et vous guider.';
      case ZeetPermission.locationAlways:
        return 'Suivi GPS continu pendant vos livraisons. Indispensable pour etre paye.';
      case ZeetPermission.batteryOptimization:
        return 'Empeche Android de couper ZEET quand vous roulez.';
      case ZeetPermission.exactAlarm:
        return 'Declenche les alertes de mission a la seconde pres.';
    }
  }

  ZeetPermissionStatus _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) {
      return ZeetPermissionStatus.granted;
    }
    if (s.isPermanentlyDenied || s.isRestricted) {
      return ZeetPermissionStatus.permanentlyDenied;
    }
    return ZeetPermissionStatus.denied;
  }
}
