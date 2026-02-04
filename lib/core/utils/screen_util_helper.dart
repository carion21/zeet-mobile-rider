// lib/core/utils/screen_util_helper.dart
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Helper class pour faciliter l'utilisation de ScreenUtil dans l'application
///
/// ScreenUtil est configuré avec une taille de design de 375x812 (iPhone 11 Pro)
///
/// Exemples d'utilisation:
///
/// 1. Adaptation de taille:
///    - width: 100.w  // 100 unités logiques de largeur
///    - height: 50.h  // 50 unités logiques de hauteur
///
/// 2. Adaptation de police:
///    - fontSize: 14.sp  // Taille de police adaptative
///
/// 3. Adaptation de rayon:
///    - borderRadius: BorderRadius.circular(8.r)
///
/// 4. Tailles d'écran:
///    - 1.sw  // Largeur totale de l'écran
///    - 1.sh  // Hauteur totale de l'écran
///    - 0.5.sw  // 50% de la largeur de l'écran
///
/// 5. EdgeInsets adaptatifs:
///    - EdgeInsets.all(16.w)
///    - EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h)
///
/// 6. SizedBox adaptatif:
///    - SizedBox(width: 10.w, height: 10.h)
///    - 10.horizontalSpace  // SizedBox avec width
///    - 10.verticalSpace    // SizedBox avec height
class ScreenUtilHelper {
  // ===== TAILLES DE POLICE - Optimisé Material Design 3 & Best Practices 2024 =====

  /// Titres principaux (h1) - Headers, Écrans
  static double get h1FontSize => 24.sp;

  /// Sous-titres (h2) - Sections principales
  static double get h2FontSize => 20.sp;

  /// Titres tertiaires (h3) - Sous-sections
  static double get h3FontSize => 18.sp;

  /// Texte important - Contenu mis en avant
  static double get bodyLargeFontSize => 16.sp;

  /// Texte standard (le plus utilisé) - Contenu principal
  static double get bodyMediumFontSize => 14.sp;

  /// Texte secondaire - Informations complémentaires
  static double get bodySmallFontSize => 12.sp;

  /// Texte de boutons - Boutons et CTA
  static double get buttonTextSize => 15.sp;

  /// Labels de champs - Formulaires
  static double get labelSize => 13.sp;

  /// Informations très secondaires - Timestamps, métadonnées
  static double get captionSize => 11.sp;

  /// Padding petit
  static double get paddingSmall => 8.w;

  /// Padding moyen
  static double get paddingMedium => 16.w;

  /// Padding large
  static double get paddingLarge => 24.w;

  /// Padding extra large
  static double get paddingXLarge => 32.w;

  /// Rayon de bordure petit
  static double get radiusSmall => 8.r;

  /// Rayon de bordure moyen
  static double get radiusMedium => 12.r;

  /// Rayon de bordure large
  static double get radiusLarge => 16.r;

  /// Taille d'icône petit
  static double get iconSizeSmall => 16.sp;

  /// Taille d'icône moyen
  static double get iconSizeMedium => 24.sp;

  /// Taille d'icône large
  static double get iconSizeLarge => 32.sp;

  /// Largeur de l'écran
  static double get screenWidth => 1.sw;

  /// Hauteur de l'écran
  static double get screenHeight => 1.sh;

  /// Pourcentage de la largeur
  static double widthPercent(double percent) => percent.sw;

  /// Pourcentage de la hauteur
  static double heightPercent(double percent) => percent.sh;
}
