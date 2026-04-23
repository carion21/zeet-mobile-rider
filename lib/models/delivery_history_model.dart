// lib/models/delivery_history_model.dart
//
// Modeles lies a l'endpoint GET /v1/rider/deliveries (historique complet
// paginé des livraisons du rider, distinct des missions actives).
//
// Schema de reference : api-reference.json > rider.deliveries.list.
// Parsing defensif : tout est nullable sauf `id`.

import 'package:flutter/material.dart';
import 'package:rider/core/utils/hex_color.dart' as hex;

/// Pagination standard ZEET.
class DeliveryHistoryMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const DeliveryHistoryMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  bool get hasNextPage => page < totalPages;

  factory DeliveryHistoryMeta.fromJson(Map<String, dynamic> json) {
    return DeliveryHistoryMeta(
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 25,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Statut d'une livraison historique (label + value + color backend).
class DeliveryHistoryStatus {
  final int? id;
  final String? label;
  final String? value;
  final String? colorHex;

  const DeliveryHistoryStatus({
    this.id,
    this.label,
    this.value,
    this.colorHex,
  });

  /// Couleur resolue depuis `colorHex` (null si non fournie / invalide).
  Color? get color => hex.hexToColor(colorHex);

  factory DeliveryHistoryStatus.fromJson(Map<String, dynamic> json) {
    return DeliveryHistoryStatus(
      id: (json['id'] as num?)?.toInt(),
      label: json['label'] as String?,
      value: json['value'] as String?,
      colorHex: json['color'] as String?,
    );
  }

  /// Vrai si la livraison est consideree comme reussie.
  bool get isDelivered => value == 'delivered';

  /// Vrai si la livraison a echoue ou ete annulee.
  bool get isFailed =>
      value == 'not-delivered' ||
      value == 'not_delivered' ||
      value == 'cancelled' ||
      value == 'canceled' ||
      value == 'failed';
}

/// Partenaire (restaurant) lie a une livraison historique.
class DeliveryHistoryPartner {
  final int? id;
  final String? name;
  final String? phone;
  final String? picture;
  final String? address;
  final double? latitude;
  final double? longitude;

  const DeliveryHistoryPartner({
    this.id,
    this.name,
    this.phone,
    this.picture,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory DeliveryHistoryPartner.fromJson(Map<String, dynamic> json) {
    return DeliveryHistoryPartner(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      picture: json['picture'] as String?,
      address: json['address'] as String?,
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
    );
  }
}

/// Client lie a une livraison historique.
class DeliveryHistoryCustomer {
  final int? id;
  final String? firstname;
  final String? lastname;
  final String? phone;

  const DeliveryHistoryCustomer({
    this.id,
    this.firstname,
    this.lastname,
    this.phone,
  });

  String get fullName {
    final parts = <String>[
      if (firstname != null && firstname!.isNotEmpty) firstname!,
      if (lastname != null && lastname!.isNotEmpty) lastname!,
    ];
    return parts.isNotEmpty ? parts.join(' ') : 'Client';
  }

  factory DeliveryHistoryCustomer.fromJson(Map<String, dynamic> json) {
    return DeliveryHistoryCustomer(
      id: (json['id'] as num?)?.toInt(),
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

/// Commande liee a une livraison historique (payload leger).
class DeliveryHistoryOrder {
  final int? id;
  final String? code;
  final double? totalAmount;
  final double? deliveryFee;
  final String? noteCustomer;
  final DeliveryHistoryStatus? lastOrderStatus;
  final DeliveryHistoryCustomer? customer;
  final DeliveryHistoryPartner? partner;

  const DeliveryHistoryOrder({
    this.id,
    this.code,
    this.totalAmount,
    this.deliveryFee,
    this.noteCustomer,
    this.lastOrderStatus,
    this.customer,
    this.partner,
  });

  factory DeliveryHistoryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryHistoryOrder(
      id: (json['id'] as num?)?.toInt(),
      code: json['code'] as String?,
      totalAmount: _asDouble(json['total_amount']),
      deliveryFee: _asDouble(json['delivery_fee']),
      noteCustomer: json['note_customer'] as String?,
      lastOrderStatus: json['last_order_status'] is Map<String, dynamic>
          ? DeliveryHistoryStatus.fromJson(
              json['last_order_status'] as Map<String, dynamic>)
          : null,
      customer: json['customer'] is Map<String, dynamic>
          ? DeliveryHistoryCustomer.fromJson(
              json['customer'] as Map<String, dynamic>)
          : null,
      partner: json['partner'] is Map<String, dynamic>
          ? DeliveryHistoryPartner.fromJson(
              json['partner'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Item d'historique de livraison (ligne dans la liste paginee).
class DeliveryHistoryItem {
  final int id;
  final String? code;
  final String? uuid;
  final DateTime? dateCreated;
  final DateTime? dateUpdated;
  final DateTime? lastDispatchedAt;
  final int? delivererId;
  final DeliveryHistoryStatus? lastDeliveryStatus;
  final DeliveryHistoryOrder? order;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;

  const DeliveryHistoryItem({
    required this.id,
    this.code,
    this.uuid,
    this.dateCreated,
    this.dateUpdated,
    this.lastDispatchedAt,
    this.delivererId,
    this.lastDeliveryStatus,
    this.order,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
  });

  /// Raccourcis pratiques pour l'UI.
  String get displayCode => code ?? '#$id';
  String get customerName => order?.customer?.fullName ?? 'Client';
  String get partnerName => order?.partner?.name ?? 'Restaurant';
  double get deliveryFee =>
      order?.deliveryFee ?? 0;
  double get totalAmount => order?.totalAmount ?? 0;
  bool get isDelivered => lastDeliveryStatus?.isDelivered ?? false;
  bool get isFailed => lastDeliveryStatus?.isFailed ?? false;
  String get statusLabel => lastDeliveryStatus?.label ?? 'Inconnu';
  String? get statusValue => lastDeliveryStatus?.value;

  factory DeliveryHistoryItem.fromJson(Map<String, dynamic> json) {
    return DeliveryHistoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String?,
      uuid: json['uuid'] as String?,
      dateCreated: _parseDate(json['date_created']),
      dateUpdated: _parseDate(json['date_updated']),
      lastDispatchedAt: _parseDate(json['last_dispatched_at']),
      delivererId: (json['deliverer'] as num?)?.toInt(),
      lastDeliveryStatus: json['last_delivery_status'] is Map<String, dynamic>
          ? DeliveryHistoryStatus.fromJson(
              json['last_delivery_status'] as Map<String, dynamic>)
          : null,
      order: json['order'] is Map<String, dynamic>
          ? DeliveryHistoryOrder.fromJson(
              json['order'] as Map<String, dynamic>)
          : null,
      deliveryAddress: json['delivery_address'] as String?,
      deliveryLat: _asDouble(json['delivery_lat']),
      deliveryLng: _asDouble(json['delivery_lng']),
    );
  }
}

/// Page d'historique (items + meta).
class DeliveryHistoryPage {
  final List<DeliveryHistoryItem> data;
  final DeliveryHistoryMeta meta;

  const DeliveryHistoryPage({required this.data, required this.meta});
}

/// Filtre logique cote UI (map vers les values backend).
enum DeliveryHistoryFilter { all, delivered, failed }

extension DeliveryHistoryFilterX on DeliveryHistoryFilter {
  String? get apiStatus {
    switch (this) {
      case DeliveryHistoryFilter.all:
        return null;
      case DeliveryHistoryFilter.delivered:
        return 'delivered';
      case DeliveryHistoryFilter.failed:
        return 'not-delivered';
    }
  }

  String get label {
    switch (this) {
      case DeliveryHistoryFilter.all:
        return 'Toutes';
      case DeliveryHistoryFilter.delivered:
        return 'Livrées';
      case DeliveryHistoryFilter.failed:
        return 'Échouées';
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers prives
// ---------------------------------------------------------------------------

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
