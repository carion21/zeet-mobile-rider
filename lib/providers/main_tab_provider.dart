// lib/providers/main_tab_provider.dart
//
// Index courant de la bottom nav permanente du MainScaffold.
//
// Conventions :
//   0 = Home
//   1 = Livraisons
//   2 = Stats
//   3 = Profil
//
// Skill `zeet-3-clicks-rule` §1 — actions recurrentes rider <= 1 tap.
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainTabNotifier extends StateNotifier<int> {
  MainTabNotifier() : super(0);

  static const int home = 0;
  static const int deliveries = 1;
  static const int stats = 2;
  static const int profile = 3;

  void setIndex(int index) {
    if (index < 0 || index > 3) return;
    if (state == index) return;
    state = index;
  }

  void goHome() => setIndex(home);
  void goDeliveries() => setIndex(deliveries);
  void goStats() => setIndex(stats);
  void goProfile() => setIndex(profile);
}

final mainTabIndexProvider =
    StateNotifierProvider<MainTabNotifier, int>((ref) => MainTabNotifier());
