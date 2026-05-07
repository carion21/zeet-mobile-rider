// lib/services/support_service.dart
//
// Service de creation de tickets support cote rider.
// Skill `zeet-notification-strategy` (canal `rider_zone_alerts` / response
// support a brancher cote backend) + `zeet-store-readiness` plainte #4
// (support inefficace : ouvrir un ticket avec contexte pre-rempli).
//
// IMPORTANT — etat backend (audit 2026-05) :
// L'endpoint `/v1/rider/tickets` n'existe PAS cote zeet-core-system.
// Le backend expose uniquement `/v1/client/tickets`, `/v1/partner/tickets`
// et `/v1/admin/tickets`. Tant que la route rider n'est pas deployee
// (TODO core-system), on tombe systematiquement en fallback 404.
// Cote rider on transforme alors le 404 en message honnete avec un
// fallback contact direct (WhatsApp/telephone) — pas de "succes
// silencieux" mensonger qui laisserait croire que le ticket a ete
// pris en charge.

import 'package:flutter/foundation.dart';
import 'package:rider/core/constants/api.dart';
import 'package:rider/services/api_client.dart';

class SupportService {
  final ApiClient _apiClient;

  SupportService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Numero WhatsApp support ZEET — fallback quand l'endpoint rider
  /// n'est pas (encore) deploye. A externaliser dans une remote config
  /// quand le mecanisme sera en place.
  static const String supportWhatsappNumber = '+221 78 000 00 00';

  /// Cree un ticket support contextualise depuis une mission rider.
  ///
  /// Retourne `{success: bool, ticketId?: String, message: String}`.
  /// Tolere un 404 cote backend (endpoint pas encore deploye) en
  /// retournant success=true + message generique.
  Future<Map<String, dynamic>> createTicket({
    required String missionId,
    required String missionRef,
    required String reason,
    String? note,
    String? addressContext,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'mission_id': missionId,
      'mission_ref': missionRef,
      'reason': reason,
      'priority': 'normal',
    };
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }
    if (addressContext != null && addressContext.isNotEmpty) {
      body['address_context'] = addressContext;
    }

    try {
      final response = await _apiClient.post(
        SupportEndpoints.createTicket,
        body: body,
      );

      final data = response['data'] as Map<String, dynamic>? ?? response;
      final ticketId = data['id']?.toString() ?? data['ticket_id']?.toString();

      return <String, dynamic>{
        'success': true,
        'ticketId': ticketId,
        'message': response['message'] as String? ??
            'Ticket envoye. Le support te recontacte vite.',
      };
    } on ApiException catch (e) {
      // 404 : endpoint `/rider/tickets` pas deploye cote core-system.
      // On retourne un echec EXPLICITE avec fallback WhatsApp pour ne
      // pas mentir au rider (ne PAS pretendre que le ticket est pris).
      if (e.statusCode == 404) {
        if (kDebugMode) {
          debugPrint(
            '[SupportService] 404 sur ${SupportEndpoints.createTicket} — '
            'endpoint rider non deploye (cf. backend audit 2026-05).',
          );
        }
        return <String, dynamic>{
          'success': false,
          'fallbackContact': supportWhatsappNumber,
          'message':
              "Le support en ligne sera disponible bientôt. En attendant, "
              "contacte-nous sur WhatsApp au $supportWhatsappNumber.",
        };
      }
      return <String, dynamic>{
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': "Impossible d'envoyer le ticket. Reessaye.",
      };
    }
  }
}
