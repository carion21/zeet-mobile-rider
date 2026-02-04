import 'package:flutter/material.dart';

class AppSizes {
  // Singleton pattern propre
  static final AppSizes _instance = AppSizes._internal();
  factory AppSizes() => _instance;
  AppSizes._internal();

  late double _screenWidth;
  late double _screenHeight;
  late double _blockWidth;
  late double _blockHeight;
  late double _safeBlockWidth;
  late double _safeBlockHeight;

  bool _isInitialized = false;

  /// À appeler dans le `build()` d'un widget racine (Splash, AppWrapper, etc.)
  void initialize(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;

    _blockWidth = _screenWidth / 100;
    _blockHeight = _screenHeight / 100;

    final safeHorizontal = mediaQuery.padding.left + mediaQuery.padding.right;
    final safeVertical = mediaQuery.padding.top + mediaQuery.padding.bottom;

    _safeBlockWidth = (_screenWidth - safeHorizontal) / 100;
    _safeBlockHeight = (_screenHeight - safeVertical) / 100;

    _isInitialized = true;
  }

  void _ensureInitialized() {
    assert(_isInitialized, 'AppSizes n\'est pas initialisé. Appelez AppSizes().initialize(context) au lancement.');
  }

  // Dimensions
  double get screenWidth {
    _ensureInitialized();
    return _screenWidth;
  }

  double get screenHeight {
    _ensureInitialized();
    return _screenHeight;
  }

  double percentWidth(double percent) {
    _ensureInitialized();
    return _safeBlockWidth * percent;
  }

  double percentHeight(double percent) {
    _ensureInitialized();
    return _safeBlockHeight * percent;
  }

  double fullPercentWidth(double percent) {
    _ensureInitialized();
    return _blockWidth * percent;
  }

  double fullPercentHeight(double percent) {
    _ensureInitialized();
    return _blockHeight * percent;
  }

  // Font sizes responsives - Optimisé selon Material Design 3 et best practices 2024
  double scaledFontSize(double size) {
    _ensureInitialized();
    double scaleFactor = _screenWidth / 375.0; // iPhone 11 Pro width ref
    return size * scaleFactor;
  }

  // Titres (Headers)
  double get h1 => scaledFontSize(24.0);  // Titres principaux
  double get h2 => scaledFontSize(20.0);  // Sous-titres
  double get h3 => scaledFontSize(18.0);  // Titres tertiaires

  // Corps de texte (Body)
  double get bodyLarge => scaledFontSize(16.0);   // Texte important
  double get bodyMedium => scaledFontSize(14.0);  // Texte standard (le plus utilisé)
  double get bodySmall => scaledFontSize(12.0);   // Texte secondaire

  // Labels et boutons
  double get buttonText => scaledFontSize(15.0);  // Texte de boutons
  double get label => scaledFontSize(13.0);       // Labels de champs
  double get caption => scaledFontSize(11.0);     // Informations très secondaires

  // Line heights
  double get lineHeightLarge => 1.6;
  double get lineHeightMedium => 1.5;
  double get lineHeightSmall => 1.4;

  // Letter spacing
  double get spacingTight => -0.25;
  double get spacingMedium => 0.0;
  double get spacingWide => 0.5;

  // Responsive paddings
  double get paddingSmall => percentWidth(2.0);   // ~8.0
  double get paddingMedium => percentWidth(3.0);  // ~12.0
  double get paddingLarge => percentWidth(4.0);   // ~16.0
  double get paddingXLarge => percentWidth(6.0);  // ~24.0

  // Radii
  double get radiusSmall => 8.0;
  double get radiusMedium => 16.0;

  // Elevation
  double get elevationSmall => 2.0;
}
