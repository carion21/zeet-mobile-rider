// lib/screens/notifications/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/models/notification_model.dart';
import 'package:rider/providers/notifications_provider.dart';
import 'package:rider/providers/connectivity_provider.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Set pour tracker les IDs des notifications expandees
  final Set<int> _expandedNotifications = {};

  @override
  void initState() {
    super.initState();
    // Charger les notifications + le badge au montage de l'ecran.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsListProvider.notifier).load();
      ref.read(unreadCountProvider.notifier).refresh();
    });
  }

  Future<void> _toggleExpand(NotificationModel notification) async {
    final id = notification.id;
    final wasExpanded = _expandedNotifications.contains(id);
    setState(() {
      if (wasExpanded) {
        _expandedNotifications.remove(id);
      } else {
        _expandedNotifications.add(id);
      }
    });

    // Marquer comme lue + ack a l'ouverture (stoppe la cascade cote backend).
    if (!wasExpanded && !notification.isRead) {
      await ref
          .read(notificationsListProvider.notifier)
          .acknowledge(id);
    }
  }

  Future<void> _markAllAsRead() async {
    await ref.read(notificationsListProvider.notifier).markAllAsRead();
  }

  Future<void> _refresh() async {
    await ref.read(notificationsListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    AppSizes().initialize(context);

    final listState = ref.watch(notificationsListProvider);
    final unreadState = ref.watch(unreadCountProvider);
    final notifications = listState.items;
    final unreadCount = unreadState.count;

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
          if (unreadCount > 0)
            TextButton(
              onPressed: listState.isOperating ? null : _markAllAsRead,
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: _buildBody(
          listState,
          notifications,
          surfaceColor,
          textColor,
          textLightColor,
          isDarkMode,
        ),
      ),
    );
  }

  Widget _buildBody(
    NotificationsListState state,
    List<NotificationModel> notifications,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    final bool isOnline = ref
        .watch(connectivityStatusProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);

    return ZeetScreenScaffold(
      state: _resolveState(state, notifications, isOnline),
      onRetry: _refresh,
      emptyTitle: 'Pas de notification',
      emptySubtitle: "On te préviendra dès qu'il y a du nouveau",
      emptyIcon: Icons.notifications_none_outlined,
      errorMessage: state.errorMessage,
      child: ListView.builder(
        padding: EdgeInsets.all(AppSizes().paddingLarge),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
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

  ZeetScreenState _resolveState(
    NotificationsListState state,
    List<NotificationModel> notifications,
    bool isOnline,
  ) {
    if (state.isLoading && notifications.isEmpty) {
      return ZeetScreenState.loading;
    }
    if (!isOnline && notifications.isEmpty) {
      return ZeetScreenState.offline;
    }
    if (state.errorMessage != null && notifications.isEmpty) {
      return ZeetScreenState.error;
    }
    if (notifications.isEmpty) {
      return ZeetScreenState.empty;
    }
    return ZeetScreenState.content;
  }

  Widget _buildNotificationCard(
    NotificationModel notification,
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode,
  ) {
    final isExpanded = _expandedNotifications.contains(notification.id);

    // Determiner l'icone et la couleur selon le type
    String iconName;
    Color iconColor;

    switch (notification.type) {
      case 'new_delivery':
      case 'mission_assigned':
      case 'delivery_assigned':
        iconName = 'delivery';
        iconColor = AppColors.primary;
        break;
      case 'delivery_update':
      case 'mission_update':
        iconName = 'info';
        iconColor = const Color(0xFF2196F3);
        break;
      case 'payment':
      case 'earnings':
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
            onTap: () => _toggleExpand(notification),
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
                        // Icone
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
                                      notification.title ??
                                          'Notification',
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
                                      decoration: const BoxDecoration(
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
                                overflow: isExpanded
                                    ? null
                                    : TextOverflow.ellipsis,
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

                  // Partie expandable
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          height: 1,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 12),
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
                        if ((notification.type == 'new_delivery' ||
                                notification.type == 'mission_assigned' ||
                                notification.type == 'delivery_assigned') &&
                            notification.data != null)
                          Column(
                            children: [
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Navigation vers le détail de mission
                                    // (quickwin vague 3 §QW4). On extrait le
                                    // mission_id du payload `data` de la notif.
                                    final data = notification.data;
                                    final missionId = data?['mission_id']?.toString() ??
                                        data?['missionId']?.toString() ??
                                        data?['delivery_id']?.toString() ??
                                        data?['deliveryId']?.toString() ??
                                        data?['order_id']?.toString() ??
                                        data?['orderId']?.toString();
                                    if (missionId != null && missionId.isNotEmpty) {
                                      Routes.pushMissionDetails(missionId: missionId);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: iconColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
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

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'new_delivery':
      case 'mission_assigned':
      case 'delivery_assigned':
        return 'Nouvelle';
      case 'delivery_update':
      case 'mission_update':
        return 'Mise a jour';
      case 'payment':
      case 'earnings':
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
      return DateFormat('dd/MM/yyyy a HH:mm').format(dateTime);
    }
  }
}
