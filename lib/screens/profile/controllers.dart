// lib/screens/profile/controllers.dart
//
// Controller UI du screen profil. Ne contient plus de logique mock : la
// mutation du profil passe par `profileEditProvider` (cf. index.dart), ce
// controller ne gere que les TextEditingController et la validation
// locale (format email, vide, etc.).

import 'package:flutter/material.dart';

class ProfileController {
  // Controllers des champs de formulaire.
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  // Focus nodes.
  final FocusNode firstnameFocusNode = FocusNode();
  final FocusNode lastnameFocusNode = FocusNode();
  final FocusNode emailFocusNode = FocusNode();

  // Cle du formulaire pour la validation.
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Etat local de l'ecran.
  bool isEditing = false;

  // Gender courant (null | 'male' | 'female'). Aligne sur le backend.
  String? gender;

  /// Pre-remplit les champs depuis les donnees actuelles du rider.
  void hydrate({
    String? firstname,
    String? lastname,
    String? email,
    String? gender,
  }) {
    firstnameController.text = firstname ?? '';
    lastnameController.text = lastname ?? '';
    emailController.text = email ?? '';
    this.gender = gender;
  }

  /// Validation email cote client. L'email est optionnel.
  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final emailRegex =
        RegExp(r'^[\w\.\-\+]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Email invalide';
    }
    return null;
  }

  String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Champ requis';
    }
    return null;
  }

  void dispose() {
    firstnameController.dispose();
    lastnameController.dispose();
    emailController.dispose();
    firstnameFocusNode.dispose();
    lastnameFocusNode.dispose();
    emailFocusNode.dispose();
  }
}
