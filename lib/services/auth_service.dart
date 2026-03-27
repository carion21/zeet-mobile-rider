import 'package:rider/core/constants/api.dart';
import 'package:rider/models/rider_model.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/token_service.dart';

/// Service d'authentification.
/// Encapsule les appels aux endpoints `/v1/auth/*` pour la surface rider.
class AuthService {
  final ApiClient _apiClient;
  final TokenService _tokenService;

  AuthService({
    ApiClient? apiClient,
    TokenService? tokenService,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _tokenService = tokenService ?? TokenService.instance;

  // ---------------------------------------------------------------------------
  // POST /v1/auth/send-otp
  // ---------------------------------------------------------------------------
  /// Envoie un OTP par SMS au numero de telephone fourni.
  ///
  /// [phone] : numero au format local (ex: "0701020304").
  ///
  /// Retourne la reponse brute du serveur (contient "message").
  Future<Map<String, dynamic>> sendOtp({required String phone}) async {
    final response = await _apiClient.post(
      AuthEndpoints.sendOtp,
      body: {'phone': phone},
      withAuth: false,
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/auth/verify-otp
  // ---------------------------------------------------------------------------
  /// Verifie le code OTP et authentifie le rider.
  ///
  /// [phone] : numero de telephone.
  /// [code]  : code OTP a 4 chiffres.
  ///
  /// CRITIQUE : surface = "rider" pour identifier la surface livreur.
  ///
  /// En cas de succes, sauvegarde automatiquement les tokens (access + refresh)
  /// et retourne la reponse contenant les tokens.
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await _apiClient.post(
      AuthEndpoints.verifyOtp,
      body: {
        'phone': phone,
        'code': code,
        'surface': 'rider',
      },
      withAuth: false,
    );

    // Extraire et persister les tokens
    final data = response['data'] as Map<String, dynamic>? ?? response;
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken != null && refreshToken != null) {
      await _tokenService.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }

    return response;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/auth/refresh
  // ---------------------------------------------------------------------------
  /// Rafraichit le token d'acces en utilisant le refresh token stocke.
  ///
  /// Sauvegarde automatiquement les nouveaux tokens.
  /// Retourne `true` si le refresh a reussi, `false` sinon.
  Future<bool> refreshToken() async {
    final refreshToken = await _tokenService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _apiClient.post(
        AuthEndpoints.refresh,
        body: {'refresh_token': refreshToken},
        withAuth: false,
      );

      final data = response['data'] as Map<String, dynamic>? ?? response;
      final newAccessToken = data['access_token'] as String?;
      final newRefreshToken = data['refresh_token'] as String?;

      if (newAccessToken != null) {
        await _tokenService.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken ?? refreshToken,
        );
        return true;
      }

      return false;
    } on ApiException {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // GET /v1/auth/me
  // ---------------------------------------------------------------------------
  /// Recupere le profil du rider connecte.
  ///
  /// Necessite un access token valide (envoye automatiquement via ApiClient).
  /// Retourne un [RiderModel] en cas de succes, incluant le `rider_status`.
  Future<RiderModel> getMe() async {
    final response = await _apiClient.get(
      AuthEndpoints.me,
      withAuth: true,
    );

    final data = response['data'] as Map<String, dynamic>;
    return RiderModel.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // POST /v1/auth/logout
  // ---------------------------------------------------------------------------
  /// Deconnecte le rider en invalidant son refresh token cote serveur,
  /// puis supprime les tokens locaux.
  Future<void> logout() async {
    final refreshToken = await _tokenService.getRefreshToken();

    // Tenter de notifier le serveur (best-effort)
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _apiClient.post(
          AuthEndpoints.logout,
          body: {'refresh_token': refreshToken},
          withAuth: true,
        );
      } catch (_) {
        // On ne bloque pas la deconnexion locale si le serveur echoue
      }
    }

    // Toujours nettoyer les tokens locaux
    await _tokenService.clearTokens();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Verifie si le rider a une session active (tokens stockes).
  Future<bool> isAuthenticated() async {
    return _tokenService.hasTokens();
  }
}
