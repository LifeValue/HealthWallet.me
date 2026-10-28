import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/user/data/service/app_data_reset_service.dart';

/// The word the user types to confirm a reset. It is the same in every
/// language, and the prompt shows this exact word, so the check below always
/// compares against what the user was asked to type.
const resetConfirmationWord = 'RESET';

class StorageSection extends StatelessWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS && !Platform.isWindows) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.small),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settingsStorage,
                  style: AppTextStyle.bodySmall,
                ),
                Text(
                  context.l10n.settingsStorageDescription,
                  style: AppTextStyle.labelSmall.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: () => _showResetDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                context.l10n.settingsReset,
                style: AppTextStyle.buttonSmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const ResetConfirmationDialog(),
    );
  }
}

class ResetConfirmationDialog extends StatefulWidget {
  const ResetConfirmationDialog({super.key, this.onReset});

  /// Deletes the data once confirmed; by default [AppDataResetService.reset]
  /// followed by quitting the app.
  final Future<void> Function()? onReset;

  @override
  State<ResetConfirmationDialog> createState() =>
      _ResetConfirmationDialogState();
}

class _ResetConfirmationDialogState extends State<ResetConfirmationDialog> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final confirmed = _controller.text.trim() == resetConfirmationWord;
      if (confirmed != _isConfirmed) {
        setState(() => _isConfirmed = confirmed);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(Insets.medium),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.normal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Insets.smallNormal),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: Insets.small),
                    Expanded(
                      child: Text(
                        context.l10n.resetDataWarning,
                        style: AppTextStyle.labelMedium.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.normal),
              Text(
                context.l10n.resetTypeToConfirm(resetConfirmationWord),
                style: AppTextStyle.labelMedium.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: Insets.small),
              TextField(
                controller: _controller,
                enabled: !_isProcessing,
                style: AppTextStyle.labelLarge,
                decoration: InputDecoration(
                  hintText: resetConfirmationWord,
                  hintStyle: AppTextStyle.labelLarge.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.smallNormal,
                    vertical: Insets.small,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(height: Insets.normal),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(
                        context.l10n.cancel,
                        style: AppTextStyle.buttonMedium.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.small),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isConfirmed && !_isProcessing
                          ? _performReset
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        disabledBackgroundColor: AppColors.error.withValues(
                          alpha: 0.3,
                        ),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: Insets.smallNormal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isProcessing
                            ? context.l10n.deleting
                            : context.l10n.delete,
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

  Future<void> _performReset() async {
    setState(() => _isProcessing = true);

    final onReset = widget.onReset;
    if (onReset != null) {
      await onReset();
      return;
    }
    await AppDataResetService(getIt<AppDatabase>()).reset();
    exit(0);
  }
}
