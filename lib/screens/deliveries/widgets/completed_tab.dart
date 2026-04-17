// lib/screens/deliveries/widgets/completed_tab.dart
//
// Contenu de l'onglet "Terminées" dans DeliveriesScreen.
// Remplace l'ancien filtre client-side sur `missionsListProvider` (qui ne
// remontait que les missions de la session courante) par un vrai historique
// paginé via GET /v1/rider/deliveries.
//
// Design aligné zeet_ui + POS ergonomics + 3-clics rule.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:rider/models/delivery_history_model.dart';
import 'package:rider/providers/delivery_history_provider.dart';
import 'package:rider/services/navigation_service.dart';

class CompletedDeliveriesTab extends ConsumerStatefulWidget {
  const CompletedDeliveriesTab({super.key});

  @override
  ConsumerState<CompletedDeliveriesTab> createState() =>
      _CompletedDeliveriesTabState();
}

class _CompletedDeliveriesTabState
    extends ConsumerState<CompletedDeliveriesTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(deliveryHistoryProvider);
      if (state.items.isEmpty && !state.isLoading) {
        ref.read(deliveryHistoryProvider.notifier).load();
      }
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
      ref.read(deliveryHistoryProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() =>
      ref.read(deliveryHistoryProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(deliveryHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    if (state.errorMessage != null && state.items.isEmpty) {
      return Center(
        child: ZeetEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Erreur de chargement',
          description: state.errorMessage!,
          actionLabel: 'Réessayer',
          onAction: () => ref.read(deliveryHistoryProvider.notifier).load(),
        ),
      );
    }

    if (state.isLoading && state.items.isEmpty) {
      return ListView.separated(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, _) => SizedBox(height: 8.h),
        itemBuilder: (_, _) => const ZeetSkeleton(
          height: 88,
          borderRadius: ZeetRadius.brMd,
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: ZeetEmptyState(
          icon: Icons.history_rounded,
          title: 'Aucune livraison terminée',
          description:
              'Vos livraisons finalisées apparaîtront ici, même après redémarrage de l\'app.',
          actionLabel: 'Ouvrir l\'historique complet',
          onAction: () => Routes.navigateTo(Routes.deliveriesHistory),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: scheme.primary,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => SizedBox(height: 8.h),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: state.isLoadingMore
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }
          final item = state.items[index];
          return _HistoryTile(
            item: item,
            onTap: () {
              HapticFeedback.lightImpact();
              Routes.pushMissionDetails(missionId: item.id.toString());
            },
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.onTap});

  final DeliveryHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = _statusFromItem(item);
    final date = item.dateCreated;
    final dateLabel =
        date != null ? DateFormat('dd MMM · HH:mm', 'fr_FR').format(date) : '';

    return ZeetCard(
      onTap: onTap,
      padding: EdgeInsets.all(16.w),
      semanticLabel:
          'Livraison ${item.displayCode}, ${item.statusLabel}, ${item.deliveryFee.toStringAsFixed(0)} francs',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 56.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.displayCode,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                ZeetStatusChip(
                  status: status,
                  label: item.statusLabel,
                  dense: true,
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              children: <Widget>[
                Icon(Icons.storefront_rounded,
                    size: 14.sp, color: scheme.onSurface),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    item.partnerName,
                    style: tt.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              children: <Widget>[
                Icon(Icons.place_rounded,
                    size: 14.sp, color: scheme.onSurfaceVariant),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    item.deliveryAddress ?? item.customerName,
                    style: tt.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  dateLabel,
                  style: tt.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                ZeetMoney(
                  amount: item.deliveryFee,
                  currency: ZeetCurrency.fcfa,
                  style: tt.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ZeetStatus _statusFromItem(DeliveryHistoryItem item) {
    if (item.isDelivered) return ZeetStatus.success;
    if (item.isFailed) return ZeetStatus.danger;
    return ZeetStatus.neutral;
  }
}
