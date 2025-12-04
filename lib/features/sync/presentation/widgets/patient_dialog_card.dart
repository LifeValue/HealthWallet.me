import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/dialog_header.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/form_fields.dart';

/// A reusable card widget for patient dialogs that can be used
/// both inside dialogs and as a standalone card in other contexts.
class PatientDialogCard extends StatelessWidget {
  /// The header title text
  final String title;

  /// Optional header subtitle text
  final String? subtitle;

  /// The form content widget to display
  final Widget content;

  /// Whether the card is in a loading state
  final bool isLoading;

  /// Cancel button label
  final String cancelLabel;

  /// Save button label
  final String saveLabel;

  /// Called when cancel is pressed
  final VoidCallback onCancel;

  /// Called when save is pressed
  final VoidCallback onSave;

  /// Fixed width for the card (optional, defaults to 350)
  final double? width;

  const PatientDialogCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.content,
    required this.isLoading,
    required this.cancelLabel,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
    this.width = 350,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;
    final textColor =
        context.isDarkMode ? const Color(0xFFE0E0E0) : const Color(0xFF212121);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogHeader(
            textColor: textColor,
            onCancel: onCancel,
            title: title,
            subtitle: subtitle,
          ),
          Container(height: 1, color: borderColor),
          Flexible(child: content),
          Padding(
            padding: const EdgeInsets.all(Insets.normal),
            child: FormFields.buildActionButtons(
              onCancel: onCancel,
              onSave: onSave,
              isLoading: isLoading,
              cancelLabel: cancelLabel,
              saveLabel: saveLabel,
            ),
          ),
        ],
      ),
    );
  }
}

