// lib/screens/home/widgets/ongoing_missions_list.dart
//
// Section "Mes livraisons" — affiche les missions en cours du rider :
// loading (1er fetch), error (retry), empty (zero etat) ou liste de
// MissionCard. Bouton "Voir plus" -> ecran deliveries.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/models/mission_model.dart';
import 'package:rider/providers/connectivity_provider.dart';
import 'package:rider/providers/main_tab_provider.dart';
import 'package:rider/providers/mission_provider.dart';
import 'package:rider/providers/status_provider.dart';
import 'package:rider/screens/home/widgets/mission_card.dart';
import 'package:rider/services/navigation_service.dart';
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes().paddingLarge),
            // Composant DS partagé : copy ZEET, retry intégré, semantics OK.
            child: ZeetErrorState(
              kind: ZeetErrorKind.generic,
              description: missionsState.errorMessage,
              onRetry: () =>
                  ref.read(missionsListProvider.notifier).refresh(),
              compact: true,
            ),
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
                  .map((mission) => _SwipeReportCard(mission: mission))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

/// Wrapper Dismissible swipe-left "Signaler un souci" sur une MissionCard
/// ongoing. Skill `zeet-gesture-grammar` §3 (rider : swipe sur mission en
/// cours = action contextuelle) + `zeet-3-clicks-rule` §5bis (swipe = 0.5
/// tap, raccourci vers signaler). Le swipe ne dismisse PAS la card : il
/// pousse l'écran de détail où le rider peut taper "Signaler un souci".
class _SwipeReportCard extends StatelessWidget {
  const _SwipeReportCard({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    // MissionCard porte déjà son propre `margin: bottom: 16`.
    return Dismissible(
      key: ValueKey<String>('ongoing-mission-${mission.id}'),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 16),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: ZeetSpacing.x6),
        decoration: BoxDecoration(
          color: ZeetColors.danger,
          borderRadius: ZeetRadius.brMd,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.flag_outlined, color: Colors.white, size: 22),
            SizedBox(width: ZeetSpacing.x2),
            Text(
              'Signaler',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      // Seuil élevé pour éviter les déclenchements accidentels (gants).
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.endToStart: 0.45,
      },
      confirmDismiss: (_) async {
        ZeetHaptics.warning();
        Routes.pushMissionDetails(missionId: mission.id.toString());
        // Retourne false : la card reste en place, on revient sur Home
        // une fois le signalement fait depuis le détail.
        return false;
      },
      child: MissionCard(mission: mission),
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
