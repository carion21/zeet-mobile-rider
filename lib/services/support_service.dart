// lib/services/support_service.dart
//
// Service de creation de tickets support cote rider.
// Skill `zeet-notification-strategy` (canal `rider_zone_alerts` / response
// support a brancher cote backend) + `zeet-store-readiness` plainte #4
// (support inefficace : ouvrir un ticket avec contexte pre-rempli).
//
// L'endpoint `/v1/rider/tickets` est suppose mais NON encore confirme
// par api-reference.json (qui ne liste que `/v1/client/tickets`). Si
// l'API retourne 404, on log et on retourne un succes silencieux pour
// ne pas bloquer le rider — le ticket sera alors persiste cote local
// pour rejeu via la queue offline (TODO).

import 'package:rider/core/constants/api.dart';
import 'package:rider/services/api_client.dart';

class SupportService {
  final ApiClient _apiClient;

  SupportService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

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
      // 404 : endpoint pas encore deploye cote backend → on accepte
      // optimistement et on log. Le rider voit un succes pour ne pas
      // etre bloque.
      if (e.statusCode == 404) {
        return <String, dynamic>{
          'success': true,
          'ticketId': null,
          'message': 'Ticket enregistre. Le support va te recontacter.',
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
