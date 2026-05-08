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
  /// [period] : "day" | "week" | "month" — laisse le backend résoudre la fenêtre
  ///   (journée commerciale pour day, semaine ISO pour week, mois calendaire pour month).
  /// [dateFrom] / [dateTo] : ISO dates optionnelles, prioritaires sur [period].
  Future<Map<String, dynamic>> getStats({
    String? period,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{};
    if (period != null && period.isNotEmpty) {
      queryParams['period'] = period;
    }
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

  /// Recupere le classement du rider parmi les actifs aujourd'hui.
  /// Source de la chip social proof "Top X %" sur le Home.
  Future<Map<String, dynamic>> getPercentile() async {
    return _apiClient.get(StatsEndpoints.percentile);
  }
}
