// lib/screens/deliveries_history/index.dart
//
// Historique complet des livraisons du rider.
// Endpoint: GET /v1/rider/deliveries (paginé, filtrable).
//
// Direction artistique (zeet-design-system + zeet-pos-ergonomics) :
// - Liste dense, glanceability statut = couleur + icône + label
// - Hit target lignes ≥ 64pt
// - Filtres en chips (Toutes / Livrées / Échouées)
// - Skeleton pour loading, ZeetEmptyState pour empty
// - Haptic feedback sur filtre + tap
// - Scroll infini paginé (loadMore quand proche du bas)
// - CTA primaire : aucun (écran purement consultation)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:rider/models/delivery_history_model.dart';
import 'package:rider/providers/delivery_history_provider.dart';
import 'package:rider/services/navigation_service.dart';

class DeliveriesHistoryScreen extends ConsumerStatefulWidget {
  const DeliveriesHistoryScreen({super.key});

  @override
  ConsumerState<DeliveriesHistoryScreen> createState() =>
      _DeliveriesHistoryScreenState();
}

class _DeliveriesHistoryScreenState
    extends ConsumerState<DeliveriesHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deliveryHistoryProvider.notifier).load();
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
    // Declenche loadMore quand on atteint 80% du scroll.
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(deliveryHistoryProvider.notifier).loadMore();
    }
  }

  void _onFilterTap(DeliveryHistoryFilter filter) {
    HapticFeedback.selectionClick();
    ref.read(deliveryHistoryProvider.notifier).setFilter(filter);
  }

  Future<void> _onRefresh() async {
    await ref.read(deliveryHistoryProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: ZeetAppBar(
        title: const Text('Historique des livraisons'),
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
                    ref.read(deliveryHistoryProvider.notifier).refresh();
                  },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _buildFilterRow(state.filter),
            if (state.errorMessage != null && state.items.isEmpty)
              Expanded(child: _buildErrorState(state.errorMessage!))
            else if (state.isLoading && state.items.isEmpty)
              Expanded(child: _buildSkeletonList())
            else if (state.isEmpty)
              Expanded(child: _buildEmptyState())
            else
              Expanded(
                child: RefreshIndicator(
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
                        return _buildLoadMoreIndicator(state.isLoadingMore);
                      }
                      final item = state.items[index];
                      return _DeliveryHistoryTile(
                        item: item,
                        onTap: () => _openMissionIfPossible(item),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openMissionIfPossible(DeliveryHistoryItem item) {
    HapticFeedback.lightImpact();
    // L'historique peut inclure des livraisons qui ne sont plus des missions
    // actives cote backend. On tente tout de meme la navigation vers le
    // detail : si le backend renvoie 404 la MissionDetailScreen gere
    // deja l'etat d'erreur.
    Routes.pushMissionDetails(missionId: item.id.toString());
  }

  Widget _buildFilterRow(DeliveryHistoryFilter current) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      child: Row(
        children: <Widget>[
          for (final filter in DeliveryHistoryFilter.values) ...<Widget>[
            _FilterChip(
              label: filter.label,
              selected: current == filter,
              onTap: () => _onFilterTap(filter),
            ),
            if (filter != DeliveryHistoryFilter.values.last)
              SizedBox(width: 8.w),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, _) => SizedBox(height: 8.h),
      itemBuilder: (_, _) => const ZeetSkeleton(
        height: 88,
        borderRadius: ZeetRadius.brMd,
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: ZeetEmptyState(
        icon: Icons.history_rounded,
        title: 'Aucune livraison',
        description:
            'Votre historique apparaîtra ici après votre première course.',
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: ZeetEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Erreur de chargement',
        description: message,
        actionLabel: 'Réessayer',
        onAction: () => ref.read(deliveryHistoryProvider.notifier).load(),
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

// ---------------------------------------------------------------------------
// Ligne d'historique (ZeetCard outlined)
// ---------------------------------------------------------------------------
class _DeliveryHistoryTile extends StatelessWidget {
  const _DeliveryHistoryTile({
    required this.item,
    required this.onTap,
  });

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
    final fee = item.deliveryFee;

    return ZeetCard(
      onTap: onTap,
      padding: EdgeInsets.all(16.w),
      semanticLabel:
          'Livraison ${item.displayCode}, ${item.statusLabel}, ${fee.toStringAsFixed(0)} francs',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 56.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Ligne 1 : code + statut. Hero `mission-ref-${id}` flie
            // vers le header du detail.
            Row(
              children: <Widget>[
                Expanded(
                  child: Hero(
                    tag: 'mission-ref-${item.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        item.displayCode,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
            SizedBox(height: 8.h),
            // Ligne 2 : restaurant
            _InfoLine(
              icon: Icons.storefront_rounded,
              text: item.partnerName,
              color: scheme.onSurface,
            ),
            SizedBox(height: 4.h),
            // Ligne 3 : client + adresse
            _InfoLine(
              icon: Icons.person_rounded,
              text: item.customerName,
              color: scheme.onSurfaceVariant,
            ),
            if (item.deliveryAddress != null &&
                item.deliveryAddress!.isNotEmpty) ...<Widget>[
              SizedBox(height: 4.h),
              _InfoLine(
                icon: Icons.place_rounded,
                text: item.deliveryAddress!,
                color: scheme.onSurfaceVariant,
              ),
            ],
            SizedBox(height: 8.h),
            // Ligne 4 : date + fee
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  dateLabel,
                  style: tt.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                ZeetMoney(
                  amount: fee,
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: tt.bodySmall?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chip de filtre
// ---------------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Filtrer : $label',
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZeetRadius.pill),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outline,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(ZeetRadius.pill),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: 40.h),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            alignment: Alignment.center,
            child: Text(
              label,
              style: tt.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
