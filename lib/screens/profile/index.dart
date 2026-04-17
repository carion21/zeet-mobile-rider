// lib/screens/profile/index.dart
//
// Ecran "Mon profil" du rider.
//
// Architecture :
// - Source de verite lecture : `currentRiderProvider` (auth_provider).
// - Mutation PATCH /v1/rider/profile : `profileEditProvider.save(...)`.
// - Mutation POST /v1/rider/profile/photo : `profileEditProvider.uploadPhoto(...)`.
// - Erreur specifique ERR_EMAIL_ALREADY_USED remontee via
//   `ProfileEditState.emailAlreadyUsed` -> toast + inline helper.
//
// Skills : zeet-pos-ergonomics (boutons larges, une main), zeet-micro-copy
// (ton rider efficace), zeet-states-elae (loader, error), zeet-neuro-ux
// (CTA primary saillant).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/widgets/app_popup.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/models/rider_model.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/providers/profile_provider.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:zeet_ui/zeet_ui.dart';
import 'package:rider/services/profile_service.dart';

import 'controllers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final ProfileController _controller;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = ProfileController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromRider());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _hydrateFromRider() {
    final rider = ref.read(currentRiderProvider);
    _controller.hydrate(
      firstname: rider?.firstname,
      lastname: rider?.lastname,
      email: rider?.email,
      gender: rider?.gender,
    );
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _toggleOnlineStatus() async {
    final result = await ref.read(statusProvider.notifier).toggleOnline();
    if (!mounted) return;

    if (result['success'] == true) {
      AppToast.showSuccess(
        context: context,
        message: result['message'] as String,
      );
    } else {
      AppToast.showError(
        context: context,
        message: result['message'] as String,
      );
    }
  }

  Future<void> _saveChanges() async {
    final formState = _controller.formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final rider = ref.read(currentRiderProvider);

    // Ne patche que les champs modifies, pour eviter les faux positifs et
    // limiter la charge serveur.
    String? firstname;
    String? lastname;
    String? email;
    String? gender;

    final newFirst = _controller.firstnameController.text.trim();
    final newLast = _controller.lastnameController.text.trim();
    final newEmail = _controller.emailController.text.trim();
    final newGender = _controller.gender;

    if (newFirst != (rider?.firstname ?? '')) {
      firstname = newFirst;
    }
    if (newLast != (rider?.lastname ?? '')) {
      lastname = newLast;
    }
    if (newEmail != (rider?.email ?? '')) {
      email = newEmail.isEmpty ? null : newEmail;
    }
    if (newGender != rider?.gender) {
      gender = newGender;
    }

    if (firstname == null &&
        lastname == null &&
        email == null &&
        gender == null) {
      AppToast.showInfo(
        context: context,
        message: 'Aucune modification a enregistrer',
      );
      setState(() => _controller.isEditing = false);
      return;
    }

    final result = await ref.read(profileEditProvider.notifier).save(
          firstname: firstname,
          lastname: lastname,
          email: email,
          gender: gender,
        );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() => _controller.isEditing = false);
      AppToast.showSuccess(
        context: context,
        message: result['message'] as String? ?? 'Profil mis a jour',
      );
    } else {
      AppToast.showError(
        context: context,
        message: result['message'] as String? ?? 'Erreur',
      );
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 90,
      );
      if (picked == null) return;

      final file = File(picked.path);

      // Validation client : taille max 5 MB.
      final size = await file.length();
      if (size > ProfileService.maxPhotoBytes) {
        if (!mounted) return;
        AppToast.showError(
          context: context,
          message: 'Fichier trop volumineux (max 5 MB).',
        );
        return;
      }

      // Validation client : extension valide.
      final lower = picked.path.toLowerCase();
      final isValidExt = lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp');
      if (!isValidExt) {
        if (!mounted) return;
        AppToast.showError(
          context: context,
          message: 'Format invalide. JPG, PNG ou WEBP uniquement.',
        );
        return;
      }

      final result =
          await ref.read(profileEditProvider.notifier).uploadPhoto(file);

      if (!mounted) return;

      if (result['success'] == true) {
        AppToast.showSuccess(
          context: context,
          message: result['message'] as String? ?? 'Photo mise a jour',
        );
      } else {
        AppToast.showError(
          context: context,
          message: result['message'] as String? ?? 'Echec de l\'upload',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(
        context: context,
        message: 'Impossible d\'ouvrir la galerie',
      );
    }
  }

  Future<void> _confirmLogout() async {
    final bool? confirm = await AppPopup.showConfirmation(
      context: context,
      title: 'Deconnexion',
      message: 'Etes-vous sur de vouloir vous deconnecter ?',
      confirmLabel: 'Deconnexion',
      cancelLabel: 'Annuler',
      isDestructive: true,
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      AppToast.showSuccess(
        context: context,
        message: 'Deconnexion reussie',
      );
      Routes.navigateAndRemoveAll(Routes.login);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final rider = ref.watch(currentRiderProvider);
    final statusState = ref.watch(statusProvider);
    final editState = ref.watch(profileEditProvider);

    AppSizes().initialize(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor =
        isDarkMode ? AppColors.darkBackground : const Color(0xFFF8F8F8);
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final borderColor = isDarkMode
        ? AppColors.darkTextLight.withOpacity(0.2)
        : const Color(0xFFEEEEEE);

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
              icon: IconManager.getIcon('edit', color: textColor),
              onPressed: () => setState(() => _controller.isEditing = true),
            )
          else
            IconButton(
              icon: IconManager.getIcon('close', color: textColor),
              onPressed: () {
                setState(() {
                  _controller.isEditing = false;
                  _hydrateFromRider();
                });
                ref.read(profileEditProvider.notifier).clearError();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(AppSizes().paddingLarge),
            child: Form(
              key: _controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildProfileHeader(
                    rider,
                    editState,
                    textColor,
                  ),
                  SizedBox(height: AppSizes().paddingLarge),
                  _buildStatusCard(
                    statusState.isOnline,
                    statusState.isLoading,
                    textColor,
                    textLightColor,
                    surfaceColor,
                  ),
                  SizedBox(height: AppSizes().paddingXLarge),
                  if (_controller.isEditing) ...[
                    _buildProfileForm(
                      editState,
                      textColor,
                      textLightColor,
                      surfaceColor,
                      borderColor,
                    ),
                    SizedBox(height: AppSizes().paddingLarge),
                    _buildSaveButton(editState),
                    SizedBox(height: AppSizes().paddingLarge),
                  ],
                  _buildProfileOptions(textColor, textLightColor, surfaceColor),
                  SizedBox(height: AppSizes().paddingXLarge),
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header avec avatar + bouton photo
  // ---------------------------------------------------------------------------

  Widget _buildProfileHeader(
    RiderModel? rider,
    ProfileEditState editState,
    Color textColor,
  ) {
    final photo = rider?.photo;
    final hasPhoto = photo != null && photo.isNotEmpty;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPhoto
                  ? ZeetImage(
                      url: photo,
                      fit: BoxFit.cover,
                      errorWidget: _buildInitialsAvatar(rider),
                    )
                  : _buildInitialsAvatar(rider),
            ),
            if (editState.isUploadingPhoto)
              Container(
                width: 100.w,
                height: 100.w,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: editState.isUploadingPhoto ? null : _pickAndUploadPhoto,
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    alignment: Alignment.center,
                    child: IconManager.getIcon(
                      'camera',
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Text(
          rider?.fullName.trim().isNotEmpty == true
              ? rider!.fullName
              : 'Rider',
          style: TextStyle(
            color: textColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          rider?.phone ?? '',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(RiderModel? rider) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Text(
        rider?.initials.isNotEmpty == true ? rider!.initials : 'R',
        style: TextStyle(
          color: Colors.white,
          fontSize: 32.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Statut online / offline
  // ---------------------------------------------------------------------------

  Widget _buildStatusCard(
    bool isOnline,
    bool isLoading,
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
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
                  SizedBox(height: 2.h),
                  Text(
                    isOnline ? 'En ligne' : 'Hors ligne',
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
            value: isOnline,
            onChanged: isLoading ? null : (_) => _toggleOnlineStatus(),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formulaire d'edition
  // ---------------------------------------------------------------------------

  Widget _buildProfileForm(
    ProfileEditState editState,
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          label: 'Prenom',
          controller: _controller.firstnameController,
          focusNode: _controller.firstnameFocusNode,
          hintText: 'Votre prenom',
          prefixIcon: 'person',
          validator: _controller.validateRequired,
          textColor: textColor,
          textLightColor: textLightColor,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
        ),
        SizedBox(height: 12.h),
        _buildField(
          label: 'Nom',
          controller: _controller.lastnameController,
          focusNode: _controller.lastnameFocusNode,
          hintText: 'Votre nom',
          prefixIcon: 'person',
          validator: _controller.validateRequired,
          textColor: textColor,
          textLightColor: textLightColor,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
        ),
        SizedBox(height: 12.h),
        _buildField(
          label: 'Adresse email',
          controller: _controller.emailController,
          focusNode: _controller.emailFocusNode,
          hintText: 'nom@exemple.com',
          prefixIcon: 'email',
          keyboardType: TextInputType.emailAddress,
          validator: _controller.validateEmail,
          textColor: textColor,
          textLightColor: textLightColor,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          hasInlineError: editState.emailAlreadyUsed,
          inlineErrorMessage:
              editState.emailAlreadyUsed ? 'Cet email est deja utilise' : null,
        ),
        SizedBox(height: 12.h),
        _buildGenderSelector(
          textColor,
          textLightColor,
          surfaceColor,
          borderColor,
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required String prefixIcon,
    required Color textColor,
    required Color textLightColor,
    required Color surfaceColor,
    required Color borderColor,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool hasInlineError = false,
    String? inlineErrorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
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
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(color: textColor, fontSize: 14.sp),
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
            contentPadding: EdgeInsets.symmetric(
              vertical: 16.h,
              horizontal: 16.w,
            ),
            filled: true,
            fillColor: surfaceColor,
            border: _border(borderColor),
            enabledBorder: _border(
              hasInlineError ? Colors.red : borderColor,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(
                color: hasInlineError ? Colors.red : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: _border(Colors.red),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
        if (hasInlineError && inlineErrorMessage != null) ...[
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.only(left: 4.w),
            child: Text(
              inlineErrorMessage,
              style: TextStyle(color: Colors.red, fontSize: 12.sp),
            ),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(color: color, width: 1),
    );
  }

  Widget _buildGenderSelector(
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    const options = [
      ('male', 'Homme'),
      ('female', 'Femme'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
          child: Text(
            'Genre',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        Row(
          children: options.map((opt) {
            final selected = _controller.gender == opt.$1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: opt == options.last ? 0 : 8.w,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8.r),
                  onTap: () => setState(() => _controller.gender = opt.$1),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withOpacity(0.1)
                          : surfaceColor,
                      border: Border.all(
                        color: selected ? AppColors.primary : borderColor,
                        width: selected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      opt.$2,
                      style: TextStyle(
                        color: selected ? AppColors.primary : textColor,
                        fontSize: 14.sp,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveButton(ProfileEditState editState) {
    final isBusy = editState.isSaving;
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: isBusy ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          disabledForegroundColor: Colors.white.withOpacity(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: isBusy
            ? SizedBox(
                height: 24.w,
                width: 24.w,
                child: const CircularProgressIndicator(
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

  // ---------------------------------------------------------------------------
  // Menu d'options
  // ---------------------------------------------------------------------------

  Widget _buildProfileOptions(
    Color textColor,
    Color textLightColor,
    Color surfaceColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          _buildProfileOption(
            title: 'Mes livraisons',
            icon: 'delivery',
            onTap: () => Routes.navigateTo(Routes.deliveries),
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Historique livraisons',
            icon: 'history',
            onTap: () => Routes.navigateTo(Routes.deliveriesHistory),
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Historique disponibilite',
            icon: 'clock',
            onTap: () => Routes.navigateTo(Routes.availabilityLog),
            showDivider: true,
            textColor: textColor,
            textLightColor: textLightColor,
          ),
          _buildProfileOption(
            title: 'Mes notes',
            icon: 'star',
            onTap: () => Routes.navigateTo(Routes.ratings),
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
            title: 'Parametres',
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
    required VoidCallback onTap,
    required bool showDivider,
    required Color textColor,
    required Color textLightColor,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: IconManager.getIcon(
                      icon,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
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
            indent: 56.w,
            endIndent: 16.w,
            color: textLightColor.withOpacity(0.1),
          ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: _confirmLogout,
      icon: IconManager.getIcon('logout', color: Colors.red, size: 20),
      label: Text(
        'Deconnexion',
        style: TextStyle(
          color: Colors.red,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }
}
