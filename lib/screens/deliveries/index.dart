// lib/screens/deliveries/index.dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/models/delivery_model.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Exemples de livraisons
  final List<Delivery> _newDeliveries = [
    Delivery(
      id: 'DLV003',
      customerName: 'Assemian Marie',
      customerPhone: '+225 0101010103',
      restaurantName: 'Asian Fusion',
      pickupAddress: 'Cocody, Boulevard Latrille',
      deliveryAddress: 'Cocody, II Plateaux Vallon',
      status: 'new',
      distance: 2.5,
      estimatedTime: 20,
      deliveryFee: 1200,
      orderDetails: '1 article',
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
  ];

  final List<Delivery> _ongoingDeliveries = [
    Delivery(
      id: 'DLV001',
      customerName: 'Kouadio Aya',
      customerPhone: '+225 0707070701',
      restaurantName: 'Chez Maman',
      pickupAddress: 'Cocody, Angré 7ème Tranche',
      deliveryAddress: 'Cocody, Riviera Palmeraie',
      status: 'accepted',
      distance: 3.2,
      estimatedTime: 25,
      deliveryFee: 1500,
      orderDetails: '2 articles',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Delivery(
      id: 'DLV002',
      customerName: 'Yao Jean',
      customerPhone: '+225 0505050502',
      restaurantName: 'Le Bistro Gourmand',
      pickupAddress: 'Plateau, Rue du Commerce',
      deliveryAddress: 'Marcory, Zone 4',
      status: 'picked_up',
      distance: 5.8,
      estimatedTime: 35,
      deliveryFee: 2000,
      orderDetails: '3 articles',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
  ];

  final List<Delivery> _completedDeliveries = [
    Delivery(
      id: 'DLV100',
      customerName: 'Brou Sylvie',
      customerPhone: '+225 0606060604',
      restaurantName: 'La Terrasse Verte',
      pickupAddress: 'Plateau, Avenue Chardy',
      deliveryAddress: 'Yopougon, Sideci',
      status: 'delivered',
      distance: 8.5,
      estimatedTime: 45,
      deliveryFee: 2500,
      orderDetails: '4 articles',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Delivery(
      id: 'DLV099',
      customerName: 'Koné Ibrahim',
      customerPhone: '+225 0404040405',
      restaurantName: 'Pasta & Co',
      pickupAddress: 'Cocody, Rue Lepic',
      deliveryAddress: 'Adjamé, Marché',
      status: 'delivered',
      distance: 6.2,
      estimatedTime: 40,
      deliveryFee: 2200,
      orderDetails: '2 articles',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(textColor),

            // Tabs
            _buildTabs(surfaceColor, textColor, textLightColor),

            // Liste des livraisons
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDeliveryList(_newDeliveries, textColor, textLightColor, surfaceColor, 'new'),
                  _buildDeliveryList(_ongoingDeliveries, textColor, textLightColor, surfaceColor, 'ongoing'),
                  _buildDeliveryList(_completedDeliveries, textColor, textLightColor, surfaceColor, 'completed'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes().paddingMedium,
        vertical: AppSizes().paddingSmall,
      ),
      child: Row(
        children: [
          IconButton(
            icon: IconManager.getIcon(
              'arrow_back',
              color: textColor,
            ),
            onPressed: () => Routes.goBack(),
          ),
          const SizedBox(width: 8),
          Text(
            'Mes livraisons',
            style: TextStyle(
              color: textColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(Color surfaceColor, Color textColor, Color textLightColor) {
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
                if (_newDeliveries.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_newDeliveries.length}',
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
            text: 'En cours',
          ),
          const Tab(
            height: 40,
            text: 'Terminées',
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryList(
    List<Delivery> deliveries,
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    String type,
  ) {
    if (deliveries.isEmpty) {
      return _buildEmptyState(type, textColor, textLightColor, surfaceColor);
    }

    return ListView.builder(
      padding: EdgeInsets.all(AppSizes().paddingLarge),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        return _buildDeliveryCard(
          deliveries[index],
          textColor,
          textLightColor,
          surfaceColor,
        );
      },
    );
  }

  Widget _buildEmptyState(String type, Color textColor, Color textLightColor, Color surfaceColor) {
    String title;
    String subtitle;

    switch (type) {
      case 'new':
        title = 'Aucune nouvelle livraison';
        subtitle = 'Les nouvelles commandes\napparaîtront ici';
        break;
      case 'ongoing':
        title = 'Aucune livraison en cours';
        subtitle = 'Acceptez une livraison\npour commencer';
        break;
      case 'completed':
        title = 'Aucune livraison terminée';
        subtitle = 'Vos livraisons terminées\napparaîtront ici';
        break;
      default:
        title = 'Aucune livraison';
        subtitle = '';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconManager.getIcon(
              'delivery',
              color: Colors.grey.shade400,
              size: 52,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: textLightColor,
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(Delivery delivery, Color textColor, Color textLightColor, Color surfaceColor) {
    // Déterminer la couleur du statut
    Color statusColor;
    String statusText;

    switch (delivery.status) {
      case 'new':
        statusColor = const Color(0xFFFFA500);
        statusText = 'Nouvelle';
        break;
      case 'accepted':
        statusColor = const Color(0xFF2196F3);
        statusText = 'Acceptée';
        break;
      case 'picked_up':
        statusColor = AppColors.primary;
        statusText = 'Récupérée';
        break;
      case 'delivered':
        statusColor = const Color(0xFF4CD964);
        statusText = 'Livrée';
        break;
      default:
        statusColor = Colors.grey;
        statusText = delivery.status;
    }

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
          Routes.pushDeliveryDetails(delivery: delivery);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec ID et statut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${delivery.id}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
                      delivery.restaurantName,
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
                      delivery.customerName,
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
                      delivery.deliveryAddress,
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

              // Infos bas (distance, temps, frais)
              Row(
                children: [
                  _buildSmallBadge(
                    'location_on',
                    '${delivery.distance} km',
                    const Color(0xFF4CD964),
                  ),
                  const SizedBox(width: 8),
                  _buildSmallBadge(
                    'access_time',
                    '${delivery.estimatedTime} min',
                    const Color(0xFFFF6B6B),
                  ),
                  const Spacer(),
                  Text(
                    '${delivery.deliveryFee.toStringAsFixed(0)} F',
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
