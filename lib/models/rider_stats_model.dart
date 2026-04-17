/// Modele pour GET /v1/rider/stats.
///
/// Note : api-reference.json est obsolete pour cet endpoint. Le payload
/// est defini dans BACKEND_WORK_ORDER_REPORT (tache 6, 2026-04-15).
///
/// IMPORTANT : les metriques `avg_pickup_time`, `avg_delivery_time`,
/// `total_km`, `streak_days`, `total_active_hours` ne sont PAS livrees
/// par le backend — ne pas les modeliser.

class RiderStatsPeriod {
  final String? dateFrom;
  final String? dateTo;

  const RiderStatsPeriod({this.dateFrom, this.dateTo});

  factory RiderStatsPeriod.fromJson(Map<String, dynamic> json) {
    return RiderStatsPeriod(
      dateFrom: json['date_from'] as String?,
      dateTo: json['date_to'] as String?,
    );
  }
}

class RiderStats {
  final RiderStatsPeriod period;
  final int totalDeliveries;
  final int deliveredCount;
  final int notDeliveredCount;
  final int acceptedCount;
  final int rejectedCount;
  final double completionRate;
  final double acceptanceRate;
  final double ratingAvg;
  final int ratingCount;
  final double totalEarnings;

  const RiderStats({
    this.period = const RiderStatsPeriod(),
    this.totalDeliveries = 0,
    this.deliveredCount = 0,
    this.notDeliveredCount = 0,
    this.acceptedCount = 0,
    this.rejectedCount = 0,
    this.completionRate = 0,
    this.acceptanceRate = 0,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.totalEarnings = 0,
  });

  factory RiderStats.fromJson(Map<String, dynamic> json) {
    return RiderStats(
      period: json['period'] is Map<String, dynamic>
          ? RiderStatsPeriod.fromJson(json['period'] as Map<String, dynamic>)
          : const RiderStatsPeriod(),
      totalDeliveries: _asInt(json['total_deliveries']) ?? 0,
      deliveredCount: _asInt(json['delivered_count']) ?? 0,
      notDeliveredCount: _asInt(json['not_delivered_count']) ?? 0,
      acceptedCount: _asInt(json['accepted_count']) ?? 0,
      rejectedCount: _asInt(json['rejected_count']) ?? 0,
      completionRate: _asDouble(json['completion_rate']) ?? 0,
      acceptanceRate: _asDouble(json['acceptance_rate']) ?? 0,
      ratingAvg: _asDouble(json['rating_avg']) ?? 0,
      ratingCount: _asInt(json['rating_count']) ?? 0,
      totalEarnings: _asDouble(json['total_earnings']) ?? 0,
    );
  }
}

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
