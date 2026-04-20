// lib/screens/delivery_details/widgets/reason_picker_sheet.dart
//
// Bottom sheet pour signaler "non livre" :
//   - presets cliquables (chips) : "Client injoignable", "Adresse fausse",
//     "Refus client"...
//   - champ libre optionnel pour preciser
//   - capture GPS optionnelle (Geolocator)
//   - bouton swipe-to-confirm en bas (ZeetSwipeToConfirm depuis zeet_ui)
//
// Skill ZEET : zeet-gesture-grammar §swipe-to-confirm (actions
// irreversibles), zeet-pos-ergonomics (presets > saisie longue),
// zeet-states-elae (motif clair).
//
// Renvoie un `ReasonPickerResult` ou null si annule.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zeet_ui/zeet_ui.dart';

import 'package:rider/core/constants/colors.dart';

class ReasonPickerResult {
  final String reason;
  final double? geoLat;
  final double? geoLng;

  const ReasonPickerResult({
    required this.reason,
    this.geoLat,
    this.geoLng,
  });
}

class ReasonPickerSheet {
  static Future<ReasonPickerResult?> show({
    required BuildContext context,
    required String title,
    String description =
        'Choisis un motif pour aider à régler le problème.',
    List<String> presets = const <String>[
      'Client injoignable',
      'Adresse fausse',
      'Refus client',
      'Restaurant ferme',
      'Probleme moto / panne',
    ],
    bool includeGeo = true,
  }) async {
    HapticFeedback.heavyImpact();
    return showModalBottomSheet<ReasonPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReasonSheet(
        title: title,
        description: description,
        presets: presets,
        includeGeo: includeGeo,
      ),
    );
  }
}

class _ReasonSheet extends StatefulWidget {
  final String title;
  final String description;
  final List<String> presets;
  final bool includeGeo;

  const _ReasonSheet({
    required this.title,
    required this.description,
    required this.presets,
    required this.includeGeo,
  });

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  String? _selectedPreset;
  final TextEditingController _customController = TextEditingController();
  bool _capturingGeo = false;
  double? _lat;
  double? _lng;

  String get _composed {
    final preset = _selectedPreset ?? '';
    final extra = _customController.text.trim();
    if (preset.isEmpty && extra.isEmpty) return '';
    if (preset.isEmpty) return extra;
    if (extra.isEmpty) return preset;
    return '$preset · $extra';
  }

  bool get _canConfirm => _composed.isNotEmpty;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _captureGeo() async {
    if (_capturingGeo) return;
    setState(() => _capturingGeo = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _capturingGeo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _capturingGeo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final surfaceColor =
        isDarkMode ? AppColors.darkSurface : Colors.white;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 14.h),
                  decoration: BoxDecoration(
                    color: textLightColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text(
                widget.title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                widget.description,
                style: TextStyle(
                  color: textLightColor,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 16.h),
              // Presets en chips
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: widget.presets
                    .map((p) => _PresetChip(
                          label: p,
                          selected: _selectedPreset == p,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedPreset =
                                  (_selectedPreset == p) ? null : p;
                            });
                          },
                        ))
                    .toList(),
              ),
              SizedBox(height: 16.h),
              // Champ libre (precision)
              TextField(
                controller: _customController,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: textColor, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'Precise si besoin (optionnel)',
                  hintStyle: TextStyle(
                    color: textLightColor.withValues(alpha: 0.6),
                    fontSize: 13.sp,
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                ),
              ),
              if (widget.includeGeo) ...[
                SizedBox(height: 12.h),
                _GeoStatusRow(
                  lat: _lat,
                  lng: _lng,
                  capturing: _capturingGeo,
                  onCapture: _captureGeo,
                  textColor: textColor,
                  textLightColor: textLightColor,
                ),
              ],
              SizedBox(height: 20.h),
              // Swipe-to-confirm bottom (action irreversible)
              Opacity(
                opacity: _canConfirm ? 1 : 0.4,
                child: IgnorePointer(
                  ignoring: !_canConfirm,
                  child: ZeetSwipeToConfirm(
                    variant: ZeetSwipeConfirmVariant.destructive,
                    label: 'Glisser pour confirmer',
                    confirmedLabel: 'Signalement envoye',
                    onConfirmed: () {
                      Navigator.of(context).pop(
                        ReasonPickerResult(
                          reason: _composed,
                          geoLat: _lat,
                          geoLng: _lng,
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                      color: textLightColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final fg = selected
        ? Colors.white
        : (isDarkMode ? AppColors.darkText : AppColors.text);
    final bg = selected
        ? AppColors.primary
        : (isDarkMode
            ? AppColors.darkSurface
            : Colors.grey.withValues(alpha: 0.1));
    final border = selected
        ? AppColors.primary
        : (isDarkMode
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.3));

    return InkWell(
      borderRadius: BorderRadius.circular(20.r),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _GeoStatusRow extends StatelessWidget {
  final double? lat;
  final double? lng;
  final bool capturing;
  final VoidCallback onCapture;
  final Color textColor;
  final Color textLightColor;

  const _GeoStatusRow({
    required this.lat,
    required this.lng,
    required this.capturing,
    required this.onCapture,
    required this.textColor,
    required this.textLightColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasGeo = lat != null && lng != null;
    return Row(
      children: [
        Icon(
          hasGeo ? Icons.gps_fixed : Icons.gps_not_fixed,
          color: hasGeo ? Colors.green : textLightColor,
          size: 18.sp,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            hasGeo
                ? 'Position capturee : ${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}'
                : 'Capturer ta position aide les enquetes (optionnel)',
            style: TextStyle(
              color: textLightColor,
              fontSize: 12.sp,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: capturing ? null : onCapture,
          child: capturing
              ? SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  hasGeo ? 'Refaire' : 'Capturer',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}
