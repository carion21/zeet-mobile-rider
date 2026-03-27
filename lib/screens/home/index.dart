// lib/screens/home/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/assets.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/models/delivery_model.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Gains du jour en FCFA
  final double _dailyEarnings = 15750.0;

  // Notifications non lues
  final int _unreadNotifications = 2;

  // Livraisons en attente
  int get _pendingDeliveries => _activeDeliveries.where((d) => d.status == 'new').length;

  @override
  void initState() {
    super.initState();
    // Charger le statut du rider au demarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStatus();
    });
  }

  void _initStatus() {
    // Synchroniser le statut local avec le rider_status du profil
    final rider = ref.read(currentRiderProvider);
    if (rider != null) {
      ref.read(statusProvider.notifier).setOnlineLocally(rider.isOnline);
    }
    // Puis charger le statut depuis l'API dediee
    ref.read(statusProvider.notifier).loadStatus();
  }

  // Exemples de livraisons en cours
  // TODO: Remplacer par les missions depuis missionProvider (BLOC 2)
  final List<Delivery> _activeDeliveries = [
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

  @override
  Widget build(BuildContext context) {
    // Watch providers so that build() re-runs when they change
    ref.watch(isOnlineProvider);
    ref.watch(currentRiderProvider);
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
            // Header custom (pas d'AppBar)
            _buildHeader(textColor, textLightColor),

            // Contenu défilable
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carte de gains du jour avec image de fond
                    _buildEarningsCard(isDarkMode),

                    const SizedBox(height: 16),

                    // Statistiques compactes
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSizes().paddingLarge),
                      child: _buildCompactStats(textColor, textLightColor, surfaceColor, isDarkMode),
                    ),

                    const SizedBox(height: 20),

                    // Section des livraisons
                    _buildDeliveriesSection(textColor, textLightColor, surfaceColor),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _activeDeliveries.isNotEmpty ? _buildDeliveriesFAB() : null,
    );
  }

  Widget _buildDeliveriesFAB() {
    return FloatingActionButton(
      onPressed: () => Routes.navigateTo(Routes.deliveries),
      backgroundColor: AppColors.primary,
      elevation: 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Iconsax.task_square,
            color: Colors.white,
            size: 28,
          ),
          if (_activeDeliveries.isNotEmpty)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 10,
                  minHeight: 10,
                ),
                child: Center(
                  child: Text(
                    '${_activeDeliveries.length}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color textLightColor) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes().paddingMedium,
            vertical: AppSizes().paddingSmall,
          ),
          child: Stack(
            children: [
              // Row pour les éléments gauche et droite
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Avatar à gauche
                  _buildAvatarWithEarnings(textColor, textLightColor),

                  // Icône de notification à droite
                  IconButton(
                    onPressed: () => Routes.navigateTo(Routes.notifications),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconManager.getIcon(
                          'notifications',
                          color: textColor,
                          size: 26,
                        ),
                        if (_unreadNotifications > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Center(
                                child: Text(
                                  '$_unreadNotifications',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Statut centré (parfaitement centré)
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Statut',
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 12.sp,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: ref.read(isOnlineProvider) ? const Color(0xFF4CD964) : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          ref.read(isOnlineProvider) ? 'En ligne' : 'Hors ligne',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWithEarnings(Color textColor, Color textLightColor) {
    return GestureDetector(
      onTap: () => Routes.navigateTo(Routes.profile),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            ref.read(currentRiderProvider)?.initials ?? '',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsCard(bool isDarkMode) {
    final walletBackground = isDarkMode ? AppAssets.darkWallet : AppAssets.lightWallet;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSizes().paddingLarge,
        vertical: AppSizes().paddingSmall,
      ),
      padding: EdgeInsets.all(AppSizes().paddingLarge * 1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: AssetImage(walletBackground),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Montant récupéré aujourd\'hui',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_dailyEarnings.toStringAsFixed(0)} F',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconManager.getIcon(
                  'wallet',
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStats(Color textColor, Color textLightColor, Color surfaceColor, bool isDarkMode) {
    return InkWell(
      onTap: () => Routes.navigateTo(Routes.stats),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        child: Row(
        children: [
          // Livraisons en attente
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En attente',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconManager.getIcon(
                      'delivery',
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_pendingDeliveries',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider vertical
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: 1,
              height: 40,
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ),

          // Gains du jour
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Votre gain du jour',
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconManager.getIcon(
                      'wallet',
                      color: const Color(0xFF4CD964),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '4100 F',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildDeliveriesSection(Color textColor, Color textLightColor, Color surfaceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de la section avec "Voir plus"
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes().paddingLarge,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mes livraisons',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => Routes.navigateTo(Routes.deliveries),
                child: Text(
                  'Voir plus',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Liste des livraisons
        _activeDeliveries.isEmpty
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSizes().paddingLarge),
                child: Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
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
                          'Aucune livraison',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ref.read(isOnlineProvider)
                              ? 'Les nouvelles commandes\napparaîtront ici'
                              : 'Mettez-vous en ligne\npour recevoir des livraisons',
                          style: TextStyle(
                            color: textLightColor,
                            fontSize: 14.sp,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSizes().paddingLarge),
                child: Column(
                  children: _activeDeliveries.take(2).map((delivery) {
                    return _buildDeliveryCard(delivery, textColor, textLightColor, surfaceColor);
                  }).toList(),
                ),
              ),
      ],
    );
  }

  Widget _buildDeliveryCard(Delivery delivery, Color textColor, Color textLightColor, Color surfaceColor) {
    // Déterminer la couleur du statut
    Color statusColor;
    String statusText;

    switch (delivery.status) {
      case 'new':
        statusColor = const Color(0xFFFFA500); // Orange
        statusText = 'Nouvelle';
        break;
      case 'accepted':
        statusColor = const Color(0xFF2196F3); // Bleu
        statusText = 'Acceptée';
        break;
      case 'picked_up':
        statusColor = AppColors.primary; // Orange
        statusText = 'Récupérée';
        break;
      case 'delivered':
        statusColor = const Color(0xFF4CD964); // Vert
        statusText = 'Livrée';
        break;
      default:
        statusColor = Colors.grey;
        statusText = delivery.status;
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
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
