// screens/auth/login/index.dart
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LoginController();
    _controller.initFocusListeners(setState);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_controller.formKey.currentState!.validate()) return;

    setState(() => _controller.isLoading = true);

    // Appel API via le provider Riverpod
    final result = await ref.read(authProvider.notifier).sendOtp(
      phone: _controller.phoneController.text,
    );

    if (!mounted) return;
    setState(() => _controller.isLoading = false);

    if (result['success']) {
      // Afficher un message de succès
      AppToast.showSuccess(
        context: context,
        message: "Un code a été envoyé au ${_controller.formatPhoneNumber(_controller.phoneController.text)}",
      );

      // Naviguer vers l'écran OTP
      Routes.pushVerifyOtp(
        phoneNumber: _controller.phoneController.text,
        type: 'login',
      );
    } else {
      // Afficher un message d'erreur
      AppToast.showError(
        context: context,
        message: result['message'] ?? "Une erreur s'est produite",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppSizes().initialize(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor = isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : Colors.white;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final borderColor = isDarkMode ? AppColors.darkTextLight.withValues(alpha: 0.2) : const Color(0xFFEEEEEE);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Logo centré
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconManager.getIcon(
                    'delivery',
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 40),

                // Titre principal
                Text(
                  'Connexion Livreur',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Sous-titre
                Text(
                  'Entrez votre numéro pour accéder\nà vos livraisons',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: textLightColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 50),

                // Champ Numéro de téléphone
                _buildInputField(
                  controller: _controller.phoneController,
                  focusNode: _controller.phoneFocusNode,
                  label: 'Numéro de téléphone',
                  hintText: 'ex: 0707070707',
                  prefixIcon: 'phone',
                  keyboardType: TextInputType.phone,
                  prefix: '+225 ',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: _controller.validatePhone,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                  textLightColor: textLightColor,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                ),

                const SizedBox(height: 12),

                // Message d'aide
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Un code vous sera envoyé par SMS pour vous connecter',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: textLightColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 40),

                // Bouton Continuer
                _buildMainButton(
                  onPressed: _controller.isPhoneValid && !_controller.isLoading ? _submitForm : null,
                  label: 'Continuer',
                  isLoading: _controller.isLoading,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget pour créer un champ de formulaire
  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hintText,
    required String prefixIcon,
    required bool isDarkMode,
    required Color textColor,
    required Color textLightColor,
    required Color surfaceColor,
    required Color borderColor,
    String? prefix,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
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
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: textLightColor.withValues(alpha: 0.6),
              fontSize: 14.sp,
            ),
            prefixIcon: IconManager.getIcon(
              prefixIcon,
              color: textLightColor,
              size: 18,
            ),
            prefixText: prefix,
            prefixStyle: TextStyle(
              color: textColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
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
            fillColor: surfaceColor,
            suffixIcon: validator != null && validator(controller.text) == null && controller.text.isNotEmpty
                ? IconManager.getIcon('check', color: Colors.green, size: 18)
                : null,
          ),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(
            color: textColor,
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }

  // Widget pour créer le bouton principal
  Widget _buildMainButton({
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            IconManager.getIcon('arrow_forward', size: 18),
          ],
        ),
      ),
    );
  }
}
