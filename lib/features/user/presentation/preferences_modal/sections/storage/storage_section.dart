import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageSection extends StatelessWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return const SizedBox.shrink();

    final textColor = context.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.normal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Storage',
            style: AppTextStyle.bodySmall.copyWith(color: textColor),
          ),
          const SizedBox(height: Insets.small),
          AppButton(
            label: 'Reset App Data',
            variant: AppButtonVariant.outlined,
            backgroundColor: AppColors.error,
            fullWidth: false,
            onPressed: () => _showResetConfirmationDialog(context),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => const _ResetConfirmationDialog(),
    );
  }
}

class _ResetConfirmationDialog extends StatefulWidget {
  const _ResetConfirmationDialog();

  @override
  State<_ResetConfirmationDialog> createState() =>
      _ResetConfirmationDialogState();
}

class _ResetConfirmationDialogState extends State<_ResetConfirmationDialog> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final confirmed = _controller.text.trim() == 'RESET';
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
              Text(
                'Reset App Data',
                style: AppTextStyle.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Insets.normal),
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
                        'This will permanently delete all your data including synced records, notes, attachments, and preferences.',
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
                'Type RESET to confirm:',
                style: AppTextStyle.labelMedium.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: Insets.small),
              TextField(
                controller: _controller,
                enabled: !_isProcessing,
                decoration: InputDecoration(
                  hintText: 'RESET',
                  hintStyle: AppTextStyle.bodySmall.copyWith(
                    color:
                        context.colorScheme.onSurface.withValues(alpha: 0.3),
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.transparent,
                    fullWidth: false,
                    onPressed:
                        _isProcessing ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: Insets.small),
                  AppButton(
                    label: _isProcessing ? 'Deleting...' : 'Delete',
                    variant: AppButtonVariant.primary,
                    backgroundColor: AppColors.error,
                    fullWidth: false,
                    enabled: _isConfirmed && !_isProcessing,
                    onPressed: _isConfirmed && !_isProcessing
                        ? () => _performReset()
                        : null,
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

    final db = getIt<AppDatabase>();
    await db.delete(db.fhirResource).go();
    await db.delete(db.sources).go();
    await db.delete(db.recordNotes).go();
    await db.delete(db.processingSessions).go();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final cacheDir = await getTemporaryDirectory();
    if (cacheDir.existsSync()) {
      await cacheDir.delete(recursive: true);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    if (docsDir.existsSync()) {
      await docsDir.delete(recursive: true);
    }

    exit(0);
  }
}
