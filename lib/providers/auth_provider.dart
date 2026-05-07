import 'package:rider/models/rider_model.dart';
import 'package:rider/services/auth_service.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/cache_policies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Auth Service Provider
// ---------------------------------------------------------------------------
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ---------------------------------------------------------------------------
// Auth State
// ---------------------------------------------------------------------------

/// Etats possibles de l'authentification.
enum AuthStatus {
  /// Etat initial, non encore determine.
  unknown,

  /// Le rider est authentifie.
  authenticated,

  /// Le rider n'est pas authentifie.
  unauthenticated,
}

/// Etat complet de l'authentification.
class AuthState {
  final AuthStatus status;
  final RiderModel? rider;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.rider,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    RiderModel? rider,
    bool? isLoading,
    String? errorMessage,
    bool clearRider = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      rider: clearRider ? null : (rider ?? this.rider),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth Notifier
// ---------------------------------------------------------------------------
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  DateTime? _profileFetchedAt;

  AuthNotifier(this._authService) : super(const AuthState());

  /// Verifie l'etat d'authentification au demarrage de l'app.
  /// Tente de recuperer le profil rider si des tokens existent.
  ///
  /// Politique de tolerance reseau :
  /// - Pas de tokens → unauthenticated (login).
  /// - Tokens + 401 (refresh KO cote serveur) → unauthenticated (login).
  /// - Tokens + erreur reseau / 5xx / timeout → on **conserve** la
  ///   session locale (status authenticated, rider=null si jamais
  ///   recupere). Le rider passe la garde du splash et l'app fonctionne
  ///   en mode degrade. Sans cette regle, un cold-start en 3G fragile
  ///   ou backend down deconnectait le rider et l'obligeait a refaire
  ///   un OTP — bloquant en zone reseau lente.
  ///
  /// [force] : si `true`, ignore le TTL [CachePolicy.profile] (1h) et
  /// refetch le profil. Sinon, si le profil a deja ete recupere recemment,
  /// on saute l'appel `getMe()` et on garde le rider deja en state.
  Future<void> checkAuthStatus({bool force = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final hasLocalSession = await _authService.isAuthenticated();
    if (!hasLocalSession) {
      _profileFetchedAt = null;
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        clearRider: true,
      );
      return;
    }

    // Court-circuit cache : profil deja a jour → no-op API.
    if (!force &&
        _profileFetchedAt != null &&
        CachePolicies.fresh(CachePolicy.profile, _profileFetchedAt!) &&
        state.rider != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        isLoading: false,
      );
      return;
    }

    try {
      final rider = await _authService.getMe();
      _profileFetchedAt = DateTime.now();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        rider: rider,
        isLoading: false,
      );
    } on ApiException catch (e) {
      _profileFetchedAt = null;
      // Seul un 401/403 explicite (token rejete par le serveur) doit
      // deconnecter le rider. Les 5xx ou erreurs metier autres laissent
      // la session intacte.
      if (e.isUnauthorized || e.statusCode == 403) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          clearRider: true,
        );
      } else {
        // Erreur metier / serveur sans rejet d'auth : on garde la session
        // mais sans profil. Les ecrans authentifies geront `rider == null`
        // en degradant l'UI (cf. screens qui watch `currentRiderProvider`).
        state = state.copyWith(
          status: AuthStatus.authenticated,
          isLoading: false,
          errorMessage: e.message,
        );
      }
    } catch (_) {
      _profileFetchedAt = null;
      // Erreur reseau / timeout / DNS — on garde la session locale.
      // Le rider entrera dans l'app, les requetes ulterieures relanceront
      // un refresh quand le reseau reviendra.
      state = state.copyWith(
        status: AuthStatus.authenticated,
        isLoading: false,
      );
    }
  }

  /// Envoie un OTP au numero de telephone.
  Future<Map<String, dynamic>> sendOtp({required String phone}) async {
    try {
      final response = await _authService.sendOtp(phone: phone);
      return {'success': true, 'message': response['message'] ?? 'Code envoyé avec succès'};
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion au serveur'};
    }
  }

  /// Verifie l'OTP et connecte le rider.
  /// Gestion specifique du 403 : le rider n'est pas enregistre.
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authService.verifyOtp(phone: phone, code: code);

      // Recuperer le profil rider
      final rider = await _authService.getMe();
      _profileFetchedAt = DateTime.now();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        rider: rider,
        isLoading: false,
      );

      return {'success': true, 'message': 'Connexion réussie'};
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);

      // 403 Forbidden : le numero n'est pas enregistre comme rider
      if (e.isForbidden) {
        return {
          'success': false,
          'message': "Ce numero n'est pas enregistre comme livreur ZEET. Contactez le support pour vous inscrire.",
        };
      }

      return {'success': false, 'message': e.message};
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Erreur de connexion au serveur');
      return {'success': false, 'message': 'Erreur de connexion au serveur'};
    }
  }

  /// Deconnecte le rider.
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    await _authService.logout();

    _profileFetchedAt = null;
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      isLoading: false,
      clearRider: true,
      clearError: true,
    );
  }

  /// Met a jour le rider localement (apres un update de profil par ex.).
  /// Reset du marker cache pour qu'un prochain checkAuthStatus refetch
  /// fraichement (le PATCH peut ne pas renvoyer tous les champs).
  void updateRider(RiderModel rider) {
    _profileFetchedAt = DateTime.now();
    state = state.copyWith(rider: rider);
  }
}

// ---------------------------------------------------------------------------
// Providers Riverpod
// ---------------------------------------------------------------------------

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

/// Provider pratique pour acceder directement au rider.
final currentRiderProvider = Provider<RiderModel?>((ref) {
  return ref.watch(authProvider).rider;
});

/// Provider pratique pour savoir si le rider est connecte.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});
