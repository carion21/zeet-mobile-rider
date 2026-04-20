/// Modeles pour GET /v1/rider/ratings.
///
/// Note : api-reference.json est obsolete pour cet endpoint. La structure
/// ci-dessous est ecrite a la main depuis le contrat BACKEND_WORK_ORDER_REPORT
/// (tache 5, 2026-04-15).
library;

/// Reference legere a une commande liee a une note.
class RatingOrderRef {
  final int id;
  final String? code;

  const RatingOrderRef({required this.id, this.code});

  factory RatingOrderRef.fromJson(Map<String, dynamic> json) {
    return RatingOrderRef(
      id: _asInt(json['id']) ?? 0,
      code: json['code'] as String?,
    );
  }
}

/// Utilisateur qui a attribue la note (surface client / partner).
class RatingRaterUser {
  final int id;
  final String? firstname;
  final String? lastname;
  final String? photo;

  const RatingRaterUser({
    required this.id,
    this.firstname,
    this.lastname,
    this.photo,
  });

  String get displayName {
    final parts = <String>[
      if (firstname != null && firstname!.isNotEmpty) firstname!,
      if (lastname != null && lastname!.isNotEmpty) lastname![0].toUpperCase(),
    ];
    if (parts.isEmpty) return 'Client';
    return parts.join(' ');
  }

  String get initials {
    final chars = <String>[
      if (firstname != null && firstname!.isNotEmpty) firstname![0],
      if (lastname != null && lastname!.isNotEmpty) lastname![0],
    ];
    if (chars.isEmpty) return 'C';
    return chars.join().toUpperCase();
  }

  factory RatingRaterUser.fromJson(Map<String, dynamic> json) {
    return RatingRaterUser(
      id: _asInt(json['id']) ?? 0,
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      photo: json['photo'] as String?,
    );
  }
}

/// Une entree de note recue par le rider.
class RatingEntry {
  final int id;
  final DateTime? dateCreated;
  final int score;
  final String? comment;
  final RatingOrderRef? order;
  final RatingRaterUser? raterUser;

  const RatingEntry({
    required this.id,
    this.dateCreated,
    required this.score,
    this.comment,
    this.order,
    this.raterUser,
  });

  factory RatingEntry.fromJson(Map<String, dynamic> json) {
    return RatingEntry(
      id: _asInt(json['id']) ?? 0,
      dateCreated: _parseDate(json['date_created']),
      score: _asInt(json['score']) ?? 0,
      comment: json['comment'] as String?,
      order: json['order'] is Map<String, dynamic>
          ? RatingOrderRef.fromJson(json['order'] as Map<String, dynamic>)
          : null,
      raterUser: json['rater_user'] is Map<String, dynamic>
          ? RatingRaterUser.fromJson(json['rater_user'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Resume agrege des notes (retourne dans `summary` par l'API).
class RatingSummary {
  final double averageRating;
  final int totalRatings;

  const RatingSummary({
    this.averageRating = 0,
    this.totalRatings = 0,
  });

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    return RatingSummary(
      averageRating: _asDouble(json['average_rating']) ?? 0,
      totalRatings: _asInt(json['total_ratings']) ?? 0,
    );
  }
}

/// Metadonnees de pagination.
class RatingsMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const RatingsMeta({
    this.total = 0,
    this.page = 1,
    this.limit = 25,
    this.totalPages = 1,
  });

  factory RatingsMeta.fromJson(Map<String, dynamic> json) {
    return RatingsMeta(
      total: _asInt(json['total']) ?? 0,
      page: _asInt(json['page']) ?? 1,
      limit: _asInt(json['limit']) ?? 25,
      totalPages: _asInt(json['totalPages']) ?? 1,
    );
  }
}

/// Page complete retournee par GET /v1/rider/ratings.
class RatingsPage {
  final List<RatingEntry> entries;
  final RatingsMeta meta;
  final RatingSummary summary;

  const RatingsPage({
    this.entries = const [],
    this.meta = const RatingsMeta(),
    this.summary = const RatingSummary(),
  });

  factory RatingsPage.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final list = rawData is List
        ? rawData
            .whereType<Map<String, dynamic>>()
            .map(RatingEntry.fromJson)
            .toList()
        : <RatingEntry>[];

    return RatingsPage(
      entries: list,
      meta: json['meta'] is Map<String, dynamic>
          ? RatingsMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : const RatingsMeta(),
      summary: json['summary'] is Map<String, dynamic>
          ? RatingSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : const RatingSummary(),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers de parsing robuste
// ---------------------------------------------------------------------------

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime? _parseDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v);
  }
  return null;
}
