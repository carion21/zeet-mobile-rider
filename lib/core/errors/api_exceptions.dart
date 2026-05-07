// lib/core/errors/api_exceptions.dart
//
// Hiérarchie d'exceptions API typées par classe d'erreur HTTP.
//
// La classe de base [ApiException] reste compatible avec le code existant
// (statusCode + message + code + errors). Les sous-classes permettent
// au caller de pattern-matcher sur la nature de l'erreur sans relire le
// statusCode :
//
//   try {
//     await api.post(...);
//   } on AuthException {           // 401 — token invalide
//     // re-login
//   } on ForbiddenException {       // 403 — pas le droit
//     AppToast.showError(...);
//   } on ConflictException {        // 409 — état changé (mission déjà prise)
//     ref.refresh(missionsListProvider);
//   } on ValidationException catch (e) {
//     // 422 — afficher e.errors champ par champ
//   } on ServerException {          // 5xx — retry silencieux ou banner
//     // déjà retryé 3x par ApiClient, prévenir l'utilisateur
//   } on NetworkException {         // pas de réseau / timeout
//     // enqueue offline si action critique, sinon banner offline
//   }
//
// Skill `zeet-flutter-bloc-recipe` §error-handling.
// Plan §7B critère 4 — gestion erreur typée.

/// Base — conservée pour compat. Tous les sous-types héritent.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  /// Code métier renvoyé par le backend (ex: `ERR_USER_NOT_FOUND`).
  /// Utiliser ce champ plutôt que `message` pour brancher de la logique.
  final String? code;
  final Map<String, dynamic>? errors;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.errors,
  });

  @override
  String toString() => '$runtimeType($statusCode${code != null ? ' · $code' : ''}): $message';

  // ─── Helpers compat ─────────────────────────────────────────
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidation => statusCode == 422;
  bool get isServerError => statusCode >= 500 && statusCode < 600;
  bool get isNetwork => statusCode == 0;

  /// Construit l'instance la plus précise selon le `statusCode`.
  /// Centralise le mapping pour qu'un seul endroit décide quelle sous-classe
  /// instancier — utilisé par `ApiClient._parseResponse`.
  factory ApiException.fromStatus({
    required int statusCode,
    required String message,
    String? code,
    Map<String, dynamic>? errors,
  }) {
    if (statusCode == 0) {
      return NetworkException(message: message, code: code, errors: errors);
    }
    if (statusCode == 401) {
      return AuthException(message: message, code: code, errors: errors);
    }
    if (statusCode == 403) {
      return ForbiddenException(message: message, code: code, errors: errors);
    }
    if (statusCode == 404) {
      return NotFoundException(message: message, code: code, errors: errors);
    }
    if (statusCode == 409) {
      return ConflictException(message: message, code: code, errors: errors);
    }
    if (statusCode == 422) {
      return ValidationException(message: message, code: code, errors: errors);
    }
    if (statusCode >= 500 && statusCode < 600) {
      return ServerException(
        statusCode: statusCode,
        message: message,
        code: code,
        errors: errors,
      );
    }
    // Autres 4xx (400, 408, 410, 429, ...) : ApiException brut.
    return ApiException(
      statusCode: statusCode,
      message: message,
      code: code,
      errors: errors,
    );
  }
}

/// 401 — token invalide / expiré. Le caller doit re-login.
class AuthException extends ApiException {
  const AuthException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 401);
}

/// 403 — l'utilisateur est authentifié mais n'a pas le droit.
class ForbiddenException extends ApiException {
  const ForbiddenException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 403);
}

/// 404 — ressource introuvable. Le caller affiche un état vide.
class NotFoundException extends ApiException {
  const NotFoundException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 404);
}

/// 409 — conflit d'état (mission déjà prise, statut déjà transitionné).
/// Le caller doit recharger la donnée puis re-proposer l'action.
class ConflictException extends ApiException {
  const ConflictException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 409);
}

/// 422 — payload invalide. `errors` contient les erreurs champ par champ.
class ValidationException extends ApiException {
  const ValidationException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 422);
}

/// 5xx — erreur serveur. Déjà retryé 3 fois par ApiClient avec backoff.
/// Si on arrive ici, l'incident est durable — prévenir l'utilisateur.
class ServerException extends ApiException {
  const ServerException({
    required super.statusCode,
    required super.message,
    super.code,
    super.errors,
  });
}

/// Erreur réseau (pas de connexion, timeout, DNS). `statusCode = 0`.
/// Pour les actions critiques, le caller doit enqueue l'action via
/// `OfflineQueueService` au lieu d'afficher une erreur.
class NetworkException extends ApiException {
  const NetworkException({
    required super.message,
    super.code,
    super.errors,
  }) : super(statusCode: 0);
}
