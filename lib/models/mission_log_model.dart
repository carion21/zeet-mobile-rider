// lib/models/mission_log_model.dart
//
// Modele pour l'endpoint GET /v1/rider/missions/:id/logs (audit trail
// d'une mission : transitions de statut, acteurs, horodatage).
//
// Parsing tres defensif : le backend peut exposer le champ sous differents
// noms selon les versions (`event`, `action`, `status`, `type`).

class MissionLogEntry {
  final int? id;
  final String? event;
  final String? description;
  final String? actor;
  final String? fromStatus;
  final String? toStatus;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  const MissionLogEntry({
    this.id,
    this.event,
    this.description,
    this.actor,
    this.fromStatus,
    this.toStatus,
    this.createdAt,
    this.metadata,
  });

  /// Titre affichable dans la timeline.
  String get displayTitle {
    if (description != null && description!.isNotEmpty) return description!;
    if (event != null && event!.isNotEmpty) return event!;
    if (toStatus != null && toStatus!.isNotEmpty) {
      return 'Statut : $toStatus';
    }
    return 'Événement';
  }

  /// Sous-titre (acteur + transition) si disponible.
  String? get displaySubtitle {
    final parts = <String>[];
    if (actor != null && actor!.isNotEmpty) parts.add(actor!);
    if (fromStatus != null && toStatus != null) {
      parts.add('$fromStatus → $toStatus');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  factory MissionLogEntry.fromJson(Map<String, dynamic> json) {
    return MissionLogEntry(
      id: (json['id'] as num?)?.toInt(),
      event: (json['event'] ??
              json['action'] ??
              json['type'] ??
              json['name']) as String?,
      description: (json['description'] ??
              json['message'] ??
              json['label']) as String?,
      actor: (json['actor'] ??
              json['author'] ??
              json['by'] ??
              json['source']) as String?,
      fromStatus: (json['from_status'] ?? json['previous_status']) as String?,
      toStatus:
          (json['to_status'] ?? json['new_status'] ?? json['status']) as String?,
      createdAt: _parseDate(json['date_created'] ??
          json['created_at'] ??
          json['occurred_at'] ??
          json['timestamp']),
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
