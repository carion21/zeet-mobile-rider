// lib/screens/delivery_details/widgets/delivery_error_view.dart
//
// Vue d'erreur centree avec bouton "Reessayer". Le retry est delegue
// via [onRetry].

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rider/core/constants/icons.dart';

class DeliveryErrorView extends StatelessWidget {
  final String message;
  final Color textColor;
  final VoidCallback? onRetry;

  const DeliveryErrorView({
    super.key,
    required this.message,
    required this.textColor,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconManager.getIcon('error', color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: textColor, fontSize: 16.sp)),
          const SizedBox(height: 16),
          if (onRetry != null)
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
        ],
      ),
    );
  }
}
