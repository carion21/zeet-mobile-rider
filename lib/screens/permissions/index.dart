// lib/screens/permissions/index.dart
//
// Onboarding permissions post-login (rider). POS-compliant, snappy,
// durees courtes 150-200ms, haptic obligatoire, couleur+icone+label.
// Refresh a resumed (retour des settings Android).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/services/permissions_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() =>
      _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  final Map<ZeetPermission, ZeetPermissionStatus> _statuses =
      <ZeetPermission, ZeetPermissionStatus>{};
  bool _loading = true;
  bool _requestingAny = false;
  // Annule la boucle "Tout autoriser" au retour d'un settings screen : sur
  // certains OEM Android, l'await `Permission.xxx.request()` ne resout pas,
  // ce qui laisse les boutons grises. On privilegie le pilotage une-par-une.
  bool _batchCancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _batchCancelled = true;
      if (_requestingAny && mounted) {
        setState(() => _requestingAny = false);
      }
      _refreshAll();
    }
  }

  Future<void> _refreshAll() async {
    final svc = PermissionsService.instance;
    final Map<ZeetPermission, ZeetPermissionStatus> next = {};
    for (final p in svc.applicablePermissions) {
      next[p] = await svc.getStatus(p);
    }
    if (!mounted) return;
    setState(() {
      _statuses
        ..clear()
        ..addAll(next);
      _loading = false;
    });
  }

  Future<void> _requestOne(ZeetPermission p) async {
    await HapticFeedback.selectionClick();
    setState(() => _requestingAny = true);
    try {
      if (_statuses[p] == ZeetPermissionStatus.permanentlyDenied) {
        await PermissionsService.instance.openSettings();
      } else {
        final next = await PermissionsService.instance.request(p);
        if (!mounted) return;
        setState(() => _statuses[p] = next);
        if (next == ZeetPermissionStatus.granted) {
          await HapticFeedback.lightImpact();
        }
      }
    } finally {
      if (mounted) setState(() => _requestingAny = false);
    }
  }

  Future<void> _requestAllMissing() async {
    final svc = PermissionsService.instance;
    _batchCancelled = false;
    setState(() => _requestingAny = true);
    try {
      for (final p in svc.applicablePermissions) {
        if (_batchCancelled || !mounted) return;
        final current = _statuses[p];
        if (current == ZeetPermissionStatus.granted ||
            current == ZeetPermissionStatus.notApplicable ||
            current == ZeetPermissionStatus.permanentlyDenied) {
          continue;
        }
        ZeetPermissionStatus next;
        try {
          next = await svc.request(p).timeout(
                const Duration(minutes: 2),
                onTimeout: () => current ?? ZeetPermissionStatus.unknown,
              );
        } catch (_) {
          next = current ?? ZeetPermissionStatus.unknown;
        }
        if (_batchCancelled || !mounted) return;
        setState(() => _statuses[p] = next);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      if (mounted) setState(() => _requestingAny = false);
    }
  }

  Future<void> _finish() async {
    await PermissionsService.instance.markOnboarded();
    if (!mounted) return;

    final criticals = PermissionsService.instance.criticalPermissions;
    final missingCritical = criticals
        .where((p) =>
            _statuses[p] != ZeetPermissionStatus.granted &&
            _statuses[p] != ZeetPermissionStatus.notApplicable)
        .toList();

    if (missingCritical.isNotEmpty) {
      AppToast.showWarning(
        context: context,
        message:
            'Des permissions critiques manquent. Vous pourriez rater des missions.',
      );
    } else {
      AppToast.showSuccess(
        context: context,
        message: 'Pret a rouler ! Bonne tournee.',
      );
    }

    Routes.navigateAndRemoveAll(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final perms = PermissionsService.instance.applicablePermissions;
    final int grantedCount = perms
        .where((p) => _statuses[p] == ZeetPermissionStatus.granted)
        .length;
    final int totalCount = perms.length;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                        children: <Widget>[
                          _Header(
                            grantedCount: grantedCount,
                            totalCount: totalCount,
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'Configuration express',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'On active tout ce qu\'il faut pour ne plus rater une mission.',
                            style: tt.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          ...perms.map((p) => _PermissionCard(
                                permission: p,
                                status: _statuses[p] ??
                                    ZeetPermissionStatus.unknown,
                                critical: PermissionsService.instance
                                    .criticalPermissions
                                    .contains(p),
                                onTap: _requestingAny
                                    ? null
                                    : () => _requestOne(p),
                              )),
                          if (perms.any((p) =>
                              _statuses[p] ==
                              ZeetPermissionStatus.permanentlyDenied))
                            _SettingsHint(
                              onOpen:
                                  PermissionsService.instance.openSettings,
                            ),
                        ],
                      ),
                    ),
            ),
            _BottomBar(
              grantedCount: grantedCount,
              totalCount: totalCount,
              requesting: _requestingAny,
              onRequestAll: _requestAllMissing,
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Header hero
// =============================================================================

class _Header extends StatelessWidget {
  const _Header({required this.grantedCount, required this.totalCount});
  final int grantedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final double progress = totalCount == 0 ? 0 : grantedCount / totalCount;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48.w,
                height: 48.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.two_wheeler_rounded,
                  color: Colors.white,
                  size: 26.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Bienvenue, rider',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Activez les permissions en 30 secondes.',
                      style: tt.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            totalCount == 0
                ? 'Aucune permission requise sur votre appareil.'
                : '$grantedCount sur $totalCount permission${totalCount > 1 ? 's' : ''} accordee${grantedCount > 1 ? 's' : ''}',
            style: tt.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Card permission
// =============================================================================

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.permission,
    required this.status,
    required this.critical,
    required this.onTap,
  });

  final ZeetPermission permission;
  final ZeetPermissionStatus status;
  final bool critical;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final svc = PermissionsService.instance;

    final bool granted = status == ZeetPermissionStatus.granted;
    final bool actionable =
        !granted && status != ZeetPermissionStatus.notApplicable;

    final Color accent = granted
        ? ZeetColors.success
        : (critical ? AppColors.primary : scheme.onSurfaceVariant);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: granted
              ? ZeetColors.success.withValues(alpha: 0.35)
              : scheme.outlineVariant,
          width: granted ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: actionable ? onTap : null,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: granted
                      ? Container(
                          key: const ValueKey<String>('granted'),
                          width: 48.w,
                          height: 48.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                ZeetColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: ZeetColors.success,
                            size: 26.r,
                          ),
                        )
                      : Container(
                          key: const ValueKey<String>('icon'),
                          width: 48.w,
                          height: 48.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Icon(_iconFor(permission),
                              color: accent, size: 24.r),
                        ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              svc.labelFor(permission),
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (critical) ...<Widget>[
                            SizedBox(width: 6.w),
                            _CriticalPill(),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        svc.descriptionFor(permission),
                        style: tt.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      _StatusPill(status: status),
                    ],
                  ),
                ),
                if (actionable)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w, top: 4.h),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14.r,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ZeetPermission p) {
    switch (p) {
      case ZeetPermission.notifications:
        return Icons.notifications_active_rounded;
      case ZeetPermission.location:
        return Icons.location_on_rounded;
      case ZeetPermission.locationAlways:
        return Icons.my_location_rounded;
      case ZeetPermission.batteryOptimization:
        return Icons.battery_charging_full_rounded;
      case ZeetPermission.exactAlarm:
        return Icons.alarm_on_rounded;
    }
  }
}

