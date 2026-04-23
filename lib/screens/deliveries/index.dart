// lib/screens/deliveries/index.dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/providers/connectivity_provider.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/screens/deliveries/widgets/completed_tab.dart';
import 'package:rider/widgets/mission_status_chip.dart';
import 'package:zeet_ui/zeet_ui.dart';

class DeliveriesScreen extends ConsumerStatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  ConsumerState<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends ConsumerState<DeliveriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Charger les missions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(missionsListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missionsState = ref.watch(missionsListProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    AppSizes().initialize(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(textColor),

            // Tabs
            _buildTabs(surfaceColor, textColor, textLightColor, missionsState),

            // Liste des missions, wrappée dans ZeetScreenScaffold pour
            // gérer ELOE (loading/empty/error/offline) de manière unifiée
            // à travers le design system.
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMissionTab(
                    missionsState.available,
                    missionsState,
                    textColor,
                    textLightColor,
                    surfaceColor,
                    'new',
                  ),
                  _buildMissionTab(
                    missionsState.ongoing,
                    missionsState,
                    textColor,
                    textLightColor,
                    surfaceColor,
                    'ongoing',
                  ),
                  // L'onglet "Terminées" consomme desormais
                  // GET /v1/rider/deliveries (historique paginé réel)
                  // au lieu d'un filtre client-side sur les missions
                  // actives (gap analysis 2026-04-15).
                  const CompletedDeliveriesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    // Pas de back button : l'ecran est un onglet permanent du MainScaffold,
    // accessible directement via la bottom nav. Le retour vers Home se fait
    // par tap sur l'onglet Accueil (skill `zeet-3-clicks-rule`).
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes().paddingLarge,
        vertical: AppSizes().paddingSmall,
      ),
      child: Row(
        children: [
          Text(
            'Mes livraisons',
            style: TextStyle(
              color: textColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Bouton de rafraichissement
          IconButton(
            icon: IconManager.getIcon('refresh', color: textColor, size: 22),
            onPressed: () => ref.read(missionsListProvider.notifier).refresh(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    MissionsListState missionsState,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes().paddingLarge,
        vertical: AppSizes().paddingSmall,
      ),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: textLightColor,
        labelStyle: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Nouvelles'),
                if (missionsState.available.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${missionsState.available.length}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('En cours'),
                if (missionsState.ongoing.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${missionsState.ongoing.length}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(
            height: 40,
            text: 'Terminées',
          ),
        ],
      ),
    );
  }

  /// Enveloppe un tab de missions dans un [ZeetScreenScaffold] qui gère
  /// tous les états ELOE (loading skeleton / empty / error / offline) de
  /// manière unifiée. Le [RefreshIndicator] est conservé autour du
  /// scaffold pour permettre le pull-to-refresh même quand la liste est
  /// vide (state == content avec 0 items remplacé par state.empty).
  Widget _buildMissionTab(
    List<Mission> missions,
    MissionsListState missionsState,
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    String type,
  ) {
    final bool isOnline = ref
        .watch(connectivityStatusProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);

    final ZeetScreenState screenState =
        _resolveState(missionsState, missions, isOnline);

    // Micro-copy contextualisée par type d'onglet.
    final (String emptyTitle, String emptySubtitle) = switch (type) {
      'new' => (
          'Aucune mission en cours',
          "Quand une mission est disponible, elle apparaîtra ici",
        ),
      'ongoing' => (
          'Aucune livraison en cours',
          'Accepte une mission pour commencer',
        ),
      _ => (
          'Aucune livraison',
          "Rien à afficher pour le moment",
        ),
    };

    return RefreshIndicator(
      onRefresh: () => ref.read(missionsListProvider.notifier).refresh(),
      color: AppColors.primary,
      child: ZeetScreenScaffold(
        state: screenState,
        onRetry: () => ref.read(missionsListProvider.notifier).refresh(),
        emptyTitle: emptyTitle,
        emptySubtitle: emptySubtitle,
        emptyIcon: Icons.inbox_outlined,
        errorMessage: missionsState.errorMessage,
        child: ListView.builder(
          padding: EdgeInsets.all(AppSizes().paddingLarge),
          itemCount: missions.length,
          itemBuilder: (context, index) {
            return _buildMissionCard(
              missions[index],
              textColor,
              textLightColor,
              surfaceColor,
            );
          },
        ),
      ),
    );
  }

  ZeetScreenState _resolveState(
    MissionsListState missionsState,
    List<Mission> missions,
    bool isOnline,
  ) {
    if (missionsState.isLoading && missions.isEmpty) {
      return ZeetScreenState.loading;
    }
    if (!isOnline && missions.isEmpty) {
      return ZeetScreenState.offline;
    }
    if (missionsState.errorMessage != null && missions.isEmpty) {
      return ZeetScreenState.error;
    }
    if (missions.isEmpty) {
      return ZeetScreenState.empty;
    }
    return ZeetScreenState.content;
  }

  Widget _buildMissionCard(
    Mission mission,
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Routes.pushMissionDetails(missionId: mission.id.toString());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tete avec reference et statut.
              // Hero sur la référence : flie vers le header detail
              // (delivery_details/index.dart). Tag stable par mission.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Hero(
                    tag: 'mission-ref-${mission.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        mission.orderReference,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  MissionStatusChip(mission: mission, dense: true),
                ],
              ),

              const SizedBox(height: 12),

              // Restaurant
              Row(
                children: [
                  IconManager.getIcon(
                    'restaurant',
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mission.partnerName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Client
              Row(
                children: [
                  IconManager.getIcon(
                    'person',
                    color: textLightColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mission.customerName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Adresse de livraison
              Row(
                children: [
                  IconManager.getIcon(
                    'location',
                    color: textLightColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mission.dropoffAddressDisplay,
                      style: TextStyle(
                        color: textLightColor,
                        fontSize: 13.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Infos bas (distance, articles, frais)
              Row(
                children: [
                  if (mission.distance != null)
                    _buildSmallBadge(
                      'location_on',
                      '${mission.distance!.toStringAsFixed(1)} km',
                      ZeetColors.success,
                    ),
                  if (mission.distance != null) const SizedBox(width: 8),
                  _buildSmallBadge(
                    'restaurant',
                    mission.itemCountText,
                    ZeetColors.danger,
                  ),
                  const Spacer(),
                  ZeetMoney(
                    amount: mission.fee,
                    currency: ZeetCurrency.fcfa,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String iconName, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconManager.getIcon(iconName, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
