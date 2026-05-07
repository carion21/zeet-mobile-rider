// lib/models/mission_log_model.dart
//
// Modele pour l'endpoint GET /v1/rider/missions/:id/logs.
//
// Payload reel (zeet-core-system) :
//   {
//     "id": 3329,
//     "date_created": "...",
//     "observation": "Rider accepted mission",   // texte libre (EN)
//     "actor": 4,                                 // user.id (nullable)
//     "actor_type": "system" | "user" | "runner",
//     "source": "dispatch_engine" | null,
//     "metadata": { ... } | null,
//     "delivery_status": {                        // null sur evenements
//       "id": 3, "label": "Accepté",              // hors transition (ex.
//       "value": "accepted",                      // dispatch scoring)
//       "color": "#1E90FF"
//     } | null
//   }

import 'package:flutter/material.dart';

class MissionLogEntry {
  final int? id;
  final String? observation;
  final int? actorId;
  final String? actorType;
  final String? source;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;
  final MissionLogStatus? deliveryStatus;

  const MissionLogEntry({
    this.id,
    this.observation,
    this.actorId,
    this.actorType,
    this.source,
    this.createdAt,
    this.metadata,
    this.deliveryStatus,
  });

  /// Titre principal de la timeline. Priorite au libelle de transition
  /// de statut (lisible FR), fallback observation backend, sinon generique.
  String get displayTitle {
    final label = deliveryStatus?.label;
    if (label != null && label.isNotEmpty) return label;
    final obs = observation;
    if (obs != null && obs.isNotEmpty) return obs;
    return 'Événement';
  }

  /// Sous-titre : observation si elle n'a pas servi de titre, sinon
  /// origine de l'evenement (acteur / source).
  String? get displaySubtitle {
    final obs = observation;
    final hasStatusTitle = deliveryStatus?.label != null;
    if (hasStatusTitle && obs != null && obs.isNotEmpty) return obs;

    final parts = <String>[];
    final actor = _actorLabel();
    if (actor != null) parts.add(actor);
    final src = source;
    if (src != null && src.isNotEmpty) {
      parts.add(src.replaceAll('_', ' '));
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Couleur du dot timeline. Couleur API du statut quand dispo, sinon
  /// neutre (le tile applique le fallback `scheme.primary`).
  Color? get dotColor => deliveryStatus?.color;

  String? _actorLabel() {
    final type = actorType;
    if (type == null) return null;
    switch (type) {
      case 'system':
        return 'Système';
      case 'runner':
        return 'Dispatch';
      case 'user':
        return actorId != null ? 'Utilisateur #$actorId' : 'Utilisateur';
      default:
        return type;
    }
  }

  factory MissionLogEntry.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['delivery_status'];
    return MissionLogEntry(
      id: (json['id'] as num?)?.toInt(),
      observation: json['observation'] as String?,
      actorId: (json['actor'] as num?)?.toInt(),
      actorType: json['actor_type'] as String?,
      source: json['source'] as String?,
      createdAt: _parseDate(json['date_created']),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      deliveryStatus: rawStatus is Map<String, dynamic>
          ? MissionLogStatus.fromJson(rawStatus)
          : null,
    );
  }
}

class MissionLogStatus {
  final int? id;
  final String? label;
  final String? value;
  final Color? color;

  const MissionLogStatus({this.id, this.label, this.value, this.color});

  factory MissionLogStatus.fromJson(Map<String, dynamic> json) {
    return MissionLogStatus(
      id: (json['id'] as num?)?.toInt(),
      label: json['label'] as String?,
      value: json['value'] as String?,
      color: _parseHexColor(json['color'] as String?),
    );
  }
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var clean = hex.replaceFirst('#', '').trim();
  if (clean.length == 6) clean = 'FF$clean';
  if (clean.length != 8) return null;
  final value = int.tryParse(clean, radix: 16);
  return value == null ? null : Color(value);
}
