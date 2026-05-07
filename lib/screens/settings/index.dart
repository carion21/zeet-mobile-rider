// lib/screens/settings/index.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/links.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/screens/settings/widgets/notification_preferences_card.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/providers/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Toggles notifs/son/vibration deplaces dans NotificationPreferencesCard
  // (vraies preferences persistees + heures silencieuses).
  bool _locationAlwaysOn = false;
  String _language = 'Français';
  String _mapStyle = 'Standard';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final themeMode = ref.watch(themeModeProvider);

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
          'Paramètres',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Apparence
            _buildSectionTitle('Apparence', textColor),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              surfaceColor,
              textColor,
              textLightColor,
              isDarkMode,
              children: [
                _buildThemeOption(
                  title: 'Clair',
                  icon: 'sun',
                  isSelected: themeMode == ThemeMode.light,
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                  },
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildThemeOption(
                  title: 'Sombre',
                  icon: 'moon',
                  isSelected: themeMode == ThemeMode.dark,
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                  },
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildThemeOption(
                  title: 'Système',
                  icon: 'phone_android',
                  isSelected: themeMode == ThemeMode.system,
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                  },
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Section Notifications — opt-in granulaire par channel +
            // heures silencieuses persistees. Skill `zeet-notification
            // -strategy` §9.
            _buildSectionTitle('Notifications', textColor),
            SizedBox(height: 12.h),
            const NotificationPreferencesCard(),

            SizedBox(height: 24.h),

            // Section Localisation
            _buildSectionTitle('Localisation', textColor),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              surfaceColor,
              textColor,
              textLightColor,
              isDarkMode,
              children: [
                _buildSwitchOption(
                  title: 'Localisation continue',
                  subtitle: 'Activer en arrière-plan',
                  icon: 'location',
                  value: _locationAlwaysOn,
                  onChanged: (value) {
                    setState(() => _locationAlwaysOn = value);
                    AppToast.showInfo(
                      context: context,
                      message: value
                          ? 'Localisation continue activée'
                          : 'Localisation à la demande',
                    );
                  },
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Style de carte',
                  subtitle: _mapStyle,
                  icon: 'location_on',
                  onTap: () {
                    _showMapStyleDialog(surfaceColor, textColor, textLightColor);
                  },
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Section Langue
            _buildSectionTitle('Langue et région', textColor),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              surfaceColor,
              textColor,
              textLightColor,
              isDarkMode,
              children: [
                _buildTapOption(
                  title: 'Langue',
                  subtitle: _language,
                  icon: 'language',
                  onTap: () {
                    _showLanguageDialog(surfaceColor, textColor, textLightColor);
                  },
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Section Aide & support — pages publiques hébergées sur
            // zeet.geasscorp.com. Ouverture en navigateur externe pour
            // respecter App Review Guideline 5.1.1.
            _buildSectionTitle('Aide & support', textColor),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              surfaceColor,
              textColor,
              textLightColor,
              isDarkMode,
              children: [
                _buildTapOption(
                  title: 'Aide & FAQ',
                  subtitle: 'Centre d\'aide en ligne',
                  icon: 'help',
                  onTap: () => _openExternal(ZeetLinks.support),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Nous contacter',
                  subtitle: 'Support ZEET',
                  icon: 'message',
                  onTap: () => _openExternal(ZeetLinks.supportContact),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Sécurité & confiance',
                  subtitle: 'Engagements ZEET',
                  icon: 'shield',
                  onTap: () => _openExternal(ZeetLinks.safety),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Règles communauté',
                  subtitle: 'Charte ZEET',
                  icon: 'document',
                  onTap: () => _openExternal(ZeetLinks.communityRules),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Section Compte
            _buildSectionTitle('Compte', textColor),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              surfaceColor,
              textColor,
              textLightColor,
              isDarkMode,
              children: [
                _buildTapOption(
                  title: 'Supprimer mon compte',
                  subtitle: 'Procédure RGPD',
                  icon: 'delete_outline',
                  onTap: () => _openExternal(ZeetLinks.accountDeletion),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Section Légal — pages publiques hébergées sur
            // zeet.geasscorp.com (URLs centralisées dans
            // core/constants/links.dart). Ouverture en navigateur
            // externe pour respecter App Review Guideline 5.1.1.
            _buildSectionTitle('Légal', textColor),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              surfaceColor,
              textColor,
              textLightColor,
              isDarkMode,
              children: [
                _buildTapOption(
                  title: 'Politique de confidentialité',
                  subtitle: 'Données personnelles',
                  icon: 'privacy',
                  onTap: () => _openExternal(ZeetLinks.privacy),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Conditions d\'utilisation',
                  subtitle: 'CGU',
                  icon: 'document',
                  onTap: () => _openExternal(ZeetLinks.terms),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Conditions générales de vente',
                  subtitle: 'CGV',
                  icon: 'document',
                  onTap: () => _openExternal(ZeetLinks.salesTerms),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Politique cookies',
                  subtitle: 'Gestion cookies',
                  icon: 'document',
                  onTap: () => _openExternal(ZeetLinks.cookies),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Mentions légales',
                  subtitle: 'Éditeur ZEET',
                  icon: 'info',
                  onTap: () => _openExternal(ZeetLinks.legalNotice),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Section À propos
            _buildSectionTitle('À propos', textColor),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              surfaceColor,
              textColor,
              textLightColor,
              isDarkMode,
              children: [
                _buildTapOption(
                  title: 'À propos de ZEET',
                  subtitle: 'Notre mission',
                  icon: 'info',
                  onTap: () => _openExternal(ZeetLinks.about),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Version de l\'application',
                  subtitle: '1.0.0',
                  icon: 'info',
                  onTap: () {},
                  showArrow: false,
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Conditions d\'utilisation',
                  subtitle: 'Voir les conditions',
                  icon: 'document',
                  onTap: () => _openExternal(ZeetLinks.terms),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
                Divider(height: 1, color: textLightColor.withValues(alpha: 0.1)),
                _buildTapOption(
                  title: 'Politique de confidentialité',
                  subtitle: 'Voir la politique',
                  icon: 'privacy',
                  onTap: () => _openExternal(ZeetLinks.privacy),
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
            ),

            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppToast.showError(
        context: context,
        message: 'Impossible d\'ouvrir le lien.',
      );
    }
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    Color surfaceColor,
    Color textColor,
    Color textLightColor,
    bool isDarkMode, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    required Color textLightColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : textLightColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: IconManager.getIcon(
                icon,
                color: isSelected ? AppColors.primary : textLightColor,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 22.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchOption({
    required String title,
    required String subtitle,
    required String icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textColor,
    required Color textLightColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: textLightColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: IconManager.getIcon(
              icon,
              color: textLightColor,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textLightColor,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTapOption({
    required String title,
    required String subtitle,
    required String icon,
    required VoidCallback onTap,
    required Color textColor,
    required Color textLightColor,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: textLightColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: IconManager.getIcon(
                icon,
                color: textLightColor,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textLightColor,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              IconManager.getIcon(
                'arrow_forward_ios',
                color: textLightColor,
                size: 16.sp,
              ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(Color surfaceColor, Color textColor, Color textLightColor) {
    // Bottom sheet (UX rider coherente) plutot qu'AlertDialog natif.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: textLightColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
                child: Text(
                  'Choisir la langue',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildLanguageOption('Français', surfaceColor, textColor, textLightColor),
              _buildLanguageOption('English', surfaceColor, textColor, textLightColor),
              _buildLanguageOption('العربية', surfaceColor, textColor, textLightColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String lang, Color surfaceColor, Color textColor, Color textLightColor) {
    final isSelected = _language == lang;
    return InkWell(
      onTap: () {
        setState(() => _language = lang);
        Navigator.pop(context);
        AppToast.showSuccess(
          context: context,
          message: 'Langue changée : $lang',
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lang,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : textColor,
                  fontSize: 15.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: AppColors.primary, size: 20.sp),
          ],
        ),
      ),
    );
  }

  void _showMapStyleDialog(Color surfaceColor, Color textColor, Color textLightColor) {
    // Bottom sheet coherent avec le picker de langue.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: textLightColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
                child: Text(
                  'Style de carte',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildMapStyleOption('Standard', surfaceColor, textColor, textLightColor),
              _buildMapStyleOption('Satellite', surfaceColor, textColor, textLightColor),
              _buildMapStyleOption('Terrain', surfaceColor, textColor, textLightColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapStyleOption(String style, Color surfaceColor, Color textColor, Color textLightColor) {
    final isSelected = _mapStyle == style;
    return InkWell(
      onTap: () {
        setState(() => _mapStyle = style);
        Navigator.pop(context);
        AppToast.showSuccess(
          context: context,
          message: 'Style de carte : $style',
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                style,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : textColor,
                  fontSize: 15.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: AppColors.primary, size: 20.sp),
          ],
        ),
      ),
    );
  }
}
