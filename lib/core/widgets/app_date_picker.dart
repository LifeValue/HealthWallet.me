import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class AppDatePicker {
  static Future<DateTime?> show({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final effectiveFirstDate = firstDate ?? DateTime(1900);
    final effectiveLastDate = lastDate ?? now;
    final effectiveInitialDate = initialDate ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: effectiveInitialDate,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      builder: (context, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: context.colorScheme,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: child!,
            ),
          ),
        );
      },
    );

    return pickedDate;
  }
}
