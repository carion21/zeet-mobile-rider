// lib/screens/delivery_details/widgets/delivery_header.dart
//
// Header overlay sur la map : back button + pill `mission-ref-{id}` (Hero
// destination conserve) + bouton historique. Sticky en haut, SafeArea applique
// par l'orchestrateur.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/sizes.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/services/navigation_service.dart';
import 'package:rider/screens/delivery_details/widgets/mission_logs_sheet.dart';
import 'package:zeet_ui/zeet_ui.dart';

class DeliveryHeader extends StatelessWidget {
  final String? missionId;

  /// Code complet de la livraison (ex: `DEL26042500_5116_3312`). Affiche
  /// en suffixe court (`#3312`) dans la pill pour glanceability —
  /// le code complet est exposable via tap (bottom sheet copier).
  final String? deliveryCode;

  /// Suffixe court du code livraison (`3312`). Calcule par l'appelant.
  final String? deliveryCodeShort;

  /// Numero/code de la commande (distinct de la livraison).
  final String? orderCode;

  /// Suffixe court du code commande (`1828`). Calcule par l'appelant.
  final String? orderCodeShort;

  final int? missionDbId;

  /// Status livraison (label + couleur API). Affiche en chip pill compact
  /// a droite de la pill code — glanceability immediate (skill
  /// `zeet-neuro-ux` status visibility). Cache si null.
  final String? statusLabel;
  final Color? statusColor;

  /// Tap sur l'icone "Signaler un souci". Cache si null.
  final VoidCallback? onReportIssue;

  const DeliveryHeader({
    super.key,
    required this.missionId,
    required this.deliveryCode,
    required this.deliveryCodeShort,
    required this.orderCode,
    required this.orderCodeShort,
    required this.missionDbId,
    this.statusLabel,
    this.statusColor,
    this.onReportIssue,
  });

  void _showCodesSheet(BuildContext context) {
    ZeetHaptics.success();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ZeetRadius.lg),
        ),
      ),
      builder: (ctx) => _CodesSheet(
        deliveryCode: deliveryCode,
        orderCode: orderCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSizes().paddingMedium),
      child: Row(
        children: [
          // Hit target 48×48 (skill zeet-pos-ergonomics §1) — gants moto OK.
          // Container visuel 42pt centré dans la zone tactile 48pt.
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Routes.goBack(),
                customBorder: const CircleBorder(),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_back,
                        color: AppColors.text, size: 22),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Hero(
              tag: 'mission-ref-${missionId ?? 'pending'}',
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                child: InkWell(
                  onTap: () => _showCodesSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              deliveryCodeShort != null
                                  ? 'LIV #$deliveryCodeShort'
                                  : '#...',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (orderCodeShort != null) ...<Widget>[
                              const SizedBox(height: 1),
                              Text(
                                'Cmd #$orderCodeShort',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 16,
                          color: AppColors.textLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (statusLabel != null && statusLabel!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: _HeaderStatusChip(
                label: statusLabel!,
                color: statusColor ?? AppColors.primary,
              ),
            ),
          ],
          const Spacer(),
          if (onReportIssue != null) ...[
            _OverlayCircleButton(
              icon: Icons.warning_amber_rounded,
              color: AppColors.text,
              onTap: onReportIssue!,
              tooltip: 'Signaler un souci',
            ),
            const SizedBox(width: 8),
          ],
          if (missionDbId != null)
            _OverlayCircleButton(
              icon: Icons.history_rounded,
              color: AppColors.text,
              onTap: () => showMissionLogsSheet(
                context,
                missionId: missionDbId.toString(),
              ),
              tooltip: 'Historique de la mission',
            ),
        ],
      ),
    );
  }
}

/// Bouton circulaire blanc overlay sur la map. Hit target 48pt
/// (skill zeet-pos-ergonomics §1) avec visuel 44pt centre.
class _OverlayCircleButton extends StatelessWidget {
  const _OverlayCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill compacte de statut affichee dans le header overlay map. Couleur
/// pilotee par l'API (`last_delivery_status.color`). Background blanc
/// pour rester lisible meme sur fond carte vert/clair.
class _HeaderStatusChip extends StatelessWidget {
  const _HeaderStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet "Identifiants" — affiche les codes complets (livraison +
/// commande) avec bouton copier dedie. Indispensable pour le rider qui
/// doit lire le code au telephone (support, partenaire) ou comparer avec
/// le ticket imprime au resto.
class _CodesSheet extends StatelessWidget {
  const _CodesSheet({
    required this.deliveryCode,
    required this.orderCode,
  });

  final String? deliveryCode;
  final String? orderCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(ZeetRadius.pill),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Identifiants',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12.h),
            if (deliveryCode != null)
              _CodeRow(
                label: 'Code livraison',
                value: deliveryCode!,
                accent: AppColors.primary,
              ),
            if (deliveryCode != null && orderCode != null)
              SizedBox(height: 8.h),
            if (orderCode != null)
              _CodeRow(
                label: 'Code commande',
                value: orderCode!,
                accent: scheme.onSurface,
              ),
          ],
        ),
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 6.w, 10.h),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: ZeetRadius.brMd,
        border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: tt.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: tt.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copier',
            onPressed: () async {
              ZeetHaptics.success();
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              AppToast.showSuccess(
                context: context,
                message: '$label copié',
              );
            },
          ),
        ],
      ),
    );
  }
}
