// lib/screens/profile/controllers.dart
import 'package:flutter/material.dart';

class ProfileController {
  // Contrôleurs pour les champs de formulaire
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // Focus nodes pour les champs de formulaire
  final FocusNode emailFocusNode = FocusNode();

  // Clé pour le formulaire (validation)
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // État d'édition
  bool isEditing = false;
  bool isLoading = false;

  // Statut du livreur
  bool isOnline = false;

  // Données utilisateur pré-remplies
  String userName = "Kouassi Jean";
  String initials = "KJ";
  String phoneNumber = "+225 0707070707";
  String? email;

  // Statistiques du livreur
  int totalDeliveries = 127;
  double averageRating = 4.8;

  // Initialiser les contrôleurs avec les données actuelles
  void initControllers() {
    nameController.text = userName;
    phoneController.text = phoneNumber;
    if (email != null) emailController.text = email!;
  }

  // Validation de l'email
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // L'email est optionnel
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Veuillez entrer un email valide';
    }

    return null;
  }

  // Basculer le statut en ligne/hors ligne
  Future<Map<String, dynamic>> toggleOnlineStatus() async {
    isLoading = true;

    try {
      // Simuler un appel API pour changer le statut
      await Future.delayed(const Duration(milliseconds: 500));

      isOnline = !isOnline;
      isLoading = false;

      return {
        'success': true,
        'message': isOnline ? 'Vous êtes maintenant en ligne' : 'Vous êtes maintenant hors ligne',
        'isOnline': isOnline,
      };
    } catch (e) {
      isLoading = false;
      return {'success': false, 'message': 'Une erreur s\'est produite: $e'};
    }
  }

  // Soumettre les modifications
  Future<Map<String, dynamic>> saveChanges() async {
    if (!formKey.currentState!.validate()) {
      return {'success': false, 'message': 'Veuillez corriger les erreurs du formulaire'};
    }

    isLoading = true;

    try {
      // Simuler un appel API pour enregistrer les modifications
      await Future.delayed(const Duration(seconds: 1));

      // Mise à jour des données
      email = emailController.text.isNotEmpty ? emailController.text : null;

      isLoading = false;
      isEditing = false;

      return {
        'success': true,
        'message': 'Profil mis à jour avec succès',
      };
    } catch (e) {
      isLoading = false;
      return {'success': false, 'message': 'Une erreur s\'est produite: $e'};
    }
  }

  // Déconnexion
  Future<Map<String, dynamic>> logout() async {
    isLoading = true;

    try {
      // Simuler un appel API pour la déconnexion
      await Future.delayed(const Duration(seconds: 1));

      isLoading = false;

      return {
        'success': true,
        'message': 'Déconnexion réussie',
      };
    } catch (e) {
      isLoading = false;
      return {'success': false, 'message': 'Une erreur s\'est produite: $e'};
    }
  }

  // Libérer les ressources
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    emailFocusNode.dispose();
  }
}
