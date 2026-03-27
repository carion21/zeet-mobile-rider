// screens/auth/verify_otp/controllers.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/providers/auth_provider.dart';

/// Controller pour gerer la logique de la page de verification OTP.
class VerifyOtpController {
  final String phoneNumber;
  final String? fullName;
  final String type;

  /// Longueur du code OTP (5 chiffres cote API).
  static const int otpLength = 5;

  String otpCode = '';
  bool isLoading = false;
  bool isResending = false;

  // Compte a rebours pour renvoyer le code
  Timer? _timer;
  int _countdown = 60; // 60 secondes
  int get remainingTime => _countdown;
  bool get canResend => _countdown <= 0;
  String get timerText => '${_countdown}s';

  VerifyOtpController({
    required this.phoneNumber,
    this.fullName,
    required this.type,
  });

  /// Demarre le compte a rebours
  void startTimer(Function setState) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        _countdown--;
        setState();
      } else {
        timer.cancel();
      }
    });
  }

  /// Reinitialise le compte a rebours
  void resetTimer(Function setState) {
    _countdown = 60;
    _timer?.cancel();
    startTimer(setState);
  }

  /// Met a jour le code OTP
  void updateOtpCode(String code) {
    otpCode = code;
  }

  /// Verifie le code OTP via le provider auth.
  Future<Map<String, dynamic>> verifyOtp(WidgetRef ref) async {
    final authNotifier = ref.read(authProvider.notifier);
    return authNotifier.verifyOtp(
      phone: phoneNumber,
      code: otpCode,
    );
  }

  /// Renvoie un nouveau code OTP via le provider auth.
  Future<Map<String, dynamic>> resendOtp(WidgetRef ref) async {
    final authNotifier = ref.read(authProvider.notifier);
    return authNotifier.sendOtp(phone: phoneNumber);
  }

  /// Formate le numero de telephone pour affichage
  String formatPhoneNumber() {
    if (phoneNumber.isEmpty) return '';
    final lastTwoDigits = phoneNumber.substring(phoneNumber.length - 2);
    return '+225 *******$lastTwoDigits';
  }

  /// Libere les ressources
  void dispose() {
    _timer?.cancel();
  }
}
