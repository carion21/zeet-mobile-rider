// lib/screens/stats/index.dart
//
// Screen statistiques rider.
//
// Source principale : `riderStatsProvider` (GET /v1/rider/stats).
// Le screen affiche uniquement les metriques reellement livrees par le
// backend (cf. BACKEND_WORK_ORDER_REPORT, tache 6) :
//   - total_deliveries, delivered_count, not_delivered_count
//   - accepted_count, rejected_count
//   - completion_rate, acceptance_rate
//   - rating_avg, rating_count
//   - total_earnings
//
// Les metriques non livrees (avg_pickup_time, avg_delivery_time, total_km,
// streak_days, total_active_hours) ont ete retirees. Si un KPI apparait
// dans le design mais pas dans le contrat, il est absent de ce screen.
//
// Le chart "gains par jour" continue d'etre alimente par `earningsProvider`
// (pas de concurrence : les 2 providers coexistent).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/widgets/freshness/zeet_freshness_chip.dart';
import 'package:rider/models/earnings_model.dart';
import 'package:rider/models/rider_stats_model.dart';
import 'package:rider/providers/earnings_provider.dart';
import 'package:rider/providers/stats_provider.dart';
import 'package:rider/screens/stats/widgets/end_of_day_recap_sheet.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:zeet_ui/zeet_ui.dart';

