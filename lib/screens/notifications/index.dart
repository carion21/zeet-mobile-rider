// lib/screens/notifications/index.dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/models/notification_model.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Set pour tracker les IDs des notifications expandues
  final Set<String> _expandedNotifications = {};

  // Exemples de notifications
  final List<NotificationModel> _notifications = [
    NotificationModel(
      id: 'N001',
      title: 'Nouvelle livraison disponible',
      message: 'Une nouvelle commande est disponible à Cocody. 1500 F',
      type: 'new_delivery',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: false,
      data: {'deliveryId': 'DLV001'},
    ),
    NotificationModel(
      id: 'N002',
      title: 'Paiement reçu',
      message: 'Vous avez reçu 15750 F pour les livraisons d\'aujourd\'hui',
      type: 'payment',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
    ),
    NotificationModel(
      id: 'N003',
      title: 'Livraison terminée',
      message: 'La livraison #DLV002 a été marquée comme terminée',
      type: 'delivery_update',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
    NotificationModel(
      id: 'N004',
      title: 'Rappel',
      message: 'N\'oubliez pas de mettre à jour votre disponibilité',
      type: 'info',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
  ];

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedNotifications.contains(id)) {
        _expandedNotifications.remove(id);
      } else {
        _expandedNotifications.add(id);
        // Marquer comme lu lors de l'expansion
        _markAsRead(id);
      }
    });
  }

  void _markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      setState(() {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      });
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    });
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
          'Notifications',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Tout marquer comme lu',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState(textColor, textLightColor)
          : ListView.builder(
              padding: EdgeInsets.all(AppSizes().paddingLarge),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationCard(
                  notification,
                  surfaceColor,
                  textColor,
                  textLightColor,
                  isDarkMode,
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color textLightColor) {
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
              'notifications',
              color: Colors.grey.shade400,
              size: 52,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune notification',
            style: TextStyle(
              color: textColor,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous n\'avez aucune notification pour le moment',
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

  Widget _buildNotificationCard(
    NotificationModel notification,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    final isExpanded = _expandedNotifications.contains(notification.id);

    // Déterminer l'icône et la couleur selon le type
    String iconName;
    Color iconColor;

    switch (notification.type) {
      case 'new_delivery':
        iconName = 'delivery';
        iconColor = AppColors.primary;
        break;
      case 'delivery_update':
        iconName = 'info';
        iconColor = const Color(0xFF2196F3);
        break;
      case 'payment':
        iconName = 'wallet';
        iconColor = const Color(0xFF4CD964);
        break;
      case 'info':
      default:
        iconName = 'info';
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead
            ? surfaceColor
            : (isDarkMode
                ? AppColors.primary.withValues(alpha: 0.05)
                : AppColors.primary.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleExpand(notification.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Partie toujours visible (hauteur fixe)
                  SizedBox(
                    height: 70,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icône avec animation de scale subtile
                        AnimatedScale(
                          scale: isExpanded ? 1.02 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconManager.getIcon(
                              iconName,
                              color: iconColor,
                              size: 24,
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Contenu
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notification.title,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!notification.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notification.message,
                                style: TextStyle(
                                  color: textLightColor,
                                  fontSize: 13.sp,
                                  height: 1.4,
                                ),
                                maxLines: isExpanded ? null : 2,
                                overflow: isExpanded ? null : TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Indicateur d'expansion
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: IconManager.getIcon(
                            'keyboard_arrow_down',
                            color: textLightColor,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Partie expandable avec animation
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // Divider
                        Container(
                          height: 1,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.15),
                        ),

                        const SizedBox(height: 12),

                        // Informations supplémentaires
                        Row(
                          children: [
                            IconManager.getIcon(
                              'clock',
                              color: textLightColor.withValues(alpha: 0.7),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(notification.createdAt),
                              style: TextStyle(
                                color: textLightColor.withValues(alpha: 0.7),
                                fontSize: 12.sp,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getTypeLabel(notification.type),
                                style: TextStyle(
                                  color: iconColor,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Bouton d'action si applicable
                        if (notification.type == 'new_delivery' && notification.data != null)
                          Column(
                            children: [
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // TODO: Navigation vers la livraison
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: iconColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'Voir la livraison',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                    sizeCurve: Curves.easeInOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'new_delivery':
        return 'Nouvelle';
      case 'delivery_update':
        return 'Mise à jour';
      case 'payment':
        return 'Paiement';
      case 'info':
      default:
        return 'Info';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return DateFormat('dd/MM/yyyy à HH:mm').format(dateTime);
    }
  }
}
