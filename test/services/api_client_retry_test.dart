// test/services/api_client_retry_test.dart
//
// Tests de la politique retry exponentiel + mapping erreurs d'ApiClient
// (lib/services/api_client.dart) :
//   - 503 → 503 → 200 : succès au 3e essai
//   - 503 × 4 : ServerException après épuisement du budget retry (3)
//   - TimeoutException × 4 : NetworkException ERR_NETWORK_RETRY_EXHAUSTED
//   - 401 + refresh + replay : pas de retry sur 401, replay une fois après refresh
//   - 4xx (400/403/404/409/422) : pas de retry, mapping subclass immédiat
//   - Idempotency-Key préservée à travers tous les retries.
//
// Note : on injecte un MockClient (package http/testing.dart) via
// ApiClient.forTesting(...). Pas besoin de mocker le réseau au niveau
// MethodChannel.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rider/core/errors/api_exceptions.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/token_service.dart';

/// Fake [TokenService] qui ne touche ni à FlutterSecureStorage ni à
/// SharedPreferences — implémente uniquement les méthodes publiques
/// utilisées par ApiClient.
class _FakeTokenService implements TokenService {
  _FakeTokenService({
    String? accessToken,
    String? refreshToken,
  })  : _access = accessToken,
        _refresh = refreshToken;

  String? _access;
  String? _refresh;

  /// Compteur d'appels — utile pour vérifier qu'un refresh a bien été déclenché.
  int refreshSavedCount = 0;
  int clearTokensCount = 0;

  @override
  Future<String?> getAccessToken() async => _access;

  @override
  Future<String?> getRefreshToken() async => _refresh;

  @override
  Future<void> setAccessToken(String token) async {
    _access = token;
  }

  @override
  Future<void> setRefreshToken(String token) async {
    _refresh = token;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    refreshSavedCount++;
  }

