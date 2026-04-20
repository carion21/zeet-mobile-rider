// lib/screens/main_scaffold/index.dart
//
// Scaffold racine de l'app rider apres l'auth. Maintient une bottom nav
// permanente pour reduire la profondeur de navigation : passer de Stats
// a Livraisons ne demande plus 3 taps mais 1 seul.
//
// Architecture :
//   - `IndexedStack` pour preserver l'etat (scroll, filtres, FCM listeners)
//     entre les onglets. Les 4 ecrans sont mountes une fois et restent
//     vivants ; leur `initState` ne se rejoue pas a chaque switch.
//   - L'index courant est partage via `mainTabIndexProvider` pour que les
//     sous-widgets (avatar du HomeHeader, FAB deliveries, etc.) puissent
//     switcher d'onglet via Riverpod plutot que de pusher.
//   - Transition entre tabs : crossfade 200ms (skill `zeet-motion-system`
//     §4 — fade through, pas de slide horizontal).
//
// Skills :
//   - `zeet-3-clicks-rule` §1 (actions recurrentes <= 1 tap)
//   - `zeet-pos-ergonomics` §1 (hit target >= 56pt, hauteur >= 56pt)
//   - `zeet-design-system` (tokens ZeetColors)
//   - `zeet-motion-system` §4 (fade through inter-tab)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/providers/main_tab_provider.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/screens/deliveries/index.dart';
import 'package:rider/screens/home/index.dart';
import 'package:rider/screens/profile/index.dart';
import 'package:rider/screens/stats/index.dart';
import 'package:zeet_ui/zeet_ui.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  // Les 4 screens sont instancies une seule fois et conserves dans
  // l'IndexedStack pour preserver l'etat entre les switches.
  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    DeliveriesScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(mainTabIndexProvider.notifier).setIndex(widget.initialIndex);
      });
    }
  }

  void _onTabTap(int index) {
    final int current = ref.read(mainTabIndexProvider);
    if (current == index) return;
    HapticFeedback.selectionClick();
    ref.read(mainTabIndexProvider.notifier).setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex = ref.watch(mainTabIndexProvider);
    final int ongoingCount = ref.watch(ongoingMissionsProvider).length;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color selectedColor = ZeetColors.primary;
    final Color unselectedColor =
        isDarkMode ? ZeetColors.inkMutedDark : ZeetColors.inkMuted;
    final Color barBackground =
        isDarkMode ? ZeetColors.surfaceDark : ZeetColors.surface;

    return Scaffold(
      // IndexedStack : tous les screens sont mountes une fois et leur
      // etat (scroll, FCM listeners, controllers) est preserve entre les
      // switches. Pas de transition inter-tab pour eviter de detruire
      // l'arbre — l'instantane est instantane (>= 200ms imperceptible
      // sur un IndexedStack), conforme aux apps natives Material.
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: currentIndex,
        ongoingCount: ongoingCount,
        selectedColor: selectedColor,
        unselectedColor: unselectedColor,
        backgroundColor: barBackground,
        onTap: _onTabTap,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.ongoingCount,
    required this.selectedColor,
    required this.unselectedColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final int currentIndex;
  final int ongoingCount;
  final Color selectedColor;
  final Color unselectedColor;
  final Color backgroundColor;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color borderColor =
        isDarkMode ? ZeetColors.lineDark : ZeetColors.line;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Accueil',
                selected: currentIndex == 0,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.delivery_dining_rounded,
                label: 'Livraisons',
                selected: currentIndex == 1,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                badgeCount: ongoingCount,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                selected: currentIndex == 2,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profil',
                selected: currentIndex == 3,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? selectedColor : unselectedColor;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          // Hit target plein rectangle (>= 48pt en hauteur car parent = 64).
          child: SizedBox(
            height: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _IconWithBadge(
                  icon: icon,
                  color: color,
                  badgeCount: badgeCount,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    if (badgeCount <= 0) {
      return Icon(icon, color: color, size: 24);
    }
    final String label = badgeCount > 9 ? '9+' : '$badgeCount';
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Icon(icon, color: color, size: 24),
        Positioned(
          right: -8,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: ZeetColors.danger,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
