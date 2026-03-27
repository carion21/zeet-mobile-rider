// screens/auth/login/controllers.dart
import 'package:flutter/material.dart';

/// Controller pour gérer la logique de validation de la page de connexion.
/// Les appels API sont désormais gérés via le AuthProvider (Riverpod).
class LoginController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();

  final FocusNode phoneFocusNode = FocusNode();

  // État du formulaire
  bool isLoading = false;
  bool isPhoneValid = false;
  bool isPhoneFocused = false;

  /// Initialise les écouteurs de focus et de validation
  void initFocusListeners(Function setState) {
    // Écouteurs de focus
    phoneFocusNode.addListener(() {
      setState(() => isPhoneFocused = phoneFocusNode.hasFocus);
    });

    // Écouteurs de validation
    phoneController.addListener(() {
      setState(() {
        isPhoneValid = _validatePhoneInput(phoneController.text);
      });
    });
  }

  /// Vérifie si le numéro de téléphone est valide selon les règles
  bool _validatePhoneInput(String value) {
    // Vérifie si le numéro a 10 chiffres et respecte les préfixes ivoiriens
    return value.length == 10 && RegExp(r'^(01|05|07)').hasMatch(value);
  }

  /// Valide le numéro de téléphone saisi
  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre numéro';
    }
    if (value.length != 10) {
      return 'Le numéro doit contenir 10 chiffres';
    }
    if (!RegExp(r'^(01|05|07)').hasMatch(value)) {
      return 'Le numéro doit commencer par 01, 05 ou 07';
    }
    return null;
  }

  /// Formate le numéro de téléphone pour affichage (+225 XXXXXXXXXX)
  String formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return '';
    return '+225 $phoneNumber';
  }

  /// Libère les ressources
  void dispose() {
    phoneController.dispose();
    phoneFocusNode.dispose();
  }
}
