// lib/providers/mission_logs_provider.dart
//
// Provider pour l'audit trail d'une mission (GET /v1/rider/missions/:id/logs).
// Implemente avec FutureProvider.family pour avoir un cache par missionId
// et un rafraichissement simple via `ref.invalidate`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rider/models/mission_log_model.dart';
import 'package:rider/providers/mission_provider.dart';

/// Recupere la liste des logs d'une mission.
/// Utilisation :
/// ```dart
/// final logsAsync = ref.watch(missionLogsProvider(missionId));
/// ```
final missionLogsProvider =
    FutureProvider.family<List<MissionLogEntry>, String>((ref, missionId) {
  final service = ref.watch(missionServiceProvider);
  return service.getMissionLogs(missionId);
});
