/// Action utilisateur en attente de synchronisation serveur.
///
/// Persistée localement (SharedPreferences) pour survivre au kill de l'app.
/// Le worker [OfflineQueueService] itère les actions `pending` et les
/// rejoue dès que le réseau redevient disponible.
///
/// Skill `zeet-offline-first` §5 (Sync Queue) :
/// - FIFO par défaut.
/// - Retry avec backoff exponentiel (1, 2, 4, 8, 16, 30, 60s — cap 60s).
/// - Dead letter après 10 échecs consécutifs (status `failed`).
library;

/// Type d'action queueable côté rider.
///
/// Limité aux actions critiques métier (acceptation/refus/livraison) qui
/// doivent **toujours** aboutir, même si le rider est temporairement hors
/// ligne (parking sous-sol, tunnel, etc.).
enum QueuedActionType {
  acceptMission,
  rejectMission,
  collectMission,
  deliverMission,
  markNotDelivered,
}

/// Statut interne d'une action dans la queue.
enum QueuedActionStatus {
  /// Pas encore tentée OU à retenter (backoff écoulé).
  pending,

  /// Le worker la traite actuellement (lock anti race-condition).
  syncing,

  /// Dépassé le nombre max de tentatives → l'utilisateur doit choisir
  /// (rejouer manuellement ou abandonner).
  failed,
}

/// Une action en attente de sync.
class QueuedAction {
  /// Identifiant unique (timestamp µs + sequence).
  final String id;

  /// Type d'action métier.
  final QueuedActionType type;

  /// Identifiant de la mission concernée (string pour transport API).
  final String missionId;

  /// Paramètres additionnels (otp_code, reason, geo_lat, geo_lng…).
  final Map<String, dynamic> payload;

  /// Quand l'utilisateur a déclenché l'action.
  final DateTime enqueuedAt;

  /// Nombre de tentatives effectuées (0 si jamais tentée).
  final int attempts;

  /// Timestamp de la dernière tentative (utile pour calculer le backoff).
  final DateTime? lastAttemptAt;

  /// Message d'erreur de la dernière tentative (humain ou code API).
  final String? lastError;

  /// Statut courant.
  final QueuedActionStatus status;

  const QueuedAction({
    required this.id,
    required this.type,
    required this.missionId,
    this.payload = const <String, dynamic>{},
    required this.enqueuedAt,
    this.attempts = 0,
    this.lastAttemptAt,
    this.lastError,
    this.status = QueuedActionStatus.pending,
  });

  QueuedAction copyWith({
    String? id,
    QueuedActionType? type,
    String? missionId,
    Map<String, dynamic>? payload,
    DateTime? enqueuedAt,
    int? attempts,
    DateTime? lastAttemptAt,
    String? lastError,
    QueuedActionStatus? status,
    bool clearLastError = false,
  }) {
    return QueuedAction(
      id: id ?? this.id,
      type: type ?? this.type,
      missionId: missionId ?? this.missionId,
      payload: payload ?? this.payload,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'missionId': missionId,
      'payload': payload,
      'enqueuedAt': enqueuedAt.toIso8601String(),
      'attempts': attempts,
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'lastError': lastError,
      'status': status.name,
    };
  }

  factory QueuedAction.fromJson(Map<String, dynamic> json) {
    return QueuedAction(
      id: json['id'] as String,
      type: QueuedActionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => QueuedActionType.acceptMission,
      ),
      missionId: json['missionId'] as String,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastAttemptAt: json['lastAttemptAt'] == null
          ? null
          : DateTime.parse(json['lastAttemptAt'] as String),
      lastError: json['lastError'] as String?,
      status: QueuedActionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => QueuedActionStatus.pending,
      ),
    );
  }

  /// Libellé court humain pour l'écran "Actions en attente".
  /// Skill `zeet-micro-copy` (rider direct).
  String get humanLabel {
    switch (type) {
      case QueuedActionType.acceptMission:
        return 'Accepter mission #$missionId';
      case QueuedActionType.rejectMission:
        return 'Refuser mission #$missionId';
      case QueuedActionType.collectMission:
        return 'Marquer récupérée #$missionId';
      case QueuedActionType.deliverMission:
        return 'Marquer livrée #$missionId';
      case QueuedActionType.markNotDelivered:
        return 'Signaler échec #$missionId';
    }
  }

  /// Statut local optimiste à appliquer immédiatement à la mission cible
  /// (avant que le serveur confirme). `null` si l'action ne change pas
  /// directement le statut visible.
  String? get optimisticStatus {
    switch (type) {
      case QueuedActionType.acceptMission:
        return 'accepted';
      case QueuedActionType.rejectMission:
        return 'rejected';
      case QueuedActionType.collectMission:
        return 'collected';
      case QueuedActionType.deliverMission:
        return 'delivered';
      case QueuedActionType.markNotDelivered:
        return 'not-delivered';
    }
  }
}
