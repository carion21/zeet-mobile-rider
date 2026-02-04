// lib/screens/profile/index.dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/core/widgets/app_popup.dart';
import 'package:rider/services/navigation_service.dart';
import 'controllers.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController();
    _controller.initControllers();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleOnlineStatus() async {
    setState(() => _controller.isLoading = true);

    final result = await _controller.toggleOnlineStatus();

    if (!mounted) return;
    setState(() => _controller.isLoading = false);

    if (result['success']) {
      AppToast.showSuccess(
        context: context,
        message: result['message'],
      );
    } else {
      AppToast.showError(
        context: context,
        message: result['message'],
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_controller.formKey.currentState!.validate()) return;

    setState(() => _controller.isLoading = true);

    final result = await _controller.saveChanges();

    if (!mounted) return;
    setState(() => _controller.isLoading = false);

    if (result['success']) {
      AppToast.showSuccess(
        context: context,
        message: result['message'],
      );
    } else {
      AppToast.showError(
        context: context,
        message: result['message'],
      );
    }
  }

  Future<void> _confirmLogout() async {
    final bool? confirm = await AppPopup.showConfirmation(
      context: context,
      title: 'Déconnexion',
      message: 'Êtes-vous sûr de vouloir vous déconnecter ?',
      confirmLabel: 'Déconnexion',
      cancelLabel: 'Annuler',
      isDestructive: true,
    );

    if (confirm == true) {
      final result = await _controller.logout();

      if (!mounted) return;
      if (result['success']) {
        AppToast.showSuccess(
          context: context,
          message: result['message'],
        );

        // Rediriger vers la page de connexion
        Routes.navigateAndRemoveAll(Routes.login);
      } else {
        AppToast.showError(
          context: context,
          message: result['message'],
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppSizes().initialize(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : const Color(0xFFF8F8F8);
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final borderColor = isDarkMode ? AppColors.darkTextLight.withOpacity(0.2) : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'Mon Profil',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_controller.isEditing)
            IconButton(
              icon: IconManager.getIcon(
                'edit',
                color: textColor,
              ),
              onPressed: () {
                setState(() {
                  _controller.isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: IconManager.getIcon(
                'close',
                color: textColor,
              ),
              onPressed: () {
                setState(() {
                  _controller.isEditing = false;
                  _controller.initControllers(); // Réinitialiser les valeurs
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(AppSizes().paddingLarge),
            child: Form(
              key: _controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar et nom
                  _buildProfileHeader(textColor, surfaceColor),

                  SizedBox(height: AppSizes().paddingLarge),

                  // Statut et statistiques du livreur
                  _buildStatusAndStatsCard(textColor, textLightColor, surfaceColor),

                  SizedBox(height: AppSizes().paddingXLarge),

                  // Informations de profil
                  if (_controller.isEditing)
                    _buildProfileInfos(
                      textColor,
                      textLightColor,
                      surfaceColor,
                      borderColor,
                    ),

                  if (_controller.isEditing)
                    SizedBox(height: AppSizes().paddingXLarge),

                  // Bouton d'enregistrement (visible uniquement en mode édition)
                  if (_controller.isEditing)
                    _buildSaveButton(),

                  if (_controller.isEditing)
                    SizedBox(height: AppSizes().paddingLarge),

                  // Menu d'options de profil
                  _buildProfileOptions(
                    textColor,
                    textLightColor,
                    surfaceColor,
                  ),

                  SizedBox(height: AppSizes().paddingXLarge),

                  // Bouton de déconnexion
                  _buildLogoutButton(textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Color textColor, Color surfaceColor) {
    return Column(
      children: [
        // Avatar avec initiales
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _controller.initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Nom de l'utilisateur
        Text(
          _controller.userName,
          style: TextStyle(
            color: textColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Numéro de téléphone
        const SizedBox(height: 4),
        Text(
          _controller.phoneNumber,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusAndStatsCard(Color textColor, Color textLightColor, Color surfaceColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Statut en ligne/hors ligne
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _controller.isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statut',
                        style: TextStyle(
                          color: textLightColor,
                          fontSize: 12.sp,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _controller.isOnline ? 'En ligne' : 'Hors ligne',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _controller.isOnline,
                onChanged: _controller.isLoading ? null : (value) => _toggleOnlineStatus(),
                activeColor: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: textLightColor.withOpacity(0.1),
          ),

          const SizedBox(height: 20),

          // Statistiques
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_controller.totalDeliveries}',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Livraisons',
                      style: TextStyle(
                        color: textLightColor,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${_controller.averageRating.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Note moyenne',
                      style: TextStyle(
                        color: textLightColor,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfos(
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email
        _buildInputField(
          controller: _controller.emailController,
          focusNode: _controller.emailFocusNode,
          label: 'Adresse email',
          hintText: 'Entrez votre adresse email',
          prefixIcon: 'email',
          keyboardType: TextInputType.emailAddress,
          validator: _controller.validateEmail,
          isEnabled: _controller.isEditing,
          textColor: textColor,
          textLightColor: textLightColor,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
    required String prefixIcon,
    required bool isEnabled,
    required Color textColor,
    required Color textLightColor,
    required Color surfaceColor,
    required Color borderColor,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: isEnabled,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: textLightColor.withOpacity(0.6),
              fontSize: 14.sp,
            ),
            prefixIcon: IconManager.getIcon(
              prefixIcon,
              color: textLightColor,
              size: 18,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: borderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isEnabled ? surfaceColor : textLightColor.withOpacity(0.05),
          ),
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: textColor,
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _controller.isLoading ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          disabledForegroundColor: Colors.white.withOpacity(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _controller.isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                'Enregistrer',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildProfileOptions(
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildProfileOption(
            title: 'Mes livraisons',
            icon: 'history',
            onTap: () => Routes.navigateTo(Routes.deliveries),
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Notifications',
            icon: 'notifications',
            onTap: () => Routes.navigateTo(Routes.notifications),
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Statistiques',
            icon: 'trending_up',
            onTap: () => Routes.navigateTo(Routes.stats),
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Paramètres',
            icon: 'settings',
            onTap: () => Routes.navigateTo(Routes.settings),
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Aide et support',
            icon: 'help',
            onTap: () => Routes.navigateTo(Routes.support),
            showDivider: false,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required String title,
    required String icon,
    required Function() onTap,
    required bool showDivider,
    required Color textColor,
    required Color textLightColor,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: IconManager.getIcon(
                      icon,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconManager.getIcon(
                  'arrow_forward',
                  color: textLightColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 56,
            endIndent: 16,
            color: textLightColor.withOpacity(0.1),
          ),
      ],
    );
  }

  Widget _buildLogoutButton(Color textColor) {
    return TextButton.icon(
      onPressed: _confirmLogout,
      icon: IconManager.getIcon(
        'logout',
        color: Colors.red,
        size: 20,
      ),
      label: Text(
        'Déconnexion',
        style: TextStyle(
          color: Colors.red,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
