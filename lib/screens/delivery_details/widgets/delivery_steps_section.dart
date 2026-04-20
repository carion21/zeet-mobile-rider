// lib/screens/delivery_details/widgets/delivery_steps_section.dart
//
// Stepper visuel "recuperation -> livraison".
// Affiche une barre de progression animee (shimmer) selon le statut mission.
//
// Pas de logique metier : recoit `status` en input et rend.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rider/core/constants/colors.dart';
import 'package:rider/core/constants/icons.dart';
import 'package:zeet_ui/zeet_ui.dart';

class DeliveryStepsSection extends StatefulWidget {
  final String? status;
  final Color dividerColor;

  const DeliveryStepsSection({
    super.key,
    required this.status,
    required this.dividerColor,
  });

  @override
  State<DeliveryStepsSection> createState() => _DeliveryStepsSectionState();
}

class _DeliveryStepsSectionState extends State<DeliveryStepsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _startShimmerAnimation();
  }

  @override
  void dispose() {
    _shimmerCooldown?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  /// Boucle shimmer pilotee par le AnimationController (skill
  /// `zeet-performance-budget` §8 — pas de Future.delayed orphelin).
  /// La pause de 5s est portee par un Timer cancellable, qui ne survit pas
  /// au dispose() du widget.
  Timer? _shimmerCooldown;

  void _startShimmerAnimation() {
    void schedule() {
      _shimmerCooldown?.cancel();
      _shimmerCooldown = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        _shimmerController.forward(from: 0);
      });
    }

    _shimmerController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _shimmerController.reset();
        schedule();
      }
    });
    schedule();
  }

  double _progressFor(String? status) {
    if (status == 'accepted') return 0.3;
    if (status == 'collecting' ||
        status == 'collected' ||
        status == 'picked_up' ||
        status == 'delivering') {
      return 0.65;
    }
    if (status == 'delivered') return 1.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progressFor(widget.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: widget.dividerColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              if (progress > 0)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: Stack(
                      children: [
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                        if (_shimmerController.value > 0 && progress < 1.0)
                          Positioned(
                            left: -100 + (_shimmerController.value * 200),
                            child: Container(
                              width: 100,
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.6),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (progress > 0 && progress < 1.0)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconManager.getIcon(
                        'motorcycle',
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              if (progress >= 1.0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: ZeetColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: IconManager.getIcon(
                      'check',
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
