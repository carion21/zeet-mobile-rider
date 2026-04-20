// lib/screens/offline_queue/index.dart
//
// Écran "Actions en attente" — visualisation et gestion par l'utilisateur
// de la file d'actions non encore synchronisées avec le serveur.
//
// Skill `zeet-offline-first` §9 (queue visible et gérable).
// Skill `zeet-pos-ergonomics` (densité, hit targets ≥56pt).
// Skill `zeet-micro-copy` (tone rider direct).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:rider/core/constants/colors.dart';
import 'package:rider/models/queued_action.dart';
import 'package:rider/providers/offline_queue_provider.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class OfflineQueueScreen extends ConsumerWidget {
  const OfflineQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<QueuedAction> actions =
        ref.watch(offlineQueueProvider).maybeWhen(
              data: (v) => v,
              orElse: () => const <QueuedAction>[],
            );
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final Color textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final Color backgroundColor =
        isDarkMode ? AppColors.darkBackground : const Color(0xFFF8F8F8);
    final Color surfaceColor =
        isDarkMode ? AppColors.darkSurface : Colors.white;

    final int failedCount = actions
        .where((QueuedAction a) => a.status == QueuedActionStatus.failed)
        .length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Routes.goBack(),
        ),
        title: Text(
          'Actions en attente',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (failedCount > 0)
            IconButton(
              tooltip: 'Vider les échecs',
              icon: Icon(Icons.delete_sweep_rounded, color: textColor),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await ref
                    .read(offlineQueueServiceProvider)
                    .clearFailed();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await ref.read(offlineQueueServiceProvider).sync();
        },
        child: actions.isEmpty
            ? _buildEmpty(textColor, textLightColor)
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 96.h),
                itemCount: actions.length,
                itemBuilder: (context, index) => _ActionTile(
                  action: actions[index],
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  textLightColor: textLightColor,
                  isDarkMode: isDarkMode,
                  onRemove: () async {
                    HapticFeedback.selectionClick();
                    await ref
                        .read(offlineQueueServiceProvider)
                        .remove(actions[index].id);
                  },
                ),
              ),
      ),
      bottomNavigationBar: failedCount > 0
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: ZeetButton.primary(
                  label: 'Réessayer ($failedCount)',
                  fullWidth: true,
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final svc = ref.read(offlineQueueServiceProvider);
                    await svc.retryFailed();
                    await svc.sync();
                  },
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmpty(Color textColor, Color textLightColor) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 0.2.sh),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 64,
                  color: textLightColor,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Tout est à jour',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  "Aucune action en attente. Tes livraisons sont synchronisées.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textLightColor, fontSize: 13.sp),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.surfaceColor,
    required this.textColor,
    required this.textLightColor,
    required this.isDarkMode,
    required this.onRemove,
  });

  final QueuedAction action;
  final Color surfaceColor;
  final Color textColor;
  final Color textLightColor;
  final bool isDarkMode;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final (Color statusColor, IconData statusIcon, String statusLabel) =
        _resolveStatus(action.status);
    final String enqueuedRel = _relativeTime(action.enqueuedAt);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.humanLabel,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '$statusLabel · $enqueuedRel',
                      style:
                          TextStyle(color: textLightColor, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              if (action.status == QueuedActionStatus.failed)
                IconButton(
                  tooltip: 'Retirer',
                  icon: Icon(Icons.close_rounded, color: textLightColor),
                  onPressed: onRemove,
                ),
            ],
          ),
          if (action.lastError != null) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                action.lastError!,
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ],
          if (action.attempts > 0) ...[
            SizedBox(height: 6.h),
            Text(
              '${action.attempts} tentative${action.attempts > 1 ? 's' : ''}',
              style: TextStyle(color: textLightColor, fontSize: 11.sp),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData, String) _resolveStatus(QueuedActionStatus s) {
    switch (s) {
      case QueuedActionStatus.pending:
        return (AppColors.primary, Icons.schedule_rounded, 'En attente');
      case QueuedActionStatus.syncing:
        return (Colors.blueAccent, Icons.sync_rounded, 'Synchronisation…');
      case QueuedActionStatus.failed:
        return (AppColors.error, Icons.error_outline_rounded, 'Échec');
    }
  }

  String _relativeTime(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return DateFormat('d MMM HH:mm', 'fr_FR').format(dt);
  }
}
