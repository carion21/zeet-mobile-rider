// lib/screens/stats/index.dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'Jour'; // Jour, Semaine, Mois

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedPeriod = ['Jour', 'Semaine', 'Mois'][_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Données de test pour les graphiques
  List<ChartData> _getDayData() {
    return [
      ChartData('8h', 2),
      ChartData('10h', 5),
      ChartData('12h', 8),
      ChartData('14h', 6),
      ChartData('16h', 9),
      ChartData('18h', 12),
      ChartData('20h', 7),
    ];
  }

  List<ChartData> _getWeekData() {
    return [
      ChartData('Lun', 15),
      ChartData('Mar', 22),
      ChartData('Mer', 18),
      ChartData('Jeu', 25),
      ChartData('Ven', 30),
      ChartData('Sam', 35),
      ChartData('Dim', 28),
    ];
  }

  List<ChartData> _getMonthData() {
    return [
      ChartData('S1', 85),
      ChartData('S2', 92),
      ChartData('S3', 78),
      ChartData('S4', 105),
    ];
  }

  List<ChartData> _getEarningsData() {
    switch (_selectedPeriod) {
      case 'Jour':
        return [
          ChartData('8h', 3500),
          ChartData('10h', 7200),
          ChartData('12h', 12800),
          ChartData('14h', 9600),
          ChartData('16h', 14400),
          ChartData('18h', 19200),
          ChartData('20h', 11200),
        ];
      case 'Semaine':
        return [
          ChartData('Lun', 22500),
          ChartData('Mar', 33000),
          ChartData('Mer', 27000),
          ChartData('Jeu', 37500),
          ChartData('Ven', 45000),
          ChartData('Sam', 52500),
          ChartData('Dim', 42000),
        ];
      case 'Mois':
      default:
        return [
          ChartData('S1', 127500),
          ChartData('S2', 138000),
          ChartData('S3', 117000),
          ChartData('S4', 157500),
        ];
    }
  }

  List<ChartData> _getCurrentData() {
    switch (_selectedPeriod) {
      case 'Jour':
        return _getDayData();
      case 'Semaine':
        return _getWeekData();
      case 'Mois':
      default:
        return _getMonthData();
    }
  }

  int _getTotalDeliveries() {
    final data = _getCurrentData();
    return data.fold(0, (sum, item) => sum + item.value.toInt());
  }

  double _getTotalEarnings() {
    final data = _getEarningsData();
    return data.fold(0.0, (sum, item) => sum + item.value);
  }

  double _getAveragePerDelivery() {
    final deliveries = _getTotalDeliveries();
    return deliveries > 0 ? _getTotalEarnings() / deliveries : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    AppSizes().initialize(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: IconManager.getIcon('arrow_back', color: textColor),
          onPressed: () => Routes.goBack(),
        ),
        title: Text(
          'Statistiques',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: textLightColor,
          indicatorWeight: 2,
          dividerColor: Colors.transparent,
          labelStyle: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Jour'),
            Tab(text: 'Semaine'),
            Tab(text: 'Mois'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsContent(surfaceColor, textColor, textLightColor, isDarkMode),
          _buildStatsContent(surfaceColor, textColor, textLightColor, isDarkMode),
          _buildStatsContent(surfaceColor, textColor, textLightColor, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildStatsContent(
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes().paddingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé des stats
          _buildSummaryCards(surfaceColor, textColor, textLightColor, isDarkMode),

          const SizedBox(height: 24),

          // Graphique des livraisons
          _buildDeliveriesChart(surfaceColor, textColor, textLightColor, isDarkMode),

          const SizedBox(height: 24),

          // Graphique des gains
          _buildEarningsChart(surfaceColor, textColor, textLightColor, isDarkMode),

          const SizedBox(height: 24),

          // Détails additionnels
          _buildAdditionalDetails(surfaceColor, textColor, textLightColor, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Livraisons',
            value: '${_getTotalDeliveries()}',
            icon: 'delivery',
            color: AppColors.primary,
            surfaceColor: surfaceColor,
            textColor: textColor,
            textLightColor: textLightColor,
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Gains totaux',
            value: '${NumberFormat('#,###', 'fr_FR').format(_getTotalEarnings())} F',
            icon: 'wallet',
            color: const Color(0xFF4CD964),
            surfaceColor: surfaceColor,
            textColor: textColor,
            textLightColor: textLightColor,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String icon,
    required Color color,
    required Color surfaceColor,
    required Color textColor,
    required Color textLightColor,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconManager.getIcon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: textLightColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesChart(
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconManager.getIcon(
                  'delivery',
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Livraisons par $_selectedPeriod',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: TextStyle(
                  color: textLightColor,
                  fontSize: 12.sp,
                ),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: MajorGridLines(
                  width: 1,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                ),
                labelStyle: TextStyle(
                  color: textLightColor,
                  fontSize: 12.sp,
                ),
              ),
              series: <CartesianSeries>[
                SplineAreaSeries<ChartData, String>(
                  dataSource: _getCurrentData(),
                  xValueMapper: (ChartData data, _) => data.label,
                  yValueMapper: (ChartData data, _) => data.value,
                  color: AppColors.primary.withValues(alpha: 0.3),
                  borderColor: AppColors.primary,
                  borderWidth: 3,
                  markerSettings: MarkerSettings(
                    isVisible: true,
                    color: AppColors.primary,
                    borderColor: Colors.white,
                    borderWidth: 2,
                    height: 8,
                    width: 8,
                  ),
                ),
              ],
              tooltipBehavior: TooltipBehavior(
                enable: true,
                color: isDarkMode ? AppColors.darkSurface : Colors.white,
                textStyle: TextStyle(color: textColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsChart(
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CD964).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconManager.getIcon(
                  'wallet',
                  color: const Color(0xFF4CD964),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Gains par $_selectedPeriod',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: TextStyle(
                  color: textLightColor,
                  fontSize: 12.sp,
                ),
              ),
              primaryYAxis: NumericAxis(
                majorGridLines: MajorGridLines(
                  width: 1,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                ),
                labelStyle: TextStyle(
                  color: textLightColor,
                  fontSize: 12.sp,
                ),
                numberFormat: NumberFormat.compact(locale: 'fr_FR'),
              ),
              series: <CartesianSeries>[
                ColumnSeries<ChartData, String>(
                  dataSource: _getEarningsData(),
                  xValueMapper: (ChartData data, _) => data.label,
                  yValueMapper: (ChartData data, _) => data.value,
                  color: const Color(0xFF4CD964),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  dataLabelSettings: DataLabelSettings(
                    isVisible: false,
                    textStyle: TextStyle(
                      color: textColor,
                      fontSize: 10.sp,
                    ),
                  ),
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

  Widget _buildAdditionalDetails(
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Détails',
            style: TextStyle(
              color: textColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Moyenne par livraison',
            '${NumberFormat('#,###', 'fr_FR').format(_getAveragePerDelivery())} F',
            textColor,
            textLightColor,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Meilleure journée',
            _selectedPeriod == 'Mois'
                ? 'Semaine 4'
                : _selectedPeriod == 'Semaine'
                    ? 'Samedi'
                    : '18h',
            textColor,
            textLightColor,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            'Taux de complétion',
            '96%',
            textColor,
            textLightColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color textColor,
    Color textLightColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textLightColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class ChartData {
  final String label;
  final double value;

  ChartData(this.label, this.value);
}
