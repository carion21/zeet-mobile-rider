// lib/screens/delivery_details/widgets/mission_logs_sheet.dart
//
// Bottom sheet affichant l'audit trail d'une mission.
// Endpoint : GET /v1/rider/missions/:id/logs
//
// Design :
// - Timeline verticale (dot + ligne + contenu)
// - ZeetSkeleton pour loading, ZeetEmptyState pour empty/error
// - Hauteur max 75% de l'ecran, drag handle en haut
// - Haptic sur ouverture

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:rider/models/mission_log_model.dart';
import 'package:rider/providers/mission_logs_provider.dart';

/// Affiche la bottom sheet des logs pour une mission donnee.
Future<void> showMissionLogsSheet(
  BuildContext context, {
  required String missionId,
}) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ZeetRadius.lg),
      ),
    ),
    builder: (ctx) => _MissionLogsSheet(missionId: missionId),
  );
}

class _MissionLogsSheet extends ConsumerWidget {
  const _MissionLogsSheet({required this.missionId});

  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final logsAsync = ref.watch(missionLogsProvider(missionId));

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Drag handle
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(ZeetRadius.pill),
                ),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 12.w, 12.h),
              child: Row(
                children: <Widget>[
                  Icon(Icons.history_rounded,
                      color: scheme.onSurface, size: 22),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Historique de la mission',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Rafraichir',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.invalidate(missionLogsProvider(missionId));
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outline),
            // Body
            Flexible(
              child: logsAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: ZeetEmptyState(
                        icon: Icons.inbox_rounded,
                        title: 'Aucun événement',
                        description:
                            'Aucune activité n\'a encore été enregistrée pour cette mission.',
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      final isLast = index == logs.length - 1;
                      return _TimelineTile(entry: entry, isLast: isLast);
                    },
                  );
                },
                loading: () => Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                  child: Column(
                    children: List<Widget>.generate(
                      4,
                      (i) => Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: const ZeetSkeleton(
                          height: 56,
                          borderRadius: ZeetRadius.brMd,
                        ),
                      ),
                    ),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: ZeetEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Erreur de chargement',
                    description:
                        'Impossible de récupérer l\'historique de cette mission.',
                    actionLabel: 'Réessayer',
                    onAction: () =>
                        ref.invalidate(missionLogsProvider(missionId)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry, required this.isLast});

  final MissionLogEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final date = entry.createdAt;
    final dateLabel = date != null
        ? DateFormat('dd MMM HH:mm:ss', 'fr_FR').format(date)
        : '';
    final subtitle = entry.displaySubtitle;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Colonne gauche : dot + ligne
          SizedBox(
            width: 24.w,
            child: Column(
              children: <Widget>[
                Container(
                  width: 12.w,
                  height: 12.w,
                  margin: EdgeInsets.only(top: 4.h),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 4.h),
                      color: scheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // Contenu
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.displayTitle,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (dateLabel.isNotEmpty) ...<Widget>[
                    SizedBox(height: 2.h),
                    Text(
                      dateLabel,
                      style: tt.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
