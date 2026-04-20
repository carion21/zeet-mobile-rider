// lib/screens/delivery_details/widgets/report_issue_sheet.dart
//
// Bottom sheet "Signaler un souci" contextualisee depuis l'ecran detail
// d'une mission. Presets de motifs en chips, champ note optionnel, submit
// en 1 tap. Skill `zeet-pos-ergonomics` (1 main / saisie minimale),
// `zeet-micro-copy` (rider direct), `zeet-3-clicks-rule` (support
// accessible en 2 taps depuis le detail mission).
//
// Hook API : la creation du ticket reel est deferred a l'integration de
// l'endpoint backend (TODO support/index.dart:405). En attendant, on log
// le payload et on retourne success pour ne pas bloquer le rider.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/widgets/toastification.dart';
import 'package:rider/services/support_service.dart';
import 'package:zeet_ui/zeet_ui.dart';

const List<String> _kIssueReasons = <String>[
  'Adresse introuvable',
  'Client injoignable',
  'Restaurant ferme',
  'Probleme mecanique',
  'Commande incomplete',
  'Probleme de paiement',
];

/// Helper. `missionRef` et `missionId` permettent de pre-remplir le ticket.
/// `addressContext` (optionnel) = adresse pickup ou dropoff selon contexte.
Future<void> showReportIssueSheet(
  BuildContext context, {
  required String missionRef,
  required String missionId,
  String? addressContext,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (BuildContext ctx) => _ReportIssueSheet(
      missionRef: missionRef,
      missionId: missionId,
      addressContext: addressContext,
    ),
  );
}

class _ReportIssueSheet extends StatefulWidget {
  const _ReportIssueSheet({
    required this.missionRef,
    required this.missionId,
    required this.addressContext,
  });

  final String missionRef;
  final String missionId;
  final String? addressContext;

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  String? _selectedReason;
  final TextEditingController _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null || _submitting) return;
    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    final result = await SupportService().createTicket(
      missionId: widget.missionId,
      missionRef: widget.missionRef,
      reason: _selectedReason!,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      addressContext: widget.addressContext,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      AppToast.showSuccess(
        context: context,
        message: result['message'] as String,
      );
    } else {
      setState(() => _submitting = false);
      AppToast.showError(
        context: context,
        message: result['message'] as String,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final canSubmit = _selectedReason != null && !_submitting;

    return Padding(
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
            children: <Widget>[
              // Handle drag visuel.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Signaler un souci',
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                widget.addressContext == null
                    ? 'Mission ${widget.missionRef}'
                    : 'Mission ${widget.missionRef} · ${widget.addressContext}',
                style: tt.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 18.h),
              Text(
                'Quel est le souci ?',
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: 10.h),
              // Chips presets : 1 tap pour selectionner.
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _kIssueReasons.map((reason) {
                  final selected = _selectedReason == reason;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedReason = reason);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? ZeetColors.primary
                            : ZeetColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: selected
                              ? ZeetColors.primary
                              : ZeetColors.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : ZeetColors.primary,
                          fontSize: 13.sp,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 18.h),
              TextField(
                controller: _noteController,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Ajoute un detail (optionnel)',
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13.sp,
                  ),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZeetColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: ZeetColors.primary
                              .withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: canSubmit ? _submit : null,
                        child: _submitting
                            ? SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Envoyer',
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
}
