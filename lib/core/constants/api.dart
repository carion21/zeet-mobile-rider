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

  /// GET /v1/rider/availability-log — historique des bascules online/offline.
  /// Paginé (page, limit), filtrable (date_from, date_to).
  static const String availabilityLog = '/rider/availability-log';
}

// ---------------------------------------------------------------------------
// Deliveries (historique + references / transitions)
// ---------------------------------------------------------------------------
abstract class DeliveryEndpoints {
  /// GET /v1/rider/deliveries — historique complet paginé des livraisons
  /// (distinct des missions actives).
  static const String list = '/rider/deliveries';

  /// GET /v1/rider/deliveries/actions?status=... — actions canoniques cote
  /// livraisons (delivery state). Source de verite pour generer les boutons UI.
  static const String deliveriesActions = '/rider/deliveries/actions';

  /// GET /v1/rider/deliveries/transitions?status=... — transitions delivery
  /// possibles depuis un statut donne (debug + filtrage UI).
  static const String deliveriesTransitions = '/rider/deliveries/transitions';
}

// ---------------------------------------------------------------------------
// Order actions (côté commande, plus large que delivery)
// ---------------------------------------------------------------------------
abstract class OrderActionEndpoints {
  /// GET /v1/rider/orders/actions?status=... — actions canoniques cote
  /// commande (order state). Source de verite pour generer les boutons UI.
  static const String ordersActions = '/rider/orders/actions';
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

  /// GET /v1/rider/missions/:id/logs — audit trail d'une mission.
  static String logs(String id) => '/rider/missions/$id/logs';
}

// ---------------------------------------------------------------------------
// Earnings
// ---------------------------------------------------------------------------
abstract class EarningsEndpoints {
  static const String summary = '/rider/earnings';
  static const String history = '/rider/earnings/history';
}

// ---------------------------------------------------------------------------
// Profile (edit + avatar upload)
// ---------------------------------------------------------------------------
abstract class ProfileEndpoints {
  /// PATCH /v1/rider/profile — update partial profile (firstname, lastname,
  /// email, gender). Tous les champs sont optionnels cote backend.
  static const String update = '/rider/profile';

  /// POST /v1/rider/profile/photo — upload avatar (multipart/form-data, field `file`).
  /// Max 5 MB, mime image/jpeg|png|webp.
  static const String photo = '/rider/profile/photo';
}

// ---------------------------------------------------------------------------
// Ratings (notes recues par le rider)
// ---------------------------------------------------------------------------
abstract class RatingEndpoints {
  /// GET /v1/rider/ratings — liste paginee des notes recues avec summary
  /// (average_rating, total_ratings).
  static const String list = '/rider/ratings';
}

// ---------------------------------------------------------------------------
// Stats (dashboard du rider : livraisons, taux, rating, gains)
// ---------------------------------------------------------------------------
abstract class StatsEndpoints {
  /// GET /v1/rider/stats — statistiques agregees du rider sur une periode.
  static const String summary = '/rider/stats';
}

// ---------------------------------------------------------------------------
// Support (tickets contextualises depuis une mission)
// ---------------------------------------------------------------------------
abstract class SupportEndpoints {
  /// POST /v1/rider/tickets — cree un ticket support contextualise.
  /// Body : `{ mission_id, mission_ref, reason, note?, address_context? }`.
  /// A confirmer cote backend (api-reference.json a `/v1/client/tickets`,
  /// l'equivalent rider est suppose suivre la meme convention).
  static const String createTicket = '/rider/tickets';
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------
abstract class NotificationEndpoints {
  static const String list = '/rider/notifications';
  static const String unreadCount = '/rider/notifications/unread-count';
  static const String readAll = '/rider/notifications/read-all';
  static const String preferences = '/rider/notifications/preferences';
  static const String deviceToken = '/rider/notifications/device-token';
  static String markAsRead(String id) => '/rider/notifications/$id/read';
  static String acknowledge(String id) => '/rider/notifications/$id/ack';
  /// PATCH /v1/rider/notifications/preferences/:typeId
  /// Le paramètre correspond a l'ID du notification_type (cote backend :typeId).
  static String updatePreference(String typeId) =>
      '/rider/notifications/preferences/$typeId';
  static String removeDeviceToken(String id) =>
      '/rider/notifications/device-token/$id';
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
