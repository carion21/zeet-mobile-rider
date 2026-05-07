import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de stockage securise des tokens JWT.
///
/// - Tokens (access/refresh) : `flutter_secure_storage`
///   (Keychain iOS / EncryptedSharedPreferences Android).
/// - Onboarding flag : `SharedPreferences` (non sensible).
///
/// Migration douce : au premier `init()`, si des tokens existent encore
/// dans SharedPreferences (heritage v < 1.x) ils sont copies vers le
/// secure storage puis purges des prefs — l'utilisateur deja logge n'est
/// PAS deconnecte par la mise a jour.
class TokenService {
  static const String _accessTokenKey = 'zeet_rider_access_token';
  static const String _refreshTokenKey = 'zeet_rider_refresh_token';
  static const String _onboardingSeenKey = 'zeet_rider_onboarding_seen';

  static TokenService? _instance;
  SharedPreferences? _prefs;
  late final FlutterSecureStorage _secureStorage;
  bool _initialized = false;

  TokenService._() {
    _secureStorage = const FlutterSecureStorage(
      // Options durcies : EncryptedSharedPreferences Android,
      // accessibilite first_unlock iOS (lisible apres premier unlock).
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  /// Singleton pour garantir une seule instance.
  static TokenService get instance {
    _instance ??= TokenService._();
    return _instance!;
  }

  // ---------------------------------------------------------------------------
  // Initialisation + migration douce
  // ---------------------------------------------------------------------------

  /// Initialise le service (doit etre appele au demarrage de l'app).
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!_initialized) {
      await _migrateLegacyTokensIfNeeded();
      _initialized = true;
    }
  }

  /// Assure que les prefs sont initialisees.
  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  /// Migration v0 (SharedPreferences) -> v1 (secure storage).
  /// Idempotente : si le secure storage contient deja un token on n'ecrase pas.
  Future<void> _migrateLegacyTokensIfNeeded() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final legacyAccess = prefs.getString(_accessTokenKey);
    final legacyRefresh = prefs.getString(_refreshTokenKey);

    // Rien a migrer
    if ((legacyAccess == null || legacyAccess.isEmpty) &&
        (legacyRefresh == null || legacyRefresh.isEmpty)) {
      return;
    }

    try {
      final secureAccess = await _secureStorage.read(key: _accessTokenKey);
      final secureRefresh = await _secureStorage.read(key: _refreshTokenKey);

      if ((secureAccess == null || secureAccess.isEmpty) &&
          legacyAccess != null &&
          legacyAccess.isNotEmpty) {
        await _secureStorage.write(key: _accessTokenKey, value: legacyAccess);
      }
      if ((secureRefresh == null || secureRefresh.isEmpty) &&
          legacyRefresh != null &&
          legacyRefresh.isNotEmpty) {
        await _secureStorage.write(key: _refreshTokenKey, value: legacyRefresh);
      }

      // Purge les prefs legacy seulement si la copie a reussi
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
    } catch (_) {
      // En cas d'echec on garde les legacy en place pour retry au prochain init.
    }
  }

  // ---------------------------------------------------------------------------
  // Access Token
  // ---------------------------------------------------------------------------

  Future<String?> getAccessToken() async {
    if (!_initialized) await init();
    return _secureStorage.read(key: _accessTokenKey);
  }

  Future<void> setAccessToken(String token) async {
    if (!_initialized) await init();
    await _secureStorage.write(key: _accessTokenKey, value: token);
  }

  // ---------------------------------------------------------------------------
  // Refresh Token
  // ---------------------------------------------------------------------------

  Future<String?> getRefreshToken() async {
    if (!_initialized) await init();
    return _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> setRefreshToken(String token) async {
    if (!_initialized) await init();
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Sauvegarde les deux tokens d'un coup (apres login/refresh).
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (!_initialized) await init();
    await Future.wait([
      _secureStorage.write(key: _accessTokenKey, value: accessToken),
      _secureStorage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  /// Supprime tous les tokens (deconnexion).
  Future<void> clearTokens() async {
    if (!_initialized) await init();
    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
    ]);
  }

  /// Verifie si un access token est stocke.
  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------

  /// Marque l'onboarding comme vu.
  Future<void> setOnboardingSeen() async {
    final prefs = await _preferences;
    await prefs.setBool(_onboardingSeenKey, true);
  }

  /// Verifie si l'onboarding a deja ete vu.
  Future<bool> isOnboardingSeen() async {
    final prefs = await _preferences;
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }
}
