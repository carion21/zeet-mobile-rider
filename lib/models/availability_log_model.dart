// lib/models/availability_log_model.dart
//
// Modele pour l'endpoint GET /v1/rider/availability-log (historique des
// bascules online/offline du rider, paginé, filtrable par date).

class AvailabilityLogMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const AvailabilityLogMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  bool get hasNextPage => page < totalPages;

  factory AvailabilityLogMeta.fromJson(Map<String, dynamic> json) {
    return AvailabilityLogMeta(
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 25,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class AvailabilityLogEntry {
  final int? id;
  final bool isOnline;
  final DateTime? fromAt;
  final DateTime? toAt;
  final int? durationSeconds;
  final String? source;
  final String? note;

  const AvailabilityLogEntry({
    this.id,
    required this.isOnline,
    this.fromAt,
    this.toAt,
    this.durationSeconds,
    this.source,
    this.note,
  });

  /// Label court pour la timeline.
  String get statusLabel => isOnline ? 'En ligne' : 'Hors ligne';

  /// Duree humaine (ex: "2h 15min", "45min", "30s").
  String get displayDuration {
    final total = durationSeconds ??
        (fromAt != null && toAt != null
            ? toAt!.difference(fromAt!).inSeconds
            : null);
    if (total == null || total <= 0) return '--';
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}min' : '${hours}h';
    }
    if (minutes > 0) {
      return '${minutes}min';
    }
    return '${seconds}s';
  }

  factory AvailabilityLogEntry.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic raw, {bool fallback = false}) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final l = raw.toLowerCase();
        return l == 'true' || l == '1' || l == 'online' || l == 'on';
      }
      return fallback;
    }

    // L'API peut exposer soit `is_online` bool, soit `status` string ("online"
    // / "offline") — on gere les deux.
    final statusRaw = json['status'] ?? json['state'];
    final isOnline = json.containsKey('is_online')
        ? parseBool(json['is_online'])
        : parseBool(statusRaw);

    return AvailabilityLogEntry(
      id: (json['id'] as num?)?.toInt(),
      isOnline: isOnline,
      fromAt: _parseDate(json['from_at'] ??
          json['started_at'] ??
          json['date_created'] ??
          json['from']),
      toAt: _parseDate(
          json['to_at'] ?? json['ended_at'] ?? json['until'] ?? json['to']),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ??
          (json['duration'] as num?)?.toInt(),
      source: (json['source'] ?? json['origin']) as String?,
      note: (json['note'] ?? json['comment']) as String?,
    );
  }
}

class AvailabilityLogPage {
  final List<AvailabilityLogEntry> data;
  final AvailabilityLogMeta meta;

  const AvailabilityLogPage({required this.data, required this.meta});
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
