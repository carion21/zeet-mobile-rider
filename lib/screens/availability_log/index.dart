// lib/screens/availability_log/index.dart
//
// Historique des bascules online/offline du rider.
// Endpoint : GET /v1/rider/availability-log
//
// Design :
// - Timeline dense : dot vert (online) / rouge (offline) + label + durée
// - Skeleton pour loading, ZeetEmptyState sinon
// - Scroll infini paginé
// - Accessible via profile > "Historique disponibilité"

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:rider/core/widgets/freshness/zeet_freshness_chip.dart';
import 'package:rider/models/availability_log_model.dart';
import 'package:rider/providers/availability_log_provider.dart';
import 'package:rider/services/navigation_service.dart';

class AvailabilityLogScreen extends ConsumerStatefulWidget {
  const AvailabilityLogScreen({super.key});

  @override
  ConsumerState<AvailabilityLogScreen> createState() =>
      _AvailabilityLogScreenState();
}

class _AvailabilityLogScreenState
    extends ConsumerState<AvailabilityLogScreen> {
  final ScrollController _scrollController = ScrollController();

  // Clé pour notifier la chip freshness d'un refresh externe
  // (pull-to-refresh, refresh button, retry).
  final GlobalKey<ZeetFreshnessChipLocalState> _freshKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(availabilityLogProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(availabilityLogProvider.notifier).loadMore();
    }
  }

  Future<void> _refreshAll() async {
    await ref.read(availabilityLogProvider.notifier).refresh();
    _freshKey.currentState?.bump();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(availabilityLogProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: const Text('Historique disponibilité'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () {
            HapticFeedback.lightImpact();
            Routes.goBack();
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraichir',
            onPressed: state.isLoading
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _refreshAll();
                  },
          ),
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: Center(
              child: ZeetFreshnessChipLocal(
                key: _freshKey,
                onRefresh: _refreshAll,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(AvailabilityLogState state) {
    if (state.errorMessage != null && state.entries.isEmpty) {
      return Center(
        child: ZeetEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Erreur de chargement',
          description: state.errorMessage!,
          actionLabel: 'Réessayer',
          onAction: _refreshAll,
        ),
      );
    }
    if (state.isLoading && state.entries.isEmpty) {
      return _buildSkeleton();
    }
    if (state.isEmpty) {
      return const Center(
        child: ZeetEmptyState(
          icon: Icons.schedule_rounded,
          title: 'Aucun historique',
          description:
              'Votre activité en ligne sera enregistrée ici dès vos prochaines sessions.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: Theme.of(context).colorScheme.primary,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.entries.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => SizedBox(height: 8.h),
        itemBuilder: (context, index) {
          if (index >= state.entries.length) {
            return _buildLoadMoreIndicator(state.isLoadingMore);
          }
          return _AvailabilityTile(entry: state.entries[index]);
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, _) => SizedBox(height: 8.h),
      itemBuilder: (_, _) => const ZeetSkeleton(
        height: 72,
        borderRadius: ZeetRadius.brMd,
      ),
    );
  }

  Widget _buildLoadMoreIndicator(bool loading) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: loading
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _AvailabilityTile extends StatelessWidget {
  const _AvailabilityTile({required this.entry});

  final AvailabilityLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final status = entry.isOnline ? ZeetStatus.success : ZeetStatus.neutral;
    final dateLabel = entry.fromAt != null
        ? DateFormat('dd MMM · HH:mm', 'fr_FR').format(entry.fromAt!)
        : '--';
    final endLabel = entry.toAt != null
        ? DateFormat('HH:mm', 'fr_FR').format(entry.toAt!)
        : null;

    return ZeetCard(
      padding: EdgeInsets.all(16.w),
      semanticLabel:
          '${entry.statusLabel} du $dateLabel, durée ${entry.displayDuration}',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 56.h),
        child: Row(
          children: <Widget>[
            // Icone de statut
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: entry.isOnline
                    ? scheme.primary.withValues(alpha: 0.12)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(ZeetRadius.md),
              ),
              child: Icon(
                entry.isOnline
                    ? Icons.power_rounded
                    : Icons.power_off_rounded,
                color: entry.isOnline ? scheme.primary : scheme.onSurfaceVariant,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 12.w),
            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          entry.statusLabel,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ZeetStatusChip(
                        status: status,
                        label: entry.displayDuration,
                        dense: true,
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    endLabel != null
                        ? '$dateLabel → $endLabel'
                        : dateLabel,
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
