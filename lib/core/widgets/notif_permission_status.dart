// NotifPermissionStatus — affichage synthetique de l'etat de la permission
// notification rider, avec CTA adapte (activer ou ouvrir Reglages).
//
// Utilise depuis :
//   - Profile screen : tuile "Notifications" dans les options.
//   - Home screen : warning discret en banniere quand permanentlyDenied.
//
// Pourquoi un widget dedie ?
//   On respecte l'exigence "1 seule relance max" (skill
//   zeet-notification-strategy §8). La bannie re home est dismissible
//   et persiste le dismiss 24h dans SharedPrefs, evitant le harcelement.
//
// Tone of voice rider : direct, camarade (cf. zeet-micro-copy §2).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/services/fcm_service.dart';
import 'package:rider/services/permissions_service.dart';

/// Pill d'etat (icone + label) affichee dans une tuile Profile.
/// 3 etats :
///   - granted          : vert + "Activees" + pas d'action.
///   - denied / unknown : orange + "A activer" + tap pour demander.
///   - permanentlyDenied : rouge + "Ouvrir Reglages" + tap -> openSettings.
class NotifPermissionTile extends StatefulWidget {
  const NotifPermissionTile({super.key, this.onGranted});

  /// Callback appele quand l'utilisateur vient d'accorder la permission
  /// (refresh ou enregistrement cote Profile).
  final VoidCallback? onGranted;

  @override
  State<NotifPermissionTile> createState() => _NotifPermissionTileState();
}

class _NotifPermissionTileState extends State<NotifPermissionTile>
    with WidgetsBindingObserver {
  ZeetPermissionStatus _status = ZeetPermissionStatus.unknown;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Retour des Reglages OS : l'utilisateur a peut-etre change l'etat.
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final next = await PermissionsService.instance.getStatus(
      ZeetPermission.notifications,
    );
    if (!mounted) return;
    setState(() => _status = next);
  }

  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_status == ZeetPermissionStatus.permanentlyDenied) {
        // L'OS ne montrera plus la system prompt : unique option = Reglages.
        await PermissionsService.instance.openSettings();
      } else if (_status != ZeetPermissionStatus.granted) {
        // Demande la permission via FcmService (re-register token au passage).
        final res = await FcmService.instance.requestPushPermission();
        debugPrint('[NotifPermissionTile] request result: $res');
      }
    } finally {
      if (mounted) {
        await _refresh();
        if (mounted) {
          setState(() => _busy = false);
          if (_status == ZeetPermissionStatus.granted) {
            widget.onGranted?.call();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    late final IconData icon;
    late final Color accent;
    late final String label;
    late final String hint;

    switch (_status) {
      case ZeetPermissionStatus.granted:
        icon = Icons.notifications_active_rounded;
        accent = const Color(0xFF10B981); // success
        label = 'Notifications activées';
        hint = 'Tu seras alerté dès qu\'une mission tombe.';
      case ZeetPermissionStatus.permanentlyDenied:
        icon = Icons.notifications_off_rounded;
        accent = const Color(0xFFD32F2F);
        label = 'Notifications bloquées';
        hint = 'Ouvre les Réglages pour réactiver les missions en temps réel.';
      case ZeetPermissionStatus.notApplicable:
        icon = Icons.notifications_rounded;
        accent = scheme.onSurfaceVariant;
        label = 'Notifications';
        hint = 'Non nécessaires sur cet appareil.';
      case ZeetPermissionStatus.denied:
      case ZeetPermissionStatus.unknown:
        icon = Icons.notifications_paused_rounded;
        accent = AppColors.primary;
        label = 'Activer les notifications';
        hint = 'Sans elles, tu ne reçois aucune mission. Touche pour activer.';
    }

    final bool actionable = _status != ZeetPermissionStatus.granted &&
        _status != ZeetPermissionStatus.notApplicable;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: actionable ? _onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: <Widget>[
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: accent, size: 22.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      hint,
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionable)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14.r,
                  color: scheme.onSurfaceVariant,
                )
              else if (_busy)
                SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
