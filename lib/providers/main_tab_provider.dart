// lib/providers/main_tab_provider.dart
//
// Index courant de la bottom nav permanente du MainScaffold.
//
// Conventions (refonte 2026-05, alignement Uber Driver / DoorDash
// Dasher / Grab Driver) :
//   0 = Accueil  (cockpit shift, Home)
//   1 = Courses  (= ex-Livraisons, vocab Senegal/wolof)
//   2 = Gains    (= ex-Stats, le rider raisonne en argent)
//   3 = Compte   (= ex-Profil, hub admin)
//
// Skill `zeet-3-clicks-rule` §1 — actions recurrentes rider <= 1 tap.
//
// Les helpers `goDeliveries` / `goStats` / `goProfile` sont conserves
// pour eviter une cascade de renames dans les call-sites ; les onglets
// gardent leurs index, seul le label/l'icone change cote UI.
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainTabNotifier extends StateNotifier<int> {
  MainTabNotifier() : super(0);

  static const int home = 0;
  static const int deliveries = 1;
  static const int stats = 2;
  static const int profile = 3;

  // Alias semantiques (reco) — les anciens noms restent disponibles.
  static const int courses = deliveries;
  static const int gains = stats;
  static const int compte = profile;

  void setIndex(int index) {
    if (index < 0 || index > 3) return;
    if (state == index) return;
    state = index;
  }

  void goHome() => setIndex(home);
  void goDeliveries() => setIndex(deliveries);
  void goStats() => setIndex(stats);
  void goProfile() => setIndex(profile);

  // Aliases recommandes pour les nouveaux call-sites.
  void goCourses() => setIndex(courses);
  void goGains() => setIndex(gains);
  void goCompte() => setIndex(compte);
}

final mainTabIndexProvider =
    StateNotifierProvider<MainTabNotifier, int>((ref) => MainTabNotifier());
