// test/core/errors/api_exceptions_test.dart
//
// Tests de la hiérarchie d'exceptions API typées (lib/core/errors/api_exceptions.dart) :
//   - mapping `ApiException.fromStatus(...)` -> sous-classes spécifiques
//   - helpers booléens isUnauthorized / isForbidden / etc.
//   - format `toString()`.

import 'package:flutter_test/flutter_test.dart';
import 'package:rider/core/errors/api_exceptions.dart';

void main() {
  group('ApiException.fromStatus mapping', () {
    test('401 -> AuthException', () {
      final e = ApiException.fromStatus(
        statusCode: 401,
        message: 'Token expiré',
        code: 'ERR_TOKEN_EXPIRED',
      );
      expect(e, isA<AuthException>());
      expect(e.statusCode, 401);
      expect(e.message, 'Token expiré');
      expect(e.code, 'ERR_TOKEN_EXPIRED');
    });

    test('403 -> ForbiddenException', () {
      final e = ApiException.fromStatus(
        statusCode: 403,
        message: 'Accès refusé',
      );
      expect(e, isA<ForbiddenException>());
      expect(e.statusCode, 403);
    });

    test('404 -> NotFoundException', () {
      final e = ApiException.fromStatus(
        statusCode: 404,
        message: 'Mission introuvable',
      );
      expect(e, isA<NotFoundException>());
      expect(e.statusCode, 404);
    });

    test('409 -> ConflictException', () {
      final e = ApiException.fromStatus(
        statusCode: 409,
        message: 'Mission déjà prise',
        code: 'ERR_MISSION_ALREADY_TAKEN',
      );
      expect(e, isA<ConflictException>());
      expect(e.statusCode, 409);
      expect(e.code, 'ERR_MISSION_ALREADY_TAKEN');
    });

    test('422 -> ValidationException avec errors champ par champ', () {
      final errors = <String, dynamic>{
        'phone': ['Format invalide'],
      };
      final e = ApiException.fromStatus(
        statusCode: 422,
        message: 'Validation échouée',
        errors: errors,
      );
      expect(e, isA<ValidationException>());
      expect(e.statusCode, 422);
      expect(e.errors, equals(errors));
    });

    test('500 -> ServerException', () {
      final e = ApiException.fromStatus(
        statusCode: 500,
        message: 'Erreur interne',
      );
      expect(e, isA<ServerException>());
      expect(e.statusCode, 500);
    });

    test('502 -> ServerException', () {
      final e = ApiException.fromStatus(
        statusCode: 502,
        message: 'Bad gateway',
      );
      expect(e, isA<ServerException>());
      expect(e.statusCode, 502);
    });

    test('503 -> ServerException', () {
      final e = ApiException.fromStatus(
        statusCode: 503,
        message: 'Service indisponible',
      );
      expect(e, isA<ServerException>());
      expect(e.statusCode, 503);
    });

    test('0 -> NetworkException', () {
      final e = ApiException.fromStatus(
        statusCode: 0,
        message: 'Pas de connexion',
        code: 'ERR_NETWORK',
      );
      expect(e, isA<NetworkException>());
      expect(e.statusCode, 0);
      expect(e.code, 'ERR_NETWORK');
    });

    test('400 -> ApiException brut (pas de subclass spécifique)', () {
      final e = ApiException.fromStatus(
        statusCode: 400,
        message: 'Bad request',
      );
      expect(e.runtimeType, ApiException);
      expect(e, isNot(isA<AuthException>()));
      expect(e, isNot(isA<ValidationException>()));
      expect(e.statusCode, 400);
    });

    test('418 -> ApiException brut', () {
      final e = ApiException.fromStatus(
        statusCode: 418,
        message: "I'm a teapot",
      );
      expect(e.runtimeType, ApiException);
      expect(e.statusCode, 418);
    });

    test('429 -> ApiException brut', () {
      final e = ApiException.fromStatus(
        statusCode: 429,
        message: 'Trop de requêtes',
      );
      expect(e.runtimeType, ApiException);
      expect(e.statusCode, 429);
    });
  });

  group('helpers booléens', () {
    test('isUnauthorized vrai uniquement pour 401', () {
      expect(
        ApiException.fromStatus(statusCode: 401, message: '').isUnauthorized,
        isTrue,
      );
      expect(
        ApiException.fromStatus(statusCode: 403, message: '').isUnauthorized,
        isFalse,
      );
      expect(
        ApiException.fromStatus(statusCode: 500, message: '').isUnauthorized,
        isFalse,
      );
    });

    test('isForbidden vrai uniquement pour 403', () {
      expect(
        ApiException.fromStatus(statusCode: 403, message: '').isForbidden,
        isTrue,
      );
      expect(
        ApiException.fromStatus(statusCode: 401, message: '').isForbidden,
        isFalse,
      );
    });

    test('isNotFound vrai uniquement pour 404', () {
      expect(
        ApiException.fromStatus(statusCode: 404, message: '').isNotFound,
        isTrue,
      );
      expect(
        ApiException.fromStatus(statusCode: 409, message: '').isNotFound,
        isFalse,
      );
    });

    test('isConflict vrai uniquement pour 409', () {
      expect(
        ApiException.fromStatus(statusCode: 409, message: '').isConflict,
        isTrue,
      );
      expect(
        ApiException.fromStatus(statusCode: 422, message: '').isConflict,
        isFalse,
      );
    });

    test('isValidation vrai uniquement pour 422', () {
      expect(
        ApiException.fromStatus(statusCode: 422, message: '').isValidation,
        isTrue,
      );
      expect(
        ApiException.fromStatus(statusCode: 400, message: '').isValidation,
        isFalse,
      );
    });

    test('isServerError vrai pour toute la plage 5xx', () {
      for (final code in <int>[500, 502, 503, 504, 599]) {
        expect(
          ApiException.fromStatus(statusCode: code, message: '').isServerError,
          isTrue,
          reason: 'isServerError doit être true pour $code',
        );
      }
      expect(
        ApiException.fromStatus(statusCode: 499, message: '').isServerError,
        isFalse,
      );
      expect(
        ApiException.fromStatus(statusCode: 600, message: '').isServerError,
        isFalse,
      );
    });

    test('isNetwork vrai uniquement pour statusCode 0', () {
      expect(
        ApiException.fromStatus(statusCode: 0, message: '').isNetwork,
        isTrue,
      );
      expect(
        ApiException.fromStatus(statusCode: 500, message: '').isNetwork,
        isFalse,
      );
    });
  });

  group('toString()', () {
    test('contient runtimeType + statusCode + message', () {
      final e = ApiException.fromStatus(
        statusCode: 404,
        message: 'Mission introuvable',
      );
      final s = e.toString();
      expect(s, contains('NotFoundException'));
      expect(s, contains('404'));
      expect(s, contains('Mission introuvable'));
    });

    test('inclut le code métier quand fourni', () {
      final e = ApiException.fromStatus(
        statusCode: 409,
        message: 'Mission déjà prise',
        code: 'ERR_MISSION_ALREADY_TAKEN',
      );
      final s = e.toString();
      expect(s, contains('ConflictException'));
      expect(s, contains('409'));
      expect(s, contains('ERR_MISSION_ALREADY_TAKEN'));
      expect(s, contains('Mission déjà prise'));
    });

    test("ApiException brut affiche 'ApiException(...)' pour 400", () {
      final e = ApiException.fromStatus(
        statusCode: 400,
        message: 'Bad request',
      );
      final s = e.toString();
      expect(s, contains('ApiException'));
      expect(s, contains('400'));
      expect(s, contains('Bad request'));
    });
  });
}
