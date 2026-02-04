import 'package:flutter/material.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:toastification/toastification.dart';


/// Enum pour différencier les types de messages dans le toast
enum ToastType {
  /// Message d'information (bleu)
  info,

  /// Message de succès (vert)
  success,

  /// Message d'avertissement (orange)
  warning,

  /// Message d'erreur (rouge)
  error,
}

/// Classe pour gérer l'affichage de toasts personnalisés
class AppToast {
  /// Affiche un toast personnalisé
  static void show({
    required BuildContext context,
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
    String? actionLabel,
    VoidCallback? onAction,
    bool dismissible = true,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Couleurs selon le type
    Color primaryColor;
    IconData iconData;
    String typeLabel;

    switch (type) {
      case ToastType.info:
        primaryColor = const Color(0xFF2196F3);
        iconData = IconManager.getIconData('info');
        typeLabel = 'Info';
        break;
      case ToastType.success:
        primaryColor = const Color(0xFF4CD964);
        iconData = IconManager.getIconData('success');
        typeLabel = 'Succès';
        break;
      case ToastType.warning:
        primaryColor = AppColors.primary;
        iconData = IconManager.getIconData('warning');
        typeLabel = 'Attention';
        break;
      case ToastType.error:
        primaryColor = AppColors.error;
        iconData = IconManager.getIconData('error');
        typeLabel = 'Erreur';
        break;
    }

    // Couleurs adaptatives
    final backgroundColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;

    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.minimal,
      alignment: Alignment.topCenter,
      autoCloseDuration: duration,
      animationDuration: const Duration(milliseconds: 500),
      animationBuilder: (context, animation, alignment, child) {
        // Animation combinée : scale + slide + fade pour un effet fluide
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.5),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        );
      },
      // Widget personnalisé pour le toast
      title: _ToastContent(
        message: message,
        primaryColor: primaryColor,
        iconData: iconData,
        typeLabel: typeLabel,
        textColor: textColor,
        isDarkMode: isDarkMode,
        onClose: dismissible ? onClose : null,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      primaryColor: primaryColor,
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withValues(alpha: isDarkMode ? 0.2 : 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ],
      showProgressBar: true,
      progressBarTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: primaryColor.withValues(alpha: 0.15),
        linearMinHeight: 3,
      ),
      showIcon: false,
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: dismissible,
      applyBlurEffect: false,
      callbacks: ToastificationCallbacks(onTap: (toastItem) {}, onCloseButtonTap: (toastItem) => onClose?.call()),
    );
  }

  /// Affiche un toast d'info (bleu)
  static void showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
  }) {
    show(context: context, message: message, type: ToastType.info, duration: duration, onClose: onClose);
  }

  /// Affiche un toast de succès (vert)
  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
  }) {
    show(context: context, message: message, type: ToastType.success, duration: duration, onClose: onClose);
  }

  /// Affiche un toast d'avertissement (orange)
  static void showWarning({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
  }) {
    show(context: context, message: message, type: ToastType.warning, duration: duration, onClose: onClose);
  }

  /// Affiche un toast d'erreur (rouge)
  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onClose,
  }) {
    show(context: context, message: message, type: ToastType.error, duration: duration, onClose: onClose);
  }
}

/// Widget personnalisé pour le contenu du toast
class _ToastContent extends StatelessWidget {
  final String message;
  final Color primaryColor;
  final IconData iconData;
  final String typeLabel;
  final Color textColor;
  final bool isDarkMode;
  final VoidCallback? onClose;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ToastContent({
    required this.message,
    required this.primaryColor,
    required this.iconData,
    required this.typeLabel,
    required this.textColor,
    required this.isDarkMode,
    this.onClose,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icône avec fond coloré et bordures arrondies
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(iconData, color: primaryColor, size: 22),
          ),

          const SizedBox(width: 12),

          // Contenu du message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label du type (Info, Succès, etc.)
                Text(
                  typeLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor, letterSpacing: 0.5),
                ),

                const SizedBox(height: 4),

                // Message principal
                Text(
                  message,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textColor, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // Bouton d'action optionnel
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Text(
                        actionLabel!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bouton de fermeture
          if (onClose != null) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    IconManager.getIconData('close'),
                    size: 18,
                    color: isDarkMode ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
