import 'dart:io';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/data/local/app_database.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageSection extends StatelessWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.small),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Storage',
                  style: AppTextStyle.bodySmall,
                ),
                Text(
                  'Clear all records, preferences and cached data',
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
                'Reset',
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
      builder: (_) => const _ResetConfirmationDialog(),
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
                style: AppTextStyle.labelLarge,
                decoration: InputDecoration(
                  hintText: 'RESET',
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
                      onPressed:
                          _isProcessing ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
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
                        disabledBackgroundColor:
                            AppColors.error.withValues(alpha: 0.3),
                        foregroundColor: Colors.white,
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(
                            vertical: Insets.smallNormal),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(_isProcessing ? 'Deleting...' : 'Delete'),
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

    try {
      final db = getIt<AppDatabase>();
      await db.delete(db.fhirResource).go();
      await db.delete(db.sources).go();
      await db.delete(db.recordNotes).go();
      await db.delete(db.processingSessions).go();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      try {
        final cacheDir = await getTemporaryDirectory();
        if (cacheDir.existsSync()) {
          await cacheDir.delete(recursive: true);
        }
      } catch (_) {}

      try {
        final supportDir = await getApplicationSupportDirectory();
        final shareDir = Directory('${supportDir.path}/share_sessions');
        if (shareDir.existsSync()) {
          await shareDir.delete(recursive: true);
        }
      } catch (_) {}
    } catch (_) {}

    exit(0);
  }
}
