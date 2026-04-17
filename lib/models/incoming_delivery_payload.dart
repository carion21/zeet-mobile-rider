// Modele de payload "nouvelle livraison" recue via push (FCM).
//
// Contrat d'interface fourni par le backend :
//
//   {
//     "user_id": 42,
//     "type_value": "delivery.offer",
//     "title": "Nouvelle livraison ZTD-2026-00421",
//     "body": "Cocody Riviera — 2.4 km",
//     "surface": "rider",
//     "entity": "delivery",
//     "entity_id": 421,
//     "notification_id": "1843",           // ajoute par le wrapper notifs
//     "metadata": "{\"type\":\"delivery.offer\",\"delivery_id\":421,\"delivery_code\":\"ZTD-2026-00421\",\"order_id\":812,\"order_code\":\"ZT-2026-00812\",\"pickup_address\":\"Cocody Riviera 2, restaurant X\",\"dropoff_address\":\"Marcory Zone 4\",\"distance_km\":2.4,\"eta_minutes\":12,\"delivery_fee_fcfa\":1500,\"accept_deadline\":\"2026-04-15T16:05:30.000Z\",\"requires_ack\":true}"
//   }
//
// Le champ `metadata` arrive en JSON encode sous forme de String (format
// standard FCM : les valeurs dans `data` sont toujours des strings). Le parser
// est defensif pour absorber les variantes possibles (types laxes, cles absentes).
//
// Le champ `accept_deadline` (ISO8601) pilote le compte a rebours cote UI :
// le rider est typiquement sur son velo, le tel sous les yeux, la deadline
// fait sens contrairement au partner en cuisine.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Payload typee d'une notification "delivery.offer".
@immutable
class IncomingDeliveryPayload {
  /// Type de l'evenement (ex: "delivery.offer").
  final String type;

  /// Id de la notification backend (pour l'ack).
  final int notificationId;

  /// Id de la delivery / mission (utilise pour /missions/:id/accept).
  final int deliveryId;

  /// Code lisible de la delivery (ex: "ZTD-2026-00421").
  final String deliveryCode;

  /// Id de la commande associee (pour afficher / lier).
  final int? orderId;

  /// Code de la commande associee.
  final String orderCode;

  /// Titre pre-formate par le backend.
  final String title;

  /// Corps pre-formate par le backend.
  final String body;

  /// Adresse de ramassage (restaurant / partner).
  final String pickupAddress;

  /// Adresse de livraison (client).
  final String dropoffAddress;

  /// Distance totale de la mission en kilometres.
  final double distanceKm;

  /// ETA estime en minutes.
  final int etaMinutes;

  /// Montant de la course payee au rider (FCFA, pas de decimales XOF).
  final int deliveryFeeFcfa;

  /// Deadline d'acceptation (UTC). Au-dela, la mission est re-assignee
  /// automatiquement cote backend et l'app auto-refuse.
  final DateTime? acceptDeadline;

  /// Si true, l'app DOIT appeler /notifications/:id/ack apres acceptation
  /// pour couper la cascade backend.
  final bool requiresAck;

  const IncomingDeliveryPayload({
    required this.type,
    required this.notificationId,
    required this.deliveryId,
    required this.deliveryCode,
    required this.orderCode,
    required this.title,
    required this.body,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distanceKm,
    required this.etaMinutes,
    required this.deliveryFeeFcfa,
    this.orderId,
    this.acceptDeadline,
    this.requiresAck = true,
  });

