// lib/screens/delivery_details/widgets/delivery_otp_section.dart
//
// Dialogs OTP / motif redesignes :
//
//  - showOtpDialog : BOTTOM SHEET avec 4 cases separees, autofocus 1ere
//    case, auto-submit a la saisie complete, message inline "X tentatives
//    restantes" apres ERR_RIDER_OTP_INVALID, disable a 5 tentatives.
//    Le format bottom sheet evite que le clavier numerique masque les
//    cases (skill `zeet-pos-ergonomics` §1 — 1 main, glance ininterrompu).
//  - showReasonDialog : delegue au ReasonPickerSheet (presets + custom)
//    pour les motifs not-delivered. Pour les autres usages (reject) on
//    garde un TextField simple via showLegacyReasonDialog.
//
// Skill : zeet-pos-ergonomics (1 main / saisie rapide), zeet-micro-copy
// (rider direct), zeet-states-elae (erreur inline pas dialog).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/screens/delivery_details/widgets/reason_picker_sheet.dart';

class DeliveryOtpDialogs {
  /// Demande un code OTP.
  ///
  /// [onValidate] est appele a la saisie complete : doit retourner
  ///   - null si succes (le dialog se ferme, retourne le code)
  ///   - une `String` (message d'erreur) si echec, qui sera affichee
  ///     inline + reset automatique des cases pour ressaisie.
  ///
  /// [maxAttempts] (defaut 5) : apres N erreurs consecutives le bouton
  /// est disable et l'utilisateur doit demander un nouveau code (annuler).
  static Future<String?> showOtpDialog({
    required BuildContext context,
    required String title,
    String subtitle = 'Saisis le code à 4 chiffres',
    int length = 4,
    int maxAttempts = 5,
    Future<String?> Function(String code)? onValidate,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true, // permet d'occuper la zone clavier
      isDismissible: false, // anti tap-out accidentel
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _OtpBottomSheet(
        title: title,
        subtitle: subtitle,
        length: length,
        maxAttempts: maxAttempts,
        onValidate: onValidate,
      ),
    );
  }

  /// Demande une raison via le ReasonPickerSheet (presets + custom).
  /// Utilise pour /not-delivered. Inclut GPS optionnellement.
  static Future<ReasonPickerResult?> showReasonDialog({
    required BuildContext context,
    required String title,
    String hint = '',
    bool includeGeo = false,
    List<String>? presets,
  }) {
    return ReasonPickerSheet.show(
      context: context,
      title: title,
      includeGeo: includeGeo,
      presets: presets ??
          const <String>[
            'Client injoignable',
            'Adresse fausse',
            'Refus client',
            'Restaurant ferme',
            'Probleme moto / panne',
          ],
    );
  }

  /// Variante texte libre (utilisee pour /reject — moins critique).
  static Future<String?> showLegacyReasonDialog({
    required BuildContext context,
    required String title,
    String hint = 'Motif',
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.of(ctx).pop(v);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

// ---------------------------------------------------------------------------
// BottomSheet OTP a N cases — autofocus + auto-submit + tracking tentatives.
//
// Format bottom sheet (vs AlertDialog) : reste au-dessus du clavier
// numerique grace a viewInsets.bottom + isScrollControlled. Le rider
// garde toujours les cases visibles pendant la saisie. Skill
// `zeet-pos-ergonomics` §1 (1 main, glance ininterrompu).
// ---------------------------------------------------------------------------

class _OtpBottomSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final int length;
  final int maxAttempts;
  final Future<String?> Function(String code)? onValidate;

  const _OtpBottomSheet({
    required this.title,
    required this.subtitle,
    required this.length,
    required this.maxAttempts,
    required this.onValidate,
  });

  @override
  State<_OtpBottomSheet> createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends State<_OtpBottomSheet> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  int _attempts = 0;
  String? _errorMessage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _focusNodes = List<FocusNode>.generate(
      widget.length,
      (_) => FocusNode(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _currentCode() => _controllers.map((c) => c.text).join();

  void _resetCases() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) _focusNodes.first.requestFocus();
  }

  Future<void> _trySubmit() async {
    if (_busy) return;
    if (_attempts >= widget.maxAttempts) return;
    final code = _currentCode();
    if (code.length != widget.length) return;

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    if (widget.onValidate == null) {
      // Pas de validateur : retourne directement.
      if (mounted) Navigator.of(context).pop(code);
      return;
    }

    final String? err = await widget.onValidate!(code);
    if (!mounted) return;

    if (err == null) {
      Navigator.of(context).pop(code);
      return;
    }

    setState(() {
      _attempts += 1;
      final remaining = widget.maxAttempts - _attempts;
      if (remaining > 0) {
        _errorMessage =
            '$err — il te reste $remaining tentative${remaining > 1 ? 's' : ''}';
      } else {
        _errorMessage =
            'Trop de tentatives. Demande un nouveau code au partenaire.';
      }
      _busy = false;
    });
    HapticFeedback.heavyImpact();
    _resetCases();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final textLightColor =
        isDarkMode ? AppColors.darkTextLight : AppColors.textLight;
    final scheme = Theme.of(context).colorScheme;
    final disabled = _attempts >= widget.maxAttempts;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      // Repousse le contenu au-dessus du clavier (les cases restent
      // visibles meme quand le clavier numerique est ouvert).
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle drag visuel (skill `zeet-motion-system` §11 —
              // affordance bottom sheet).
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textLightColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                widget.subtitle,
                style: TextStyle(fontSize: 13.sp, color: textLightColor),
              ),
              SizedBox(height: 20.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List<Widget>.generate(
                  widget.length,
                  (i) => _OtpBox(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    disabled: disabled || _busy,
                    onChanged: (v) => _onBoxChanged(i, v),
                    onSubmitted: (_) => _trySubmit(),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: 14.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: AppColors.error, size: 16.sp),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 18.h),
              Row(
                children: [
                  // Annuler positionne A GAUCHE (loin du Confirmer = anti
                  // mis-tap, skill `zeet-pos-ergonomics` §2).
                  Expanded(
                    flex: 1,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Confirmer plein-largeur, hit target ≥56pt.
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: (disabled ||
                                _busy ||
                                _currentCode().length != widget.length)
                            ? null
                            : _trySubmit,
                        child: _busy
                            ? SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Confirmer',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onBoxChanged(int idx, String value) {
    if (_attempts >= widget.maxAttempts) return;
    if (value.length == 1) {
      // Avance au prochain
      if (idx + 1 < widget.length) {
        _focusNodes[idx + 1].requestFocus();
      } else {
        // Dernier rempli -> tente submit
        _focusNodes[idx].unfocus();
        _trySubmit();
      }
    } else if (value.isEmpty && idx > 0) {
      _focusNodes[idx - 1].requestFocus();
    }
    setState(() {/* rebuild bouton confirmer */});
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool disabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.disabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkText : AppColors.text;
    final borderColor = isDarkMode
        ? AppColors.darkTextLight.withValues(alpha: 0.3)
        : Colors.grey.withValues(alpha: 0.4);
    final fillColor =
        isDarkMode ? AppColors.darkSurface : Colors.grey.withValues(alpha: 0.06);

    return SizedBox(
      width: 56.w,
      height: 64.h,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: !disabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: TextStyle(
          fontSize: 24.sp,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: fillColor,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: borderColor, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide:
                BorderSide(color: borderColor.withValues(alpha: 0.5), width: 1),
          ),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
