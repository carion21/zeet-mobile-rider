// lib/screens/home/widgets/ongoing_missions_list.dart
//
// Section "Mes livraisons" — affiche les missions en cours du rider :
// loading (1er fetch), error (retry), empty (zero etat) ou liste de
// MissionCard. Bouton "Voir plus" -> ecran deliveries.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/providers/connectivity_provider.dart';
import 'package:rider/providers/main_tab_provider.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:rider/screens/home/widgets/mission_card.dart';
import 'package:zeet_ui/zeet_ui.dart';

class OngoingMissionsList extends ConsumerWidget {
  const OngoingMissionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    final missionsState = ref.watch(missionsListProvider);
    final ongoing = missionsState.ongoing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes().paddingLarge,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mes livraisons',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () =>
                    ref.read(mainTabIndexProvider.notifier).goDeliveries(),
                child: Text(
                  'Voir plus',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (missionsState.isLoading && ongoing.isEmpty)
          _LoadingState(surfaceColor: surfaceColor, isDarkMode: isDarkMode)
        else if (missionsState.errorMessage != null && ongoing.isEmpty)
          _ErrorState(
            message: missionsState.errorMessage!,
            textColor: textColor,
            surfaceColor: surfaceColor,
            isDarkMode: isDarkMode,
            onRetry: () =>
                ref.read(missionsListProvider.notifier).refresh(),
          )
        else if (ongoing.isEmpty)
          _EmptyState(
            isRiderOnline: ref.watch(isOnlineProvider),
            isNetworkOnline: ref.watch(connectivityStatusProvider).maybeWhen(
                  data: (v) => v,
                  orElse: () => true,
                ),
            textColor: textColor,
            textLightColor: textLightColor,
            surfaceColor: surfaceColor,
            isDarkMode: isDarkMode,
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes().paddingLarge),
            child: Column(
              children: ongoing
                  .take(2)
                  .map((mission) => MissionCard(mission: mission))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

/// Skeleton loader matching la structure des MissionCard (skill
/// `zeet-states-elae` §2 — skeleton first, jamais spinner plein ecran).
class _LoadingState extends StatelessWidget {
  const _LoadingState({
    required this.surfaceColor,
    required this.isDarkMode,
  });

  final Color surfaceColor;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes().paddingLarge),
      child: const ZeetSkeletonList(
        itemCount: 2,
        itemHeight: 140,
        padding: EdgeInsets.zero,
        gap: 12,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.textColor,
    required this.surfaceColor,
    required this.isDarkMode,
    required this.onRetry,
  });

  final String message;
  final Color textColor;
  final Color surfaceColor;
  final bool isDarkMode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes().paddingLarge),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              IconManager.getIcon(
                'warning',
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state qui distingue 3 cas (skill `zeet-micro-copy` rider direct) :
///   1. Hors ligne reseau    → "Pas de connexion. Tes missions vont arriver."
///   2. Hors ligne rider     → "Tu es en pause. Active-toi pour recevoir."
///   3. En ligne, queue vide → "On attend la prochaine. Reste dans ta zone."
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isRiderOnline,
    required this.isNetworkOnline,
    required this.textColor,
    required this.textLightColor,
    required this.surfaceColor,
    required this.isDarkMode,
  });

  final bool isRiderOnline;
  final bool isNetworkOnline;
  final Color textColor;
  final Color textLightColor;
  final Color surfaceColor;
  final bool isDarkMode;

  ({String title, String subtitle, IconData icon}) _resolve() {
    if (!isNetworkOnline) {
      return (
        title: 'Pas de connexion',
        subtitle:
            'Tes missions vont arriver\ndès que le réseau revient.',
        icon: Icons.wifi_off_rounded,
      );
    }
    if (!isRiderOnline) {
      return (
        title: 'Tu es en pause',
        subtitle: 'Active-toi pour recevoir\ndes nouvelles missions.',
        icon: Icons.pause_circle_outline_rounded,
      );
    }
    return (
      title: 'On attend la prochaine',
      subtitle: 'Reste dans ta zone,\nça va tomber.',
      icon: Icons.delivery_dining_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = _resolve();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes().paddingLarge),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  visual.icon,
                  color: Colors.grey.shade400,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                visual.title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                visual.subtitle,
                style: TextStyle(
                  color: textLightColor,
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
