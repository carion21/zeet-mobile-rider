import 'package:rider/core/constants/api.dart';
import 'package:rider/services/api_client.dart';

/// Service pour GET /v1/rider/stats.
/// Retourne les statistiques agregees du rider sur une periode.
class StatsService {
  final ApiClient _apiClient;

  StatsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Recupere les statistiques du rider.
  ///
  /// [dateFrom] et [dateTo] sont des ISO dates (YYYY-MM-DD) optionnelles.
  /// Sans parametres, le backend applique sa periode par defaut (generalement
  /// mois courant).
  Future<Map<String, dynamic>> getStats({
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{};
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams['date_from'] = dateFrom;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParams['date_to'] = dateTo;
    }

    final response = await _apiClient.get(
      StatsEndpoints.summary,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    return response;
  }
}
