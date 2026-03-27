/// Configuration des URLs de l'API pour différents environnements.
/// Base URL du Core API ZEET (sans le préfixe de version).
class ApiConfig {
  static const String devBaseUrl = 'http://localhost:8000/v1';
  static const String testBaseUrl = 'http://46.202.170.228:8000/v1';
  static const String prodBaseUrl = 'https://zeet-core-system-production.up.railway.app/v1';

  static String get baseUrl {
    const environment = "prod";
    switch (environment) {
      case 'prod':
        return prodBaseUrl;
      case 'test':
        return testBaseUrl;
      default:
        return devBaseUrl;
    }
  }
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------
abstract class AuthEndpoints {
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
}

// ---------------------------------------------------------------------------
// Status & Location
// ---------------------------------------------------------------------------
abstract class StatusEndpoints {
  static const String get = '/rider/status';
  static const String setOnline = '/rider/status';
  static const String updateLocation = '/rider/location';
}

// ---------------------------------------------------------------------------
// Deliveries (references / transitions)
// ---------------------------------------------------------------------------
abstract class DeliveryEndpoints {
  static const String transitions = '/rider/deliveries/transitions';
  static const String actions = '/rider/orders/actions';
}

// ---------------------------------------------------------------------------
// Missions
// ---------------------------------------------------------------------------
abstract class MissionEndpoints {
  static const String list = '/rider/missions';
  static String get(String id) => '/rider/missions/$id';
  static String accept(String id) => '/rider/missions/$id/accept';
  static String reject(String id) => '/rider/missions/$id/reject';
  static String collect(String id) => '/rider/missions/$id/collect';
  static String deliver(String id) => '/rider/missions/$id/deliver';
  static String notDelivered(String id) => '/rider/missions/$id/not-delivered';
}

// ---------------------------------------------------------------------------
// Earnings
// ---------------------------------------------------------------------------
abstract class EarningsEndpoints {
  static const String summary = '/rider/earnings';
  static const String history = '/rider/earnings/history';
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------
class ApiHelper {
  static String buildUrl(String endpoint) {
    return '${ApiConfig.baseUrl}$endpoint';
  }

  static String buildUrlWithId(String endpoint, String id) {
    return '${ApiConfig.baseUrl}$endpoint/$id';
  }
}
