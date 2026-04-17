import 'package:rider/core/constants/api.dart';
import 'package:rider/services/api_client.dart';

/// Service pour GET /v1/rider/ratings.
/// Pagination : `page`, `limit`, `sort` (defaut cote backend : `-date_created`).
class RatingsService {
  final ApiClient _apiClient;

  RatingsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  /// Recupere une page de notes.
  Future<Map<String, dynamic>> getRatings({
    int page = 1,
    int limit = 25,
    String sort = '-date_created',
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort,
    };

    final response = await _apiClient.get(
      RatingEndpoints.list,
      queryParams: queryParams,
    );
    return response;
  }
}
