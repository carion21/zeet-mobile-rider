import 'dart:io';

import 'package:rider/core/constants/api.dart';
import 'package:rider/services/api_client.dart';

/// Service pour la gestion du profil rider.
///
/// Endpoints :
/// - PATCH /v1/rider/profile  (update partiel firstname/lastname/email/gender)
/// - POST  /v1/rider/profile/photo  (upload avatar multipart/form-data)
class ProfileService {
  final ApiClient _apiClient;

  ProfileService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Limite de taille du fichier avatar (5 MB).
  static const int maxPhotoBytes = 5 * 1024 * 1024;

  /// Mimes acceptes cote backend.
  static const Set<String> allowedPhotoMimes = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  };

  // ---------------------------------------------------------------------------
  // PATCH /v1/rider/profile
  // ---------------------------------------------------------------------------
  /// Met a jour le profil rider (patch partiel).
  ///
  /// Chaque champ est optionnel. Seuls les champs non nuls sont envoyes.
  /// Retourne la reponse brute (`{message, data: IUser}`).
  Future<Map<String, dynamic>> updateProfile({
    String? firstname,
    String? lastname,
    String? email,
    String? gender,
  }) async {
    final body = <String, dynamic>{};
    if (firstname != null) body['firstname'] = firstname;
    if (lastname != null) body['lastname'] = lastname;
    if (email != null) body['email'] = email;
    if (gender != null) body['gender'] = gender;

    final response = await _apiClient.patch(
      ProfileEndpoints.update,
      body: body,
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // POST /v1/rider/profile/photo
  // ---------------------------------------------------------------------------
  /// Upload de la photo de profil (multipart/form-data, champ "file").
  ///
  /// La validation taille/mime est appliquee AVANT envoi cote client pour
  /// eviter des round-trips inutiles. Le backend les revalide ensuite.
  Future<Map<String, dynamic>> uploadPhoto({
    required File file,
    String? contentType,
  }) async {
    final bytes = await file.length();
    if (bytes > maxPhotoBytes) {
      throw const ApiException(
        statusCode: 400,
        message: 'Fichier trop volumineux (max 5 MB).',
      );
    }

    String? effectiveMime = contentType;
    effectiveMime ??= _guessMimeFromPath(file.path);

    if (effectiveMime == null || !allowedPhotoMimes.contains(effectiveMime)) {
      throw const ApiException(
        statusCode: 400,
        message: 'Format invalide. Formats acceptes : JPG, PNG, WEBP.',
      );
    }

    final response = await _apiClient.postMultipartFile(
      ProfileEndpoints.photo,
      filePath: file.path,
      fieldName: 'file',
      contentType: effectiveMime,
    );
    return response;
  }

  String? _guessMimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
  }
}
