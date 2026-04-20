/// Modeles representant les gains du rider cote API.
/// Correspond aux reponses de `GET /v1/rider/earnings` et `GET /v1/rider/earnings/history`.
///
/// Parsing defensif : tous les champs nullable sauf ceux structurels.
library;

// ---------------------------------------------------------------------------
// Earnings Summary
// ---------------------------------------------------------------------------

/// Point de la serie temporelle de gains (une tranche de la periode).
/// Correspond a un element de `by_period` retourne par `GET /v1/rider/earnings`.
class EarningsPeriodPoint {
  /// Date ou tranche horaire brute retournee par l'API (ex: "2026-03-27" ou "08:00").
  final String date;
  final int deliveryCount;
  final double earnings;

  const EarningsPeriodPoint({
    required this.date,
    this.deliveryCount = 0,
    this.earnings = 0,
  });

  factory EarningsPeriodPoint.fromJson(Map<String, dynamic> json) {
    return EarningsPeriodPoint(
      date: (json['date'] ?? json['label'] ?? json['period'] ?? '').toString(),
      deliveryCount: json['delivery_count'] as int?
          ?? json['deliveries'] as int?
          ?? json['count'] as int?
          ?? 0,
      earnings: _parseDouble(
            json['earnings'] ?? json['total_earnings'] ?? json['amount'],
          ) ??
          0,
    );
  }
}

/// Resume des gains sur une periode (jour, semaine, mois).
class EarningsSummary {
  final double totalEarnings;
  final double deliveryFees;
  final double tips;
  final double bonuses;
  final int totalDeliveries;
  final int completedDeliveries;
  final int cancelledDeliveries;
  final double averagePerDelivery;
  final String? period;
  final String? dateFrom;
  final String? dateTo;
  final List<EarningsPeriodPoint> byPeriod;

  const EarningsSummary({
    this.totalEarnings = 0,
    this.deliveryFees = 0,
    this.tips = 0,
    this.bonuses = 0,
    this.totalDeliveries = 0,
    this.completedDeliveries = 0,
    this.cancelledDeliveries = 0,
    this.averagePerDelivery = 0,
    this.period,
    this.dateFrom,
    this.dateTo,
    this.byPeriod = const [],
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    final totalEarnings = _parseDouble(
      json['total_earnings'] ?? json['total'] ?? json['amount'],
    ) ?? 0;
    final deliveryFees = _parseDouble(
      json['delivery_fees'] ?? json['delivery_total'] ?? json['fees'],
    ) ?? 0;
    final tips = _parseDouble(json['tips'] ?? json['tip_total']) ?? 0;
    final bonuses = _parseDouble(json['bonuses'] ?? json['bonus_total']) ?? 0;

    final totalDeliveries = json['total_deliveries'] as int?
        ?? json['total_missions'] as int?
        ?? json['count'] as int?
        ?? 0;
    final completedDeliveries = json['completed_deliveries'] as int?
        ?? json['completed'] as int?
        ?? 0;
    final cancelledDeliveries = json['cancelled_deliveries'] as int?
        ?? json['cancelled'] as int?
        ?? 0;
    final averagePerDelivery = _parseDouble(
      json['average_per_delivery'] ?? json['average'],
    ) ?? (completedDeliveries > 0 ? totalEarnings / completedDeliveries : 0);

    final byPeriodRaw = json['by_period'] ?? json['series'] ?? json['breakdown'];
    final byPeriod = <EarningsPeriodPoint>[];
    if (byPeriodRaw is List) {
      for (final item in byPeriodRaw) {
        if (item is Map<String, dynamic>) {
          byPeriod.add(EarningsPeriodPoint.fromJson(item));
        }
      }
    }

    return EarningsSummary(
      totalEarnings: totalEarnings,
      deliveryFees: deliveryFees,
      tips: tips,
      bonuses: bonuses,
      totalDeliveries: totalDeliveries,
      completedDeliveries: completedDeliveries,
      cancelledDeliveries: cancelledDeliveries,
      averagePerDelivery: averagePerDelivery,
      period: json['period'] as String?,
      dateFrom: json['date_from'] as String? ?? json['from'] as String?,
      dateTo: json['date_to'] as String? ?? json['to'] as String?,
      byPeriod: byPeriod,
    );
  }
}

// ---------------------------------------------------------------------------
// Earnings Entry (historique)
// ---------------------------------------------------------------------------

/// Entree individuelle de gains (une livraison, un bonus, etc.).
class EarningsEntry {
  final int? id;
  final String? type;
  final double amount;
  final String? description;
  final String? reference;
  final String? status;
  final String? createdAt;
  final int? missionId;
  final int? orderId;

  const EarningsEntry({
    this.id,
    this.type,
    this.amount = 0,
    this.description,
    this.reference,
    this.status,
    this.createdAt,
    this.missionId,
    this.orderId,
  });

  /// Label lisible du type.
  String get typeLabel {
    switch (type) {
      case 'delivery':
      case 'delivery_fee':
        return 'Livraison';
      case 'tip':
        return 'Pourboire';
      case 'bonus':
        return 'Bonus';
      case 'penalty':
        return 'Penalite';
      case 'adjustment':
        return 'Ajustement';
      default:
        return type ?? 'Gain';
    }
  }

  /// Indique si c'est un credit (positif) ou un debit (negatif).
  bool get isCredit => amount >= 0;

  factory EarningsEntry.fromJson(Map<String, dynamic> json) {
    return EarningsEntry(
      id: json['id'] as int?,
      type: json['type'] as String? ?? json['entry_type'] as String?,
      amount: _parseDouble(json['amount'] ?? json['value']) ?? 0,
      description: json['description'] as String? ?? json['label'] as String?,
      reference: json['reference'] as String? ?? json['order_reference'] as String?,
      status: json['status'] as String?,
      createdAt: json['created_at'] as String? ?? json['date'] as String?,
      missionId: json['mission_id'] as int?,
      orderId: json['order_id'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