class _CriticalPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ZeetRadius.pill),
      ),
      child: Text(
        'Requis',
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final ZeetPermissionStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;
    late final IconData icon;

    switch (status) {
      case ZeetPermissionStatus.granted:
        bg = ZeetColors.success.withValues(alpha: 0.15);
        fg = ZeetColors.success;
        label = 'Accordee';
        icon = Icons.check_circle_rounded;
      case ZeetPermissionStatus.denied:
      case ZeetPermissionStatus.unknown:
        bg = AppColors.primary.withValues(alpha: 0.12);
        fg = AppColors.primary;
        label = 'Appuyez pour autoriser';
        icon = Icons.touch_app_rounded;
      case ZeetPermissionStatus.permanentlyDenied:
        bg = const Color(0xFFFFE6E6);
        fg = const Color(0xFFD32F2F);
        label = 'Ouvrir les reglages';
        icon = Icons.settings_rounded;
      case ZeetPermissionStatus.notApplicable:
        bg = const Color(0xFFEEEEEE);
        fg = const Color(0xFF616161);
        label = 'Non necessaire';
        icon = Icons.remove_circle_outline_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ZeetRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: fg, size: 14.r),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHint extends StatelessWidget {
  const _SettingsHint({required this.onOpen});
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Certaines permissions passent par les reglages systeme.',
              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: onOpen,
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.grantedCount,
    required this.totalCount,
    required this.requesting,
    required this.onRequestAll,
    required this.onFinish,
  });

  final int grantedCount;
  final int totalCount;
  final bool requesting;
  final VoidCallback onRequestAll;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool allGranted = totalCount == 0 || grantedCount >= totalCount;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          if (!allGranted)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: requesting ? null : onRequestAll,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text('Tout autoriser'),
              ),
            ),
          if (!allGranted) SizedBox(width: 12.w),
          Expanded(
            child: FilledButton(
              onPressed: requesting ? null : onFinish,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Text(
                allGranted ? 'En route' : 'Plus tard',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
