// screens/auth/verify_otp/index.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/providers/auth_provider.dart';
import 'package:rider/services/navigation_service.dart';
import 'controllers.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String? fullName;
  final String type;

  const VerifyOtpScreen({
    super.key,
    required this.phoneNumber,
    this.fullName,
    required this.type,
  });

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  late final VerifyOtpController _controller;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = VerifyOtpController(
      phoneNumber: widget.phoneNumber,
      fullName: widget.fullName,
      type: widget.type,
    );

    _otpController.addListener(() {
      _controller.updateOtpCode(_otpController.text);
      setState(() {});

      // Verifier automatiquement quand le code complet est saisi
      if (_otpController.text.length == VerifyOtpController.otpLength) {
        _focusNode.unfocus();
        _verifyOtp();
      }
    });

    // Demarrer le compte a rebours
    _controller.startTimer(() {
      if (mounted) setState(() {});
    });

    // Focus automatique sur le champ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_controller.otpCode.length != VerifyOtpController.otpLength) {
      AppToast.showWarning(
        context: context,
        message: "Veuillez saisir le code a ${VerifyOtpController.otpLength} chiffres complet",
      );
      return;
    }

    setState(() => _controller.isLoading = true);

    final result = await _controller.verifyOtp(ref);

    if (!mounted) return;
    setState(() => _controller.isLoading = false);

    if (result['success']) {
      AppToast.showSuccess(context: context, message: "Verification reussie !");
      Routes.navigateAndRemoveAll(Routes.home);
    } else {
      AppToast.showError(
        context: context,
        message: result['message'] ?? "Echec de la verification",
      );
      // Vider le champ pour permettre une nouvelle saisie
      _otpController.clear();
      _focusNode.requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (!_controller.canResend) return;

    setState(() => _controller.isResending = true);

    final result = await _controller.resendOtp(ref);

    if (!mounted) return;
    setState(() {
      _controller.isResending = false;
      if (result['success']) {
        _controller.resetTimer(() {
          if (mounted) setState(() {});
        });
      }
    });

    if (result['success']) {
      AppToast.showSuccess(context: context, message: "Un nouveau code a ete envoye");
      _otpController.clear();
      _focusNode.requestFocus();
    } else {
      AppToast.showError(
        context: context,
        message: result['message'] ?? "Echec de l'envoi du nouveau code",
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
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: IconManager.getIcon('arrow_back', color: textColor),
          onPressed: () => Routes.goBack(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Titre
              Text(
                'Verification',
                style: TextStyle(
                  fontSize: 24.0.sp,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 8),

              // Message avec numero masque
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: textLightColor,
                  ),
                  children: [
                    TextSpan(text: 'Un code a ${VerifyOtpController.otpLength} chiffres vous a ete envoye au '),
                    TextSpan(
                      text: _controller.formatPhoneNumber(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Champ OTP unique
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Code de verification',
                      style: TextStyle(
                        fontSize: 14.0.sp,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: _otpController,
                    focusNode: _focusNode,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor, width: 1.w),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor, width: 1.w),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primary, width: 2.w),
                      ),
                      filled: true,
                      fillColor: surfaceColor,
                      suffixIcon: _otpController.text.length == VerifyOtpController.otpLength
                          ? IconManager.getIcon('check', color: Colors.green, size: 18)
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(VerifyOtpController.otpLength),
                    ],
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18.0.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 8.w,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bouton renvoyer le code
              Center(
                child: GestureDetector(
                  onTap: _controller.canResend ? _resendOtp : null,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: textLightColor,
                      ),
                      children: [
                        const TextSpan(text: 'Code non recu ? '),
                        TextSpan(
                          text: _controller.canResend
                              ? 'Renvoyer le code'
                              : 'Renvoyer dans ${_controller.timerText}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _controller.canResend
                                ? AppColors.primary
                                : textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Bouton Verifier
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: !_controller.isLoading ? _verifyOtp : null,
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
                  child: _controller.isLoading
                      ? SizedBox(
                          height: 24.h,
                          width: 24.w,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Verifier',
                              style: TextStyle(
                                fontSize: 16.0.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            IconManager.getIcon('arrow_forward', size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
