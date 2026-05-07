import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:rider/core/constants/api.dart';
import 'package:rider/core/errors/api_exceptions.dart';
import 'package:rider/core/utils/api_logger.dart';
import 'package:rider/services/token_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

// Re-export pour compat avec les imports existants
// (`import 'package:rider/services/api_client.dart' show ApiException;`).
export 'package:rider/core/errors/api_exceptions.dart';

/// Client HTTP centralise avec gestion automatique :
/// - Headers d'authentification (Bearer token)
/// - Refresh automatique du token sur 401 (race-safe via Completer)
/// - Replay de la requete originale (POST/PUT/PATCH inclus) apres refresh OK
/// - Logging des requetes/reponses (headers sensibles redactes)
/// - Parsing standardise des reponses
class ApiClient {
  static ApiClient? _instance;
  final TokenService _tokenService;
  final http.Client _httpClient;

  /// Timeout par defaut pour les requetes HTTP.
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Politique retry exponentiel sur 5xx + timeout/réseau (plan §7B critère 2).
  /// Délais : 1s → 2s → 4s + jitter aléatoire 0-300ms (anti-stampede).
  static const int _maxRetries = 3;
  static const List<Duration> _retryBackoff = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  static final math.Random _jitterRng = math.Random();

  /// Refresh en cours — evite les rafales concurrentes (multiples 401
  /// simultanes ne declenchent qu'un seul POST /auth/refresh).
  Completer<bool>? _refreshInflight;

  ApiClient._({
    TokenService? tokenService,
    http.Client? httpClient,
  })  : _tokenService = tokenService ?? TokenService.instance,
        _httpClient = httpClient ?? http.Client();

  /// Singleton.
  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  /// Constructeur de test — permet d'injecter un [http.Client] (typiquement
  /// `MockClient` du package `http/testing.dart`) et un [TokenService] mocké.
  /// NE PAS utiliser en production : ne touche pas au singleton.
  @visibleForTesting
  factory ApiClient.forTesting({
    required http.Client httpClient,
    TokenService? tokenService,
  }) {
    return ApiClient._(
      httpClient: httpClient,
      tokenService: tokenService,
    );
  }

