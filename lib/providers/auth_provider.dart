import 'package:rider/models/rider_model.dart';
import 'package:rider/services/auth_service.dart';
import 'package:rider/services/api_client.dart';
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

  AuthNotifier(this._authService) : super(const AuthState());

  /// Verifie l'etat d'authentification au demarrage de l'app.
  /// Tente de recuperer le profil rider si des tokens existent.
  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final isAuth = await _authService.isAuthenticated();

      if (!isAuth) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          clearRider: true,
        );
        return;
      }

      // Tenter de recuperer le profil
      final rider = await _authService.getMe();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        rider: rider,
        isLoading: false,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // Token expire et refresh echoue
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          clearRider: true,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          errorMessage: e.message,
          clearRider: true,
        );
      }
    } catch (_) {
      // Erreur reseau ou autre : considerer comme non authentifie
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        clearRider: true,
      );
    }
  }

  /// Envoie un OTP au numero de telephone.
  Future<Map<String, dynamic>> sendOtp({required String phone}) async {
    try {
      final response = await _authService.sendOtp(phone: phone);
      return {'success': true, 'message': response['message'] ?? 'Code envoye avec succes'};
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
      state = state.copyWith(
        status: AuthStatus.authenticated,
        rider: rider,
        isLoading: false,
      );

      return {'success': true, 'message': 'Connexion reussie'};
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

    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      isLoading: false,
      clearRider: true,
      clearError: true,
    );
  }

  /// Met a jour le rider localement (apres un update de profil par ex.).
  void updateRider(RiderModel rider) {
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
