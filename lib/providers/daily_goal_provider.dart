// lib/providers/daily_goal_provider.dart
//
// Objectif courses/jour rider — opt-in via tap tuile Home (Skill
// `zeet-neuro-ux` §11 peak moment + §12bis dopamine anticipation).
//
// State :
//   0  = non defini (le rider n'a jamais regle d'objectif)
//   >0 = objectif courses/jour
//
// Persistance SharedPreferences cle `rider_daily_goal_courses`.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyGoalNotifier extends StateNotifier<int> {
  DailyGoalNotifier() : super(0) {
    _load();
  }

  static const String _key = 'rider_daily_goal_courses';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      state = prefs.getInt(_key) ?? 0;
    } catch (_) {
      if (!mounted) return;
      state = 0;
    }
  }

  Future<void> setGoal(int value) async {
    if (value < 0) return;
    if (!mounted) return;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, value);
    } catch (_) {
      // silencieux : la valeur reste en memoire pour la session
    }
  }

  Future<void> unset() => setGoal(0);

  bool get isSet => state > 0;
}

final dailyGoalProvider =
    StateNotifierProvider<DailyGoalNotifier, int>((ref) => DailyGoalNotifier());
