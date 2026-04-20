// HomeNotifWarningBanner — warning discret sur le home quand la
// permission notification a ete hard-refused.
//
// Regle "1 seule relance max" (skill zeet-notification-strategy §8) :
//   - s'affiche uniquement si status == permanentlyDenied,
//   - dismissible via X, persistance 24h dans SharedPreferences,
//   - apres dismiss, ne re-affiche pas avant H+24.
//
// Tone rider : direct, camarade (cf. zeet-micro-copy §2).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rider/core/constants/colors.dart';
import 'package:rider/services/permissions_service.dart';

class HomeNotifWarningBanner extends StatefulWidget {
  const HomeNotifWarningBanner({super.key});

  @override
  State<HomeNotifWarningBanner> createState() => _HomeNotifWarningBannerState();
}

class _HomeNotifWarningBannerState extends State<HomeNotifWarningBanner>
    with WidgetsBindingObserver {
  static const String _kDismissKey = 'home.notif.warning.dismissed_at';
  static const Duration _kSilencePeriod = Duration(hours: 24);

  bool _visible = false;

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
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await PermissionsService.instance.getStatus(
      ZeetPermission.notifications,
    );
    final bool shouldWarn = status == ZeetPermissionStatus.permanentlyDenied;

    bool dismissed = false;
    if (shouldWarn) {
      final prefs = await SharedPreferences.getInstance();
      final int? ts = prefs.getInt(_kDismissKey);
      if (ts != null) {
        final dismissedAt = DateTime.fromMillisecondsSinceEpoch(ts);
        final age = DateTime.now().difference(dismissedAt);
        if (age < _kSilencePeriod) dismissed = true;
      }
    }

    if (!mounted) return;
    setState(() => _visible = shouldWarn && !dismissed);
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kDismissKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    setState(() => _visible = false);
  }

  Future<void> _openSettings() async {
    await PermissionsService.instance.openSettings();
    // Refresh apres retour — gere par didChangeAppLifecycleState.
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      child: Material(
        color: const Color(0xFFFFF3E0), // orange pale, warning discret
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: _openSettings,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.w, 10.h, 8.w, 10.h),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.notifications_off_rounded,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Tu ne reçois pas les missions en temps réel',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF7A3E00),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Active les notifications dans les Réglages.',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFF7A3E00),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ne plus afficher aujourd\'hui',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18.sp,
                    color: const Color(0xFF7A3E00),
                  ),
                  onPressed: _dismiss,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 32.w,
                    minHeight: 32.w,
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
