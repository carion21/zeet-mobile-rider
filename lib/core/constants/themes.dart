import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';

class AppTheme {
  static const BorderRadius _defaultBorderRadius = BorderRadius.all(Radius.circular(8));
  static const double _defaultElevation = 1.0;

  static ThemeData _baseTheme(BuildContext context, ColorScheme colorScheme, Brightness brightness) {
    // Initialisation des tailles responsives
    AppSizes().initialize(context);

    // TextTheme avec Roboto - Police Material Design officielle
    final textTheme = GoogleFonts.robotoTextTheme().copyWith(
      // Titres principaux (Roboto Bold)
      displayLarge: GoogleFonts.roboto(
        fontSize: AppSizes().h1,        // 24sp
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.roboto(
        fontSize: AppSizes().h2,        // 20sp
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      headlineSmall: GoogleFonts.roboto(
        fontSize: AppSizes().h3,        // 18sp
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),

      // Corps de texte (Roboto Regular)
      bodyLarge: GoogleFonts.roboto(
        fontSize: AppSizes().bodyLarge,   // 16sp
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.roboto(
        fontSize: AppSizes().bodyMedium,  // 14sp
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodySmall: GoogleFonts.roboto(
        fontSize: AppSizes().bodySmall,   // 12sp
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),

      // Labels et boutons (Roboto Medium)
      labelLarge: GoogleFonts.roboto(
        fontSize: AppSizes().buttonText,  // 15sp
        fontWeight: FontWeight.w500,
        color: colorScheme.primary,
      ),
      labelMedium: GoogleFonts.roboto(
        fontSize: AppSizes().label,       // 13sp
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      labelSmall: GoogleFonts.roboto(
        fontSize: AppSizes().caption,     // 11sp
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      textTheme: textTheme,

      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: _defaultElevation,
        shape: const RoundedRectangleBorder(borderRadius: _defaultBorderRadius),
        margin: EdgeInsets.all(AppSizes().paddingMedium),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: _defaultBorderRadius),
          ),
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(
              vertical: AppSizes().percentHeight(1.8),
              horizontal: AppSizes().percentWidth(4),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return colorScheme.primary.withOpacity(0.5);
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return colorScheme.onSurface.withOpacity(0.5);
            return colorScheme.onPrimary;
          }),
          elevation: WidgetStateProperty.all(_defaultElevation),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        fillColor: colorScheme.surface,
        filled: true,
        contentPadding: EdgeInsets.symmetric(
          vertical: AppSizes().percentHeight(1.6),
          horizontal: AppSizes().percentWidth(4),
        ),
        border: OutlineInputBorder(
          borderRadius: _defaultBorderRadius,
          borderSide: BorderSide(color: colorScheme.onSurface.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _defaultBorderRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: AppSizes().h3,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),

      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: AppSizes().percentWidth(6),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.error,
        contentTextStyle: GoogleFonts.roboto(
          fontSize: AppSizes().bodyMedium,
          color: colorScheme.onError,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: _defaultBorderRadius),
      ),

      // Autres thèmes (FloatingActionButton, Dialog, etc.) inchangés
    );
  }

  /// Thème clair
  static ThemeData lightTheme(BuildContext context) => _baseTheme(
    context,
    const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      secondary: Colors.blue,
      onSecondary: AppColors.white,
      background: Color(0xFFF5F5F5),
      onBackground: AppColors.text,
      surface: AppColors.white,
      onSurface: AppColors.text,
      surfaceVariant: Color(0xFFE0E0E0),
      onSurfaceVariant: Color(0xFF333333),
      error: AppColors.error,
      onError: AppColors.white,
    ),
    Brightness.light,
  );

  /// Thème sombre
  static ThemeData darkTheme(BuildContext context) => _baseTheme(
    context,
    const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      secondary: Colors.blue,
      onSecondary: AppColors.white,
      background: AppColors.darkBackground,
      onBackground: AppColors.darkText,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      surfaceVariant: Color(0xFF2E2E2E),
      onSurfaceVariant: AppColors.darkTextLight,
      error: AppColors.error,
      onError: AppColors.white,
    ),
    Brightness.dark,
  );
}