  /// Secondes restantes avant expiration du deadline. 0 si absent ou passe.
  int get secondsUntilDeadline {
    final deadline = acceptDeadline;
    if (deadline == null) return 0;
    final diff = deadline.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  /// Parse un payload FCM brut (map reconstruite depuis RemoteMessage.data).
  static IncomingDeliveryPayload? tryParse(Map<String, dynamic> raw) {
    final metadata = _extractMetadata(raw);

    // L'id cible est cherche dans metadata en priorite (delivery_id), puis
    // au top-level (entity_id). `entity_id` est redondant avec delivery_id.
    final deliveryId = _asInt(
      metadata['delivery_id'] ?? raw['entity_id'] ?? raw['delivery_id'],
    );
    if (deliveryId == null) return null;

    // `type_value` est le nom officiel du champ top-level, `type` est un alias.
    final type = _asString(raw['type_value']) ??
        _asString(raw['type']) ??
        _asString(metadata['type']) ??
        'delivery.offer';

    final notificationId =
        _asInt(raw['notification_id'] ?? metadata['notification_id']) ?? 0;

    final deliveryCode = _asString(metadata['delivery_code']) ??
        _asString(raw['delivery_code']) ??
        _extractCodeFromTitle(raw['title']) ??
        '';

    final orderId = _asInt(metadata['order_id'] ?? raw['order_id']);
    final orderCode = _asString(metadata['order_code']) ??
        _asString(raw['order_code']) ??
        '';

    final pickupAddress = _asString(metadata['pickup_address']) ??
        _asString(raw['pickup_address']) ??
        '';
    final dropoffAddress = _asString(metadata['dropoff_address']) ??
        _asString(raw['dropoff_address']) ??
        '';

    final distanceKm = _asDouble(
          metadata['distance_km'] ?? raw['distance_km'],
        ) ??
        0.0;

    final etaMinutes = _asInt(
          metadata['eta_minutes'] ?? raw['eta_minutes'],
        ) ??
        0;

    final deliveryFeeFcfa = _asInt(
          metadata['delivery_fee_fcfa'] ??
              metadata['rider_fee_fcfa'] ??
              raw['delivery_fee_fcfa'],
        ) ??
        0;

    final acceptDeadline = _asDateTime(
      metadata['accept_deadline'] ?? raw['accept_deadline'],
    );

    final requiresAck = _asBool(
      metadata['requires_ack'] ?? raw['requires_ack'],
      fallback: true,
    );

    return IncomingDeliveryPayload(
      type: type,
      notificationId: notificationId,
      deliveryId: deliveryId,
      deliveryCode: deliveryCode,
      orderId: orderId,
      orderCode: orderCode,
      title: _asString(raw['title']) ?? 'Nouvelle livraison',
      body: _asString(raw['body']) ?? '',
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      distanceKm: distanceKm,
      etaMinutes: etaMinutes,
      deliveryFeeFcfa: deliveryFeeFcfa,
      acceptDeadline: acceptDeadline,
      requiresAck: requiresAck,
    );
  }

  // ---------------------------------------------------------------------------
  // Parsing utilitaires
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _extractMetadata(Map<String, dynamic> raw) {
    final meta = raw['metadata'];
    if (meta is Map<String, dynamic>) return meta;
    if (meta is Map) return Map<String, dynamic>.from(meta);
    if (meta is String && meta.isNotEmpty) {
      try {
        final decoded = jsonDecode(meta);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        // metadata malforme — fallback sur champs top-level
      }
    }
    return const {};
  }

  static int? _asInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static double? _asDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static String? _asString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.isEmpty ? null : raw;
    return raw.toString();
  }

  static bool _asBool(dynamic raw, {bool fallback = false}) {
    if (raw == null) return fallback;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return fallback;
  }

  static DateTime? _asDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }

  static String? _extractCodeFromTitle(dynamic title) {
    if (title is! String) return null;
    final match = RegExp(r'([A-Z]{2,4}-\d{4}-\d+)').firstMatch(title);
    return match?.group(1);
  }

  /// Utilitaire pour creer un payload de test (dev trigger).
  factory IncomingDeliveryPayload.fake({
    int deliveryId = 421,
    String deliveryCode = 'ZTD-2026-00421',
    int deliveryFeeFcfa = 1500,
    double distanceKm = 2.4,
    int etaMinutes = 12,
    int notificationId = 1843,
    Duration deadlineIn = const Duration(seconds: 30),
  }) {
    return IncomingDeliveryPayload(
      type: 'delivery.offer',
      notificationId: notificationId,
      deliveryId: deliveryId,
      deliveryCode: deliveryCode,
      orderId: 812,
      orderCode: 'ZT-2026-00812',
      title: 'Nouvelle livraison $deliveryCode',
      body: 'Cocody Riviera 2 — ${distanceKm.toStringAsFixed(1)} km',
      pickupAddress: 'Chez Samuel — Cocody Riviera 2, Abidjan',
      dropoffAddress: 'Marcory Zone 4, Rue du Canal',
      distanceKm: distanceKm,
      etaMinutes: etaMinutes,
      deliveryFeeFcfa: deliveryFeeFcfa,
      acceptDeadline: DateTime.now().add(deadlineIn),
      requiresAck: true,
    );
  }

  @override
  String toString() =>
      'IncomingDeliveryPayload(delivery=$deliveryCode #$deliveryId, '
      'fee=$deliveryFeeFcfa FCFA, dist=$distanceKm km, eta=${etaMinutes}min, '
      'deadline=$acceptDeadline, ack=$requiresAck)';
}