/// Presets de periode pour le filtre rapide.
enum _StatsPreset { today, week, month }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _StatsPreset _preset = _StatsPreset.month;

  // Clé pour notifier la chip freshness d'un refresh externe
  // (pull-to-refresh, retry, changement de preset).
  final GlobalKey<ZeetFreshnessChipLocalState> _freshKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadForCurrentPreset();
      // Le chart "gains par jour" continue d'utiliser earnings_provider.
      ref.read(earningsSummaryProvider.notifier).load(period: 'month');
      // Historique des transactions (gains/jour, primes, pourboires) —
      // backend `/v1/rider/earnings/history`. Charge la 1ere page,
      // l'utilisateur peut paginer via le bouton "Voir plus".
      ref.read(earningsHistoryProvider.notifier).load();
    });
  }

  // ---------------------------------------------------------------------------
  // Period helpers
  // ---------------------------------------------------------------------------

  ({String from, String to}) _rangeForPreset(_StatsPreset preset) {
    final now = DateTime.now();
    late DateTime from;
    late DateTime to;
    switch (preset) {
      case _StatsPreset.today:
        from = DateTime(now.year, now.month, now.day);
        to = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case _StatsPreset.week:
        // Semaine : lundi -> aujourd'hui
        final monday = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(monday.year, monday.month, monday.day);
        to = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case _StatsPreset.month:
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
    }
    final fmt = DateFormat('yyyy-MM-dd');
    return (from: fmt.format(from), to: fmt.format(to));
  }

  String _earningsPeriodForPreset(_StatsPreset preset) {
    switch (preset) {
      case _StatsPreset.today:
        return 'day';
      case _StatsPreset.week:
        return 'week';
      case _StatsPreset.month:
        return 'month';
    }
  }

  String _labelForPreset(_StatsPreset preset) {
    switch (preset) {
      case _StatsPreset.today:
        return "Aujourd'hui";
      case _StatsPreset.week:
        return 'Cette semaine';
      case _StatsPreset.month:
        return 'Ce mois';
    }
  }

  Future<void> _loadForCurrentPreset() {
    final range = _rangeForPreset(_preset);
    return ref
        .read(riderStatsProvider.notifier)
        .load(dateFrom: range.from, dateTo: range.to);
  }

  Future<void> _onPresetTap(_StatsPreset preset) async {
    if (_preset == preset) return;
    ZeetHaptics.tap();
    setState(() => _preset = preset);
    await Future.wait([
      _loadForCurrentPreset(),
      ref
          .read(earningsSummaryProvider.notifier)
          .load(period: _earningsPeriodForPreset(preset)),
    ]);
    _freshKey.currentState?.bump();
  }

  Future<void> _refreshAll() async {
    ZeetHaptics.success();
    await Future.wait([
      _loadForCurrentPreset(),
      ref
          .read(earningsSummaryProvider.notifier)
          .load(period: _earningsPeriodForPreset(_preset)),
    ]);
    _freshKey.currentState?.bump();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final statsState = ref.watch(riderStatsProvider);
    final summaryState = ref.watch(earningsSummaryProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : ZeetColors.surfaceAlt;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    AppSizes().initialize(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        // Pas de leading back button : l'ecran est un onglet permanent du
        // MainScaffold, on revient au Home via la bottom nav.
        automaticallyImplyLeading: false,
        title: Text(
          'Mes gains',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          // Clôture de service — affiche un récap peak moment quand on
          // est en mode "today" et qu'au moins une livraison a été faite.
          if (_preset == _StatsPreset.today &&
              (statsState.stats?.deliveredCount ?? 0) > 0)
            IconButton(
              tooltip: 'Clôturer ma journée',
              icon: Icon(Icons.bedtime_rounded, color: textColor),
              onPressed: () {
                final stats = statsState.stats;
                if (stats == null) return;
                showEndOfDayRecapSheet(
                  context,
                  deliveries: stats.deliveredCount,
                  earnings: stats.totalEarnings,
                  isRecord: false,
                );
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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshAll,
        child: _buildBody(
          statsState,
          summaryState,
          surfaceColor,
          textColor,
          textLightColor,
          isDarkMode,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ELOE states
  // ---------------------------------------------------------------------------

  Widget _buildBody(
    RiderStatsState statsState,
    EarningsSummaryState summaryState,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    // Loading initial : skeleton list au lieu d'un spinner plein écran
    // (skill zeet-states-elae §2 — hierarchy "skeleton first").
    if (statsState.isLoading && statsState.stats == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _buildPeriodFilter(textColor, textLightColor, surfaceColor),
          SizedBox(height: 16.h),
          const ZeetSkeletonList(itemCount: 5, itemHeight: 110),
        ],
      );
    }

    // Error sans fallback (premier chargement echoue).
    if (statsState.errorMessage != null && statsState.stats == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildPeriodFilter(textColor, textLightColor, surfaceColor),
          SizedBox(height: 0.1.sh),
          _buildErrorState(statsState.errorMessage!, textColor, textLightColor),
        ],
      );
    }

    return _buildContent(
      statsState,
      summaryState,
      surfaceColor,
      textColor,
      textLightColor,
      isDarkMode,
    );
  }

  Widget _buildErrorState(
    String message,
    Color textColor,
    Color textLightColor,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconManager.getIcon('warning', color: textLightColor, size: 48),
          SizedBox(height: 16.h),
          Text(
            'Impossible de charger les statistiques',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: textLightColor, fontSize: 13.sp),
          ),
          SizedBox(height: 16.h),
          TextButton(
            onPressed: _refreshAll,
            child: Text(
              'Réessayer',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color textLightColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconManager.getIcon('chart', color: textLightColor, size: 56),
          SizedBox(height: 16.h),
          Text(
            'Aucune activite sur cette periode',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Vos livraisons apparaitront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textLightColor, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------------

  Widget _buildContent(
    RiderStatsState statsState,
    EarningsSummaryState summaryState,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    final stats = statsState.stats;
    final isEmpty = stats != null && stats.totalDeliveries == 0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodFilter(textColor, textLightColor, surfaceColor),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statsState.isLoading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  SizedBox(height: 12.h),
                ],
                if (isEmpty)
                  _buildEmptyState(textColor, textLightColor)
                else ...[
                  _buildEarningsHero(
                    stats!,
                    surfaceColor,
                    textColor,
                    textLightColor,
                    isDarkMode,
                  ),
                  SizedBox(height: 16.h),
                  _buildDeliveriesRow(
                    stats,
                    surfaceColor,
                    textColor,
                    textLightColor,
                    isDarkMode,
                  ),
                  SizedBox(height: 16.h),
                  _buildRatesRow(
                    stats,
                    surfaceColor,
                    textColor,
                    textLightColor,
                    isDarkMode,
                  ),
                  SizedBox(height: 16.h),
                  _buildRatingCard(
                    stats,
                    surfaceColor,
                    textColor,
                    textLightColor,
                    isDarkMode,
                  ),
                  SizedBox(height: 16.h),
                  _buildEarningsChart(
                    summaryState.summary,
                    surfaceColor,
                    textColor,
                    textLightColor,
                    isDarkMode,
                  ),
                  SizedBox(height: 16.h),
                  _EarningsHistorySection(
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    textLightColor: textLightColor,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Period filter
  // ---------------------------------------------------------------------------

  Widget _buildPeriodFilter(
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: _StatsPreset.values.map((p) {
          final selected = p == _preset;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: p == _StatsPreset.values.last ? 0 : 8.w,
              ),
              child: Material(
                color: selected ? AppColors.primary : surfaceColor,
                borderRadius: BorderRadius.circular(10.r),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10.r),
                  onTap: () => _onPresetTap(p),
                  child: Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      _labelForPreset(p),
                      style: TextStyle(
                        color: selected ? Colors.white : textColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero (gains totaux)
  // ---------------------------------------------------------------------------

  Widget _buildEarningsHero(
    RiderStats stats,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gains totaux',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          ZeetMoney(
            amount: stats.totalEarnings,
            currency: ZeetCurrency.fcfa,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${stats.deliveredCount} livraison${stats.deliveredCount > 1 ? 's' : ''} réussie${stats.deliveredCount > 1 ? 's' : ''}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Deliveries row
  // ---------------------------------------------------------------------------

  Widget _buildDeliveriesRow(
    RiderStats stats,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            label: 'Total',
            value: stats.totalDeliveries,
            icon: 'delivery',
            color: AppColors.primary,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textLightColor: textLightColor,
            isDarkMode: isDarkMode,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildKpiCard(
            label: 'Livrees',
            value: stats.deliveredCount,
            icon: 'check',
            color: ZeetColors.success,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textLightColor: textLightColor,
            isDarkMode: isDarkMode,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildKpiCard(
            label: 'Echouees',
            value: stats.notDeliveredCount,
            icon: 'warning',
            color: ZeetColors.danger,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textLightColor: textLightColor,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Rates row
  // ---------------------------------------------------------------------------

  Widget _buildRatesRow(
    RiderStats stats,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildRateCard(
            label: 'Taux d\'acceptation',
            value: stats.acceptanceRate,
            helper:
                '${stats.acceptedCount} accept. / ${stats.acceptedCount + stats.rejectedCount} offres',
            color: AppColors.primary,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textLightColor: textLightColor,
            isDarkMode: isDarkMode,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildRateCard(
            label: 'Taux de completion',
            value: stats.completionRate,
            helper:
                '${stats.deliveredCount} / ${stats.totalDeliveries} livraisons',
            color: ZeetColors.success,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textLightColor: textLightColor,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildRateCard({
    required String label,
    required double value,
    required String helper,
    required Color color,
    required Color surfaceColor,
    required Color textColor,
    required Color textLightColor,
    required bool isDarkMode,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
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
          Text(
            label,
            style: TextStyle(
              color: textLightColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          ZeetRollingCounter(
            value: (value * 100).clamp(0, 100),
            suffix: '%',
            style: TextStyle(
              color: color,
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            helper,
            style: TextStyle(color: textLightColor, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rating card
  // ---------------------------------------------------------------------------

  Widget _buildRatingCard(
    RiderStats stats,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: ZeetColors.starGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Center(
              child: IconManager.getIcon(
                'star',
                color: ZeetColors.starGold,
                size: 28,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note moyenne',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ZeetRollingCounter(
                      value: stats.ratingAvg,
                      fractionDigits: 1,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Padding(
                      padding: EdgeInsets.only(bottom: 4.h),
                      child: Text(
                        '/ 5',
                        style: TextStyle(
                          color: textLightColor,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  '${stats.ratingCount} avis',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Routes.navigateTo(Routes.ratings),
            child: Text(
              'Voir',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Earnings chart (alimente par earnings_provider — complement au summary)
  // ---------------------------------------------------------------------------

  Widget _buildEarningsChart(
    EarningsSummary? summary,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    final points = summary?.byPeriod ?? const <EarningsPeriodPoint>[];
    final data = points
        .map((p) => _ChartData(_formatPointLabel(p.date), p.earnings))
        .toList();

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
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
                  color: ZeetColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: IconManager.getIcon(
                  'wallet',
                  color: ZeetColors.success,
                  size: 18,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Gains par periode',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (data.isEmpty)
            SizedBox(
              height: 160.h,
              child: Center(
                child: Text(
                  'Aucune activite sur cette periode',
                  style: TextStyle(color: textLightColor, fontSize: 13.sp),
                ),
              ),
            )
          else
            SizedBox(
              height: 200.h,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  labelStyle:
                      TextStyle(color: textLightColor, fontSize: 12.sp),
                ),
                primaryYAxis: NumericAxis(
                  majorGridLines: MajorGridLines(
                    width: 1,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.1),
                  ),
                  labelStyle:
                      TextStyle(color: textLightColor, fontSize: 12.sp),
                  numberFormat: NumberFormat.compact(locale: 'fr_FR'),
                ),
                series: <CartesianSeries>[
                  ColumnSeries<_ChartData, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    color: ZeetColors.success,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  color: isDarkMode ? AppColors.darkSurface : Colors.white,
                  textStyle: TextStyle(color: textColor),
                  format: 'point.x : point.y F',
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatPointLabel(String raw) {
    if (raw.isEmpty) return '';
    if (raw.contains(':') && !raw.contains('-')) {
      final parts = raw.split(':');
      final h = int.tryParse(parts.first);
      if (h != null) return '${h}h';
      return raw;
    }
    try {
      final date = DateTime.parse(raw);
      switch (_preset) {
        case _StatsPreset.today:
          return '${date.hour}h';
        case _StatsPreset.week:
          const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
          return days[(date.weekday - 1) % 7];
        case _StatsPreset.month:
          return DateFormat('dd/MM', 'fr_FR').format(date);
      }
    } catch (_) {
      return raw;
    }
  }

  // ---------------------------------------------------------------------------
  // KPI card helper
  // ---------------------------------------------------------------------------

  /// Card KPI avec compteur animé (rolling counter) — change de période
  /// (today/week/month) déclenche une animation flip vers la nouvelle valeur.
  /// Skill : zeet-motion-system §6 (Number animation grammar).
  Widget _buildKpiCard({
    required String label,
    required num value,
    required String icon,
    required Color color,
    required Color surfaceColor,
    required Color textColor,
    required Color textLightColor,
    required bool isDarkMode,
  }) {
    return Container(
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
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: IconManager.getIcon(icon, color: color, size: 18),
          ),
          SizedBox(height: 10.h),
          ZeetRollingCounter(
            value: value,
            style: TextStyle(
              color: textColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(color: textLightColor, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class _ChartData {
  final String label;
  final double value;

  const _ChartData(this.label, this.value);
}

// ---------------------------------------------------------------------------
// Earnings history section (transactions list — alimente le nouveau onglet
// "Gains"). Source : `earningsHistoryProvider` (GET /v1/rider/earnings/history).
// Etats ELOE : loading skeleton / error retry / empty / list paginee.
// ---------------------------------------------------------------------------

class _EarningsHistorySection extends ConsumerWidget {
  const _EarningsHistorySection({
    required this.surfaceColor,
    required this.textColor,
    required this.textLightColor,
    required this.isDarkMode,
  });

  final Color surfaceColor;
  final Color textColor;
  final Color textLightColor;
  final bool isDarkMode;

  /// Limite l'affichage initial pour ne pas exploser le scroll. L'utilisateur
  /// peut paginer avec le bouton "Voir plus".
  static const int _previewLimit = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(earningsHistoryProvider);
    final notifier = ref.read(earningsHistoryProvider.notifier);
    final Color borderColor =
        isDarkMode ? ZeetColors.lineDark : ZeetColors.line;

    final List<EarningsEntry> visible =
        state.entries.take(_previewLimit + (state.currentPage - 1) * 10).toList();

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(ZeetRadius.md),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
            child: Row(
              children: <Widget>[
                Icon(Icons.receipt_long_rounded,
                    color: textLightColor, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  'Historique des transactions',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (state.isLoading && state.entries.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: const ZeetSkeletonList(itemCount: 4, itemHeight: 56),
            )
          else if (state.errorMessage != null && state.entries.isEmpty)
            Padding(
              padding: EdgeInsets.all(16.w),
              child: ZeetErrorState(
                kind: ZeetErrorKind.generic,
                description: state.errorMessage,
                onRetry: () => notifier.refresh(),
                compact: true,
              ),
            )
          else if (state.entries.isEmpty)
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Center(
                child: Text(
                  'Aucune transaction sur cette période.',
                  style: TextStyle(color: textLightColor, fontSize: 13.sp),
                ),
              ),
            )
          else
            ...visible.map<Widget>(
              (entry) => _EarningsEntryTile(
                entry: entry,
                textColor: textColor,
                textLightColor: textLightColor,
                borderColor: borderColor,
              ),
            ),
          if (state.hasMore && state.entries.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Center(
                child: TextButton.icon(
                  onPressed: state.isLoadingMore
                      ? null
                      : () => notifier.loadMore(),
                  icon: state.isLoadingMore
                      ? SizedBox(
                          width: 14.sp,
                          height: 14.sp,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ZeetColors.primary,
                          ),
                        )
                      : Icon(Icons.expand_more_rounded,
                          color: ZeetColors.primary, size: 18.sp),
                  label: Text(
                    state.isLoadingMore ? 'Chargement…' : 'Voir plus',
                    style: TextStyle(
                      color: ZeetColors.primary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EarningsEntryTile extends StatelessWidget {
  const _EarningsEntryTile({
    required this.entry,
    required this.textColor,
    required this.textLightColor,
    required this.borderColor,
  });

  final EarningsEntry entry;
  final Color textColor;
  final Color textLightColor;
  final Color borderColor;

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('d MMM, HH:mm', 'fr_FR').format(dt);
    } catch (_) {
      return raw;
    }
  }

  IconData _iconForType() {
    switch (entry.type) {
      case 'tip':
        return Icons.volunteer_activism_rounded;
      case 'bonus':
        return Icons.card_giftcard_rounded;
      case 'penalty':
        return Icons.remove_circle_outline_rounded;
      case 'adjustment':
        return Icons.tune_rounded;
      case 'delivery':
      case 'delivery_fee':
      default:
        return Icons.two_wheeler_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool credit = entry.isCredit;
    final Color amountColor =
        credit ? ZeetColors.success : ZeetColors.danger;
    final String prefix = credit ? '+' : '';
    final String label = entry.description?.trim().isNotEmpty == true
        ? entry.description!
        : entry.typeLabel;
    final String dateLabel = _formatDate(entry.createdAt);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: <Widget>[
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: ZeetColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(_iconForType(), size: 18.sp, color: textLightColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dateLabel.isNotEmpty) ...<Widget>[
                  SizedBox(height: 2.h),
                  Text(
                    dateLabel,
                    style: TextStyle(color: textLightColor, fontSize: 11.sp),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                prefix,
                style: TextStyle(
                  color: amountColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ZeetMoney(
                amount: entry.amount.abs(),
                currency: ZeetCurrency.fcfa,
                style: TextStyle(
                  color: amountColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
