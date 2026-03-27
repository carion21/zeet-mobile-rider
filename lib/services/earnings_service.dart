import 'package:rider/core/constants/api.dart';
import 'package:rider/services/api_client.dart';

/// Service pour les gains du rider.
/// Encapsule les appels aux endpoints `/v1/rider/earnings` et `/v1/rider/earnings/history`.
class EarningsService {
  final ApiClient _apiClient;

  EarningsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  // ---------------------------------------------------------------------------
  // GET /v1/rider/earnings
  // ---------------------------------------------------------------------------
  /// Recupere le resume des gains.
  ///
  /// [period] : "day", "week", "month" (optionnel).
  /// [dateFrom] : date de debut au format YYYY-MM-DD (optionnel).
  /// [dateTo] : date de fin au format YYYY-MM-DD (optionnel).
  Future<Map<String, dynamic>> getSummary({
    String? period,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{};
    if (period != null && period.isNotEmpty) queryParams['period'] = period;
    if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;

    final response = await _apiClient.get(
      EarningsEndpoints.summary,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // GET /v1/rider/earnings/history
  // ---------------------------------------------------------------------------
  /// Recupere l'historique pagine des gains.
  ///
  /// [page] : numero de page (defaut 1).
  /// [limit] : nombre d'entrees par page (defaut 10).
  Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    final response = await _apiClient.get(
      EarningsEndpoints.history,
      queryParams: queryParams,
    );
    return response;
  }
}