  @override
  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
    clearTokensCount++;
  }

  @override
  Future<bool> hasTokens() async => _access != null && _access!.isNotEmpty;

  @override
  Future<void> init() async {}

  @override
  Future<bool> isOnboardingSeen() async => true;

  @override
  Future<void> setOnboardingSeen() async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Retry exponentiel sur 5xx', () {
    test('503 → 503 → 200 : retry et succeeds', () async {
      int attempts = 0;
      final client = MockClient((http.Request request) async {
        attempts++;
        if (attempts <= 2) {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': 'Service unavailable'}),
            503,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(<String, dynamic>{'ok': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final api = ApiClient.forTesting(
        httpClient: client,
        tokenService: _FakeTokenService(accessToken: 'tk'),
      );

      final result = await api.get('/v1/rider/stats');

      expect(attempts, 3);
      expect(result['ok'], isTrue);
    });

    test('503 × 4 : retry 3 fois puis throws ServerException', () async {
      int attempts = 0;
      final client = MockClient((http.Request request) async {
        attempts++;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'message': 'Internal error',
            'code': 'ERR_INTERNAL',
          }),
          503,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final api = ApiClient.forTesting(
        httpClient: client,
        tokenService: _FakeTokenService(accessToken: 'tk'),
      );

      await expectLater(
        api.get('/v1/rider/stats'),
        throwsA(isA<ServerException>().having(
          (e) => e.statusCode,
          'statusCode',
          503,
        )),
      );

      // 1 essai initial + 3 retries = 4
      expect(attempts, 4);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Retry sur erreur réseau (TimeoutException)', () {
    test('TimeoutException × 4 : NetworkException ERR_NETWORK_RETRY_EXHAUSTED',
        () async {
      int attempts = 0;
      final client = MockClient((http.Request request) async {
        attempts++;
        // Le code interne d'ApiClient applique son propre `.timeout(...)` —
        // on déclenche directement TimeoutException pour simuler.
        throw TimeoutException('simulated timeout');
      });

      final api = ApiClient.forTesting(
        httpClient: client,
        tokenService: _FakeTokenService(accessToken: 'tk'),
      );

      await expectLater(
        api.get('/v1/rider/stats'),
        throwsA(isA<NetworkException>()
            .having((e) => e.code, 'code', 'ERR_NETWORK_RETRY_EXHAUSTED')
            .having((e) => e.statusCode, 'statusCode', 0)),
      );

      // 1 essai + 3 retries = 4
      expect(attempts, 4);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('401 + refresh + replay', () {
    test('401 puis succès après refresh : pas de retry sur 401', () async {
      int authedAttempts = 0;
      int refreshCalls = 0;

      final client = MockClient((http.Request request) async {
        // Endpoint refresh : succès qui retourne nouveaux tokens
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'access_token': 'new-access',
                'refresh_token': 'new-refresh',
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        authedAttempts++;
        // 1ère tentative : 401 (token expiré)
        // 2e tentative (replay après refresh) : 200
        if (authedAttempts == 1) {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': 'Token expired'}),
            401,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(<String, dynamic>{'ok': true, 'data': 'replayed'}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final fakeToken = _FakeTokenService(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );
      final api = ApiClient.forTesting(
        httpClient: client,
        tokenService: fakeToken,
      );

      final result = await api.get('/v1/rider/profile');

      // Pas de retry sur 401 — exactement 2 appels métier (1 raté + 1 replay)
      expect(authedAttempts, 2);
      expect(refreshCalls, 1);
      expect(result['ok'], isTrue);
      expect(result['data'], 'replayed');
      // Tokens mis à jour
      expect(await fakeToken.getAccessToken(), 'new-access');
      expect(fakeToken.refreshSavedCount, 1);
    });
  });

  group('4xx : pas de retry, mapping subclass immédiat', () {
    Future<void> _expect4xxNoRetry({
      required int statusCode,
      required Type expectedType,
    }) async {
      int attempts = 0;
      final client = MockClient((http.Request request) async {
        attempts++;
        return http.Response(
          jsonEncode(<String, dynamic>{'message': 'metier $statusCode'}),
          statusCode,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final api = ApiClient.forTesting(
        httpClient: client,
        tokenService: _FakeTokenService(accessToken: 'tk'),
      );

      await expectLater(
        api.post('/v1/rider/missions/123/accept', body: <String, dynamic>{}),
        throwsA(predicate(
          (e) =>
              e.runtimeType == expectedType &&
              (e as ApiException).statusCode == statusCode,
          'doit lever $expectedType($statusCode)',
        )),
      );

      // Aucun retry : exactement 1 tentative
      expect(attempts, 1, reason: '$statusCode ne doit jamais être retryé');
    }

    test('400 → ApiException brut, pas de retry', () async {
      await _expect4xxNoRetry(statusCode: 400, expectedType: ApiException);
    });

    test('403 → ForbiddenException, pas de retry', () async {
      await _expect4xxNoRetry(
        statusCode: 403,
        expectedType: ForbiddenException,
      );
    });

    test('404 → NotFoundException, pas de retry', () async {
      await _expect4xxNoRetry(
        statusCode: 404,
        expectedType: NotFoundException,
      );
    });

    test('409 → ConflictException, pas de retry', () async {
      await _expect4xxNoRetry(
        statusCode: 409,
        expectedType: ConflictException,
      );
    });

    test('422 → ValidationException, pas de retry', () async {
      await _expect4xxNoRetry(
        statusCode: 422,
        expectedType: ValidationException,
      );
    });
  });

  group('Idempotency-Key préservée à travers les retries', () {
    test(
        'header Idempotency-Key reste identique sur 503→503→200 et sur replay après refresh',
        () async {
      const idemKey = 'b3c9a0f1-1234-4abc-8def-0123456789ab';
      final seenKeys = <String>[];
      int authedAttempts = 0;

      final client = MockClient((http.Request request) async {
        // refresh endpoint : pas concerné par Idempotency-Key
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'access_token': 'new-access',
                'refresh_token': 'new-refresh',
              },
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        // Toutes les tentatives métier doivent porter l'Idempotency-Key
        final hdr = request.headers['Idempotency-Key'] ??
            request.headers['idempotency-key'];
        if (hdr != null) seenKeys.add(hdr);

        authedAttempts++;
        // Schéma : 401 (déclenche refresh) → 503 (retry) → 503 (retry) → 200
        if (authedAttempts == 1) {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': 'Token expired'}),
            401,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (authedAttempts <= 3) {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': 'svc down'}),
            503,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(<String, dynamic>{'ok': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final api = ApiClient.forTesting(
        httpClient: client,
        tokenService: _FakeTokenService(
          accessToken: 'old',
          refreshToken: 'old-r',
        ),
      );

      final result = await api.post(
        '/v1/rider/missions/42/accept',
        body: <String, dynamic>{'rider_id': 'r-1'},
        extraHeaders: <String, String>{'Idempotency-Key': idemKey},
      );

      expect(result['ok'], isTrue);
      // Toutes les tentatives métier ont vu la même clé
      expect(seenKeys, isNotEmpty);
      expect(seenKeys.every((k) => k == idemKey), isTrue,
          reason: 'Idempotency-Key doit rester stable entre retries et replay');
      // Au moins 4 appels métier : 1 (401) + 2 (503 retry) + 1 (200)
      expect(seenKeys.length, greaterThanOrEqualTo(4));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
