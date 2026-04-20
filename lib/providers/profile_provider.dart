import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/models/rider_model.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/services/api_client.dart';
import 'package:rider/services/profile_service.dart';

// ---------------------------------------------------------------------------
// Service Provider
// ---------------------------------------------------------------------------
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// ---------------------------------------------------------------------------
// Profile Edit State
// ---------------------------------------------------------------------------

/// Code d'erreur specifique retourne par le backend quand l'email est deja
/// utilise par un autre compte (409 Conflict).
const String errEmailAlreadyUsed = 'ERR_EMAIL_ALREADY_USED';

class ProfileEditState {
  /// En cours de sauvegarde (PATCH /rider/profile).
  final bool isSaving;

  /// En cours d'upload de la photo (POST /rider/profile/photo).
  final bool isUploadingPhoto;

  /// Dernier message d'erreur (affiche via toast par l'ecran).
  final String? errorMessage;

  /// Flag pour erreur specifique "email already used".
  final bool emailAlreadyUsed;

  const ProfileEditState({
    this.isSaving = false,
    this.isUploadingPhoto = false,
    this.errorMessage,
    this.emailAlreadyUsed = false,
  });

  ProfileEditState copyWith({
    bool? isSaving,
    bool? isUploadingPhoto,
    String? errorMessage,
    bool? emailAlreadyUsed,
    bool clearError = false,
  }) {
    return ProfileEditState(
      isSaving: isSaving ?? this.isSaving,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      emailAlreadyUsed: emailAlreadyUsed ?? this.emailAlreadyUsed,
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Edit Notifier
// ---------------------------------------------------------------------------
class ProfileEditNotifier extends StateNotifier<ProfileEditState> {
  final ProfileService _profileService;
  final Ref _ref;

  ProfileEditNotifier(this._profileService, this._ref)
      : super(const ProfileEditState());

  /// Sauvegarde (patch) les modifications du profil.
  ///
  /// Les champs null ne sont pas envoyes. Retourne `{'success': bool,
  /// 'message': String}`. En cas de succes, le rider global est mis a jour
  /// via [AuthNotifier.updateRider].
  ///
  /// Gestion specifique de l'erreur 409 avec code `ERR_EMAIL_ALREADY_USED` :
  /// l'etat `emailAlreadyUsed` est positionne a true pour permettre a
  /// l'ecran d'afficher un message contextuel sous le champ email.
  Future<Map<String, dynamic>> save({
    String? firstname,
    String? lastname,
    String? email,
    String? gender,
  }) async {
    state = state.copyWith(
      isSaving: true,
      clearError: true,
      emailAlreadyUsed: false,
    );

    try {
      final response = await _profileService.updateProfile(
        firstname: firstname,
        lastname: lastname,
        email: email,
        gender: gender,
      );

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _updateGlobalRider(data);
      }

      state = state.copyWith(isSaving: false);
      return {
        'success': true,
        'message': response['message'] as String? ?? 'Profil mis a jour',
      };
    } on ApiException catch (e) {
      final isEmailConflict = e.statusCode == 409 &&
          (e.errors?['code'] == errEmailAlreadyUsed ||
              e.message.toUpperCase().contains('EMAIL'));

      state = state.copyWith(
        isSaving: false,
        errorMessage: isEmailConflict
            ? 'Cet email est deja utilise par un autre compte.'
            : e.message,
        emailAlreadyUsed: isEmailConflict,
      );
      return {
        'success': false,
        'message': isEmailConflict
            ? 'Cet email est deja utilise par un autre compte.'
            : e.message,
        'emailAlreadyUsed': isEmailConflict,
      };
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Erreur lors de la sauvegarde',
      );
      return {
        'success': false,
        'message': 'Sauvegarde impossible. Réessaye.',
      };
    }
  }

  /// Upload de la photo de profil.
  ///
  /// Met a jour le rider global avec la nouvelle URL `photo` retournee par
  /// l'API. Retourne `{'success': bool, 'message': String}`.
  Future<Map<String, dynamic>> uploadPhoto(File file) async {
    state = state.copyWith(isUploadingPhoto: true, clearError: true);

    try {
      final response = await _profileService.uploadPhoto(file: file);

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _updateGlobalRider(data);
      }

      state = state.copyWith(isUploadingPhoto: false);
      return {
        'success': true,
        'message': response['message'] as String? ?? 'Photo mise a jour',
      };
    } on ApiException catch (e) {
      state = state.copyWith(
        isUploadingPhoto: false,
        errorMessage: e.message,
      );
      return {'success': false, 'message': e.message};
    } catch (e) {
      state = state.copyWith(
        isUploadingPhoto: false,
        errorMessage: 'Envoi impossible. Réessaye.',
      );
      return {
        'success': false,
        'message': "Photo non envoyée. Réessaye.",
      };
    }
  }

  /// Nettoie les erreurs (ex: apres dismissal d'un toast).
  void clearError() {
    state = state.copyWith(clearError: true, emailAlreadyUsed: false);
  }

  void _updateGlobalRider(Map<String, dynamic> data) {
    try {
      // Le payload est un `IUser` : on peut soit utiliser directement
      // RiderModel.fromJson, soit merger sur l'existant pour preserver les
      // champs non retournes (ex: rider_status).
      final current = _ref.read(currentRiderProvider);
      final incoming = RiderModel.fromJson(data);

      final merged = current == null
          ? incoming
          : current.copyWith(
              firstname: incoming.firstname,
              lastname: incoming.lastname,
              email: incoming.email,
              gender: incoming.gender,
              photo: incoming.photo,
            );

      _ref.read(authProvider.notifier).updateRider(merged);
    } catch (_) {
      // Si le parsing echoue on garde le rider existant : l'UI affichera
      // au prochain refresh (`checkAuthStatus`).
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final profileEditProvider =
    StateNotifierProvider<ProfileEditNotifier, ProfileEditState>((ref) {
  final service = ref.watch(profileServiceProvider);
  return ProfileEditNotifier(service, ref);
});