  // ---------------------------------------------------------------------------
  // Headers
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _buildHeaders({
    bool withAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };

    if (withAuth) {
      final token = await _tokenService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    }

    // Headers custom mergés en dernier (overrident les standards si conflit) —
    // utilise notamment pour `Idempotency-Key` sur les actions critiques rider.
    if (extraHeaders != null && extraHeaders.isNotEmpty) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  // ---------------------------------------------------------------------------
  // Methodes HTTP publiques
  // ---------------------------------------------------------------------------

  /// GET request.
  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool withAuth = true,
    Map<String, String>? queryParams,
  }) async {
    final url = _buildUrl(endpoint, queryParams);
    return _execWithRefresh(
      method: 'GET',
      uri: url,
      body: null,
      withAuth: withAuth,
    );
  }

  /// POST request.
  ///
  /// [extraHeaders] permet d'injecter des headers custom (ex: `Idempotency-Key`).
  /// Ils sont propages tels quels lors d'un eventuel replay apres refresh,
  /// ce qui est crucial pour l'idempotence (la cle DOIT rester stable).
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final url = _buildUrl(endpoint);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _execWithRefresh(
      method: 'POST',
      uri: url,
      body: encodedBody,
      withAuth: withAuth,
      extraHeaders: extraHeaders,
    );
  }

  /// PUT request.
  ///
  /// Voir [post] pour la semantique de [extraHeaders].
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final url = _buildUrl(endpoint);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _execWithRefresh(
      method: 'PUT',
      uri: url,
      body: encodedBody,
      withAuth: withAuth,
      extraHeaders: extraHeaders,
    );
  }

  /// PATCH request.
  ///
  /// Voir [post] pour la semantique de [extraHeaders].
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    Map<String, String>? extraHeaders,
  }) async {
    final url = _buildUrl(endpoint);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _execWithRefresh(
      method: 'PATCH',
      uri: url,
      body: encodedBody,
      withAuth: withAuth,
      extraHeaders: extraHeaders,
    );
  }

  /// DELETE request.
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool withAuth = true,
  }) async {
    final url = _buildUrl(endpoint);
    return _execWithRefresh(
      method: 'DELETE',
      uri: url,
      body: null,
      withAuth: withAuth,
    );
  }

  // ---------------------------------------------------------------------------
  // POST multipart/form-data (upload de fichier)
  // ---------------------------------------------------------------------------
  /// POST multipart request — utilise pour uploader un fichier (ex: avatar).
  ///
  /// Note : la mecanique de refresh-and-replay n'est PAS appliquee ici (le
  /// MultipartRequest est non rejouable simplement). En cas de 401 le caller
  /// doit gerer la redirection vers login.
  ///
  /// [filePath] : chemin local du fichier a uploader.
  /// [fieldName] : nom du champ attendu par le backend (ex: "file").
  /// [fields] : champs additionnels (optionnels) envoyes dans le meme form.
  /// [contentType] : mime optionnel (ex: "image/jpeg"). Si null, inference auto.
  Future<Map<String, dynamic>> postMultipartFile(
    String endpoint, {
    required String filePath,
    required String fieldName,
    Map<String, String>? fields,
    String? contentType,
    bool withAuth = true,
  }) async {
    final url = _buildUrl(endpoint);
    final headers = await _buildHeaders(withAuth: withAuth);
    // On laisse http construire le content-type multipart boundary.
    headers.remove(HttpHeaders.contentTypeHeader);

    ApiLogger.logRequest(
      method: 'POST[multipart]',
      url: url.toString(),
      headers: headers,
      body: '{"field":"$fieldName","file":"$filePath"}',
    );
    final stopwatch = Stopwatch()..start();

    try {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);
      if (fields != null && fields.isNotEmpty) {
        request.fields.addAll(fields);
      }

      final multipartFile = await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        contentType: contentType != null ? _parseMediaType(contentType) : null,
      );
      request.files.add(multipartFile);

      final streamed = await request.send().timeout(_defaultTimeout);
      final response = await http.Response.fromStream(streamed);
      stopwatch.stop();

      return _parseResponse(
        method: 'POST[multipart]',
        url: url.toString(),
        response: response,
        duration: stopwatch.elapsed,
        requestBody: '{"multipart":"$fieldName"}',
      );
    } catch (e, st) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'POST[multipart]',
        url: url.toString(),
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Parse "image/jpeg" -> MediaType('image', 'jpeg').
  MediaType? _parseMediaType(String value) {
    final parts = value.split('/');
    if (parts.length != 2) return null;
    try {
      return MediaType(parts[0], parts[1]);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Coeur : exec + refresh-and-replay
  // ---------------------------------------------------------------------------

  /// Execute la requete et, sur 401, tente un refresh puis rejoue UNE fois
  /// la meme requete avec le nouveau token. Fonctionne pour toutes les
  /// methodes (GET / POST / PUT / PATCH / DELETE) car le body est capture.
  ///
  /// [extraHeaders] est propage a la fois sur la 1ere tentative ET sur le
  /// replay apres refresh — indispensable pour conserver une cle
  /// `Idempotency-Key` stable.
  Future<Map<String, dynamic>> _execWithRefresh({
    required String method,
    required Uri uri,
    required String? body,
    required bool withAuth,
    Map<String, String>? extraHeaders,
  }) async {
    // 1ere tentative — wrapper retry exponentiel sur 5xx + timeout réseau
    final firstResponse = await _sendWithRetry(
      method: method,
      uri: uri,
      body: body,
      withAuth: withAuth,
      extraHeaders: extraHeaders,
    );

    // Pas un 401 → on parse directement (succes ou erreur metier)
    if (firstResponse.statusCode != 401 || !withAuth) {
      return _parseResponse(
        method: method,
        url: uri.toString(),
        response: firstResponse,
        duration: Duration.zero, // duree deja loggee dans _sendOnce
        requestBody: body,
      );
    }

    // 401 : tenter un refresh (race-safe)
    final refreshed = await _tryRefreshToken();
    if (!refreshed) {
      // Refresh KO → on retombe sur le parsing standard de la 1ere reponse
      return _parseResponse(
        method: method,
        url: uri.toString(),
        response: firstResponse,
        duration: Duration.zero,
        requestBody: body,
      );
    }

    // Refresh OK → rejouer la meme requete avec le nouveau token
    // (extraHeaders rejoue tel quel : `Idempotency-Key` reste stable).
    final retryResponse = await _sendWithRetry(
      method: method,
      uri: uri,
      body: body,
      withAuth: true,
      extraHeaders: extraHeaders,
    );
    return _parseResponse(
      method: method,
      url: uri.toString(),
      response: retryResponse,
      duration: Duration.zero,
      requestBody: body,
    );
  }

  /// Envoie une requête en applicant le retry exponentiel sur 5xx + timeout
  /// réseau (plan §7B critère 2). 4xx ne sont JAMAIS retryés (erreur métier).
  ///
  /// Retry :
  ///   - tentative 1 → délai 1s + jitter
  ///   - tentative 2 → délai 2s + jitter
  ///   - tentative 3 → délai 4s + jitter
  ///   - échec final → propage la dernière réponse / exception
  ///
  /// Sur SocketException / TimeoutException, on relance — au bout des
  /// 3 retries, on émet une [NetworkException] (statusCode 0) que le caller
  /// peut intercepter pour enqueue offline.
  Future<http.Response> _sendWithRetry({
    required String method,
    required Uri uri,
    required String? body,
    required bool withAuth,
    Map<String, String>? extraHeaders,
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      if (attempt > 0) {
        final base = _retryBackoff[attempt - 1];
        final jitter = Duration(milliseconds: _jitterRng.nextInt(300));
        await Future<void>.delayed(base + jitter);
      }
      try {
        final response = await _sendOnce(
          method: method,
          uri: uri,
          body: body,
          withAuth: withAuth,
          extraHeaders: extraHeaders,
        );
        // 5xx → retry. Tous les autres codes (2xx, 3xx, 4xx) → return.
        if (response.statusCode >= 500 && response.statusCode < 600) {
          if (attempt < _maxRetries) continue;
        }
        return response;
      } on TimeoutException catch (e, st) {
        lastError = e;
        lastStack = st;
        if (attempt < _maxRetries) continue;
      } on SocketException catch (e, st) {
        lastError = e;
        lastStack = st;
        if (attempt < _maxRetries) continue;
      } on http.ClientException catch (e, st) {
        // http package wrappe parfois les SocketException
        lastError = e;
        lastStack = st;
        if (attempt < _maxRetries) continue;
      }
    }
    // 3 retries épuisés sans réponse exploitable → NetworkException.
    ApiLogger.logError(
      method: method,
      url: uri.toString(),
      error: lastError ?? 'Retry budget épuisé',
      stackTrace: lastStack,
      requestBody: body,
    );
    throw NetworkException(
      message: 'Connexion impossible. Vérifie ta connexion internet.',
      code: 'ERR_NETWORK_RETRY_EXHAUSTED',
    );
  }

  /// Envoie une requete unique (sans logique de refresh). Logue les events.
  Future<http.Response> _sendOnce({
    required String method,
    required Uri uri,
    required String? body,
    required bool withAuth,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _buildHeaders(
      withAuth: withAuth,
      extraHeaders: extraHeaders,
    );

    ApiLogger.logRequest(
      method: method,
      url: uri.toString(),
      headers: headers,
      body: body,
    );
    final stopwatch = Stopwatch()..start();

    try {
      final http.Response response;
      switch (method) {
        case 'GET':
          response = await _httpClient
              .get(uri, headers: headers)
              .timeout(_defaultTimeout);
          break;
        case 'DELETE':
          response = await _httpClient
              .delete(uri, headers: headers)
              .timeout(_defaultTimeout);
          break;
        case 'POST':
          response = await _httpClient
              .post(uri, headers: headers, body: body)
              .timeout(_defaultTimeout);
          break;
        case 'PUT':
          response = await _httpClient
              .put(uri, headers: headers, body: body)
              .timeout(_defaultTimeout);
          break;
        case 'PATCH':
          response = await _httpClient
              .patch(uri, headers: headers, body: body)
              .timeout(_defaultTimeout);
          break;
        default:
          throw ApiException(
            statusCode: 0,
            message: 'Methode HTTP non supportee: $method',
          );
      }
      stopwatch.stop();

      // Log de la reponse (le _parseResponse logge aussi mais on veut la
      // duree exacte de l'aller-retour reseau ici).
      final decoded = _safeDecode(response.body);
      ApiLogger.logResponse(
        method: method,
        url: uri.toString(),
        statusCode: response.statusCode,
        body: decoded,
        duration: stopwatch.elapsed,
      );

      return response;
    } catch (e, st) {
      stopwatch.stop();
      ApiLogger.logError(
        method: method,
        url: uri.toString(),
        error: e,
        stackTrace: st,
        requestBody: body,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Gestion des reponses
  // ---------------------------------------------------------------------------

  /// Parse la reponse HTTP en Map. Lance ApiException sur erreur metier.
  Map<String, dynamic> _parseResponse({
    required String method,
    required String url,
    required http.Response response,
    required Duration duration,
    required String? requestBody,
  }) {
    final body = _safeDecode(response.body);

    // Succes (2xx)
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body['message'] is String
        ? body['message'] as String
        : body['message'] is List
            ? (body['message'] as List).join(', ')
            : 'Une erreur est survenue';
    final errorCode = body['code'] as String?;

    // Log consolide avec input + reponse pour faciliter le debug
    ApiLogger.logError(
      method: method,
      url: url,
      error: 'HTTP ${response.statusCode}: $message',
      statusCode: response.statusCode,
      requestBody: requestBody,
      responseBody: body,
    );

    throw ApiException.fromStatus(
      statusCode: response.statusCode,
      message: message,
      code: errorCode,
      errors: body['errors'] as Map<String, dynamic>?,
    );
  }

  /// Decode JSON en `Map<String, dynamic>` de facon defensive : si le
  /// serveur renvoie du non-JSON, on jette une ApiException explicite
  /// (5xx HTML, reverse-proxy down, etc.) plutot qu'un FormatException brut.
  Map<String, dynamic> _safeDecode(String raw) {
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      // Le backend ZEET renvoie toujours un objet — un array/string n'est
      // pas un cas legitime ici.
      throw const FormatException('Payload non objet');
    } catch (_) {
      throw const NetworkException(
        message: 'Reponse invalide du serveur',
        code: 'ERR_INVALID_RESPONSE',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Refresh token race-safe
  // ---------------------------------------------------------------------------

  /// Tente de rafraichir le token d'acces. Si un refresh est deja en cours,
  /// les appelants concurrents attendent le meme resultat (pas de stampede).
  Future<bool> _tryRefreshToken() async {
    final inflight = _refreshInflight;
    if (inflight != null) return inflight.future;

    final completer = Completer<bool>();
    _refreshInflight = completer;
    try {
      final ok = await _doRefresh();
      completer.complete(ok);
      return ok;
    } catch (_) {
      completer.complete(false);
      return false;
    } finally {
      _refreshInflight = null;
    }
  }

  /// Logique reelle d'echange refresh_token -> access_token.
  ///
  /// IMPORTANT — Politique de nettoyage des tokens :
  /// On ne supprime les tokens locaux QUE si le serveur a explicitement
  /// rejete le refresh token (401/403). Sur erreur reseau, timeout, ou
  /// 5xx serveur, on garde les tokens : le rider reessaiera au prochain
  /// cold-start ou requete authentifiee. Sans cette regle, un cold-start
  /// en 3G fragile / backend en panne deconnecte le rider de force, ce
  /// qui le force a re-saisir un OTP — bloquant en zone reseau lente.
  Future<bool> _doRefresh() async {
    final refreshToken = await _tokenService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      // Pas de refresh token → impossible de refresh, mais rien a nettoyer
      // (l'access token seul est sans valeur, le caller redirige login).
      return false;
    }

    final url = _buildUrl(AuthEndpoints.refresh);
    final headers = {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
    final body = jsonEncode({'refresh_token': refreshToken});

    final http.Response response;
    try {
      response = await _httpClient
          .post(url, headers: headers, body: body)
          .timeout(_defaultTimeout);
    } catch (_) {
      // Erreur reseau / timeout / DNS — on NE supprime PAS les tokens.
      // Le rider reste localement "connu" et retentera au prochain coup.
      return false;
    }

    // Succes : extraire et persister les nouveaux tokens.
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = _safeDecode(response.body);
        final responseData = data['data'] as Map<String, dynamic>? ?? data;
        final newAccessToken = responseData['access_token'] as String?;
        final newRefreshToken = responseData['refresh_token'] as String?;
        if (newAccessToken != null) {
          await _tokenService.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? refreshToken,
          );
          return true;
        }
      } catch (_) {
        // Reponse 2xx mais body malforme : pas de token sauvegarde, mais
        // on ne purge pas non plus (probleme cote backend, pas cote rider).
        return false;
      }
    }

    // Rejet explicite du refresh token par le serveur : on nettoie pour
    // forcer une nouvelle authentification. Tout autre statut (5xx, 4xx
    // non-auth) → on garde les tokens et on retournera false sans purge.
    if (response.statusCode == 401 || response.statusCode == 403) {
      await _tokenService.clearTokens();
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Uri _buildUrl(String endpoint, [Map<String, String>? queryParams]) {
    final fullUrl = '${ApiConfig.baseUrl}$endpoint';
    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }
}
