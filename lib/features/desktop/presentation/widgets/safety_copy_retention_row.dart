import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/core/widgets/app_input_field.dart';
import 'package:health_wallet/features/desktop/backup/domain/utils/safety_copy_retention.dart';
import 'package:health_wallet/features/desktop/backup/presentation/bloc/backup_bloc.dart';

/// The Backup card's row under the backup folder: how many days the copy
/// made before every restore is kept, and a small editor to change it. A
/// valid number is sent as [SafetyCopyRetentionChanged]; anything else keeps
/// the editor open with a message.
class SafetyCopyRetentionRow extends StatefulWidget {
  const SafetyCopyRetentionRow({
    super.key,
    required this.days,
    this.isWorking = false,
  });

  /// The retention shown, in whole days.
  final int days;

  /// A backup or restore is running: the value can't be changed meanwhile.
  final bool isWorking;

  static const changeKey = Key('safety_copy_retention_change');
  static const fieldKey = Key('safety_copy_retention_field');
  static const saveKey = Key('safety_copy_retention_save');
  static const cancelKey = Key('safety_copy_retention_cancel');
  static const errorKey = Key('safety_copy_retention_error');

  /// Width of the number field: room for three digits.
  static const fieldWidth = 64.0;

  /// Height of the field and its buttons.
  static const controlHeight = 36.0;

  @override
  State<SafetyCopyRetentionRow> createState() => _SafetyCopyRetentionRowState();
}

class _SafetyCopyRetentionRowState extends State<SafetyCopyRetentionRow> {
  final _controller = TextEditingController();
  bool _editing = false;
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.text = '${widget.days}';
    setState(() {
      _editing = true;
      _invalid = false;
    });
  }

  void _cancel() => setState(() {
    _editing = false;
    _invalid = false;
  });

  void _save() {
    final days = SafetyCopyRetention.parseDays(_controller.text);
    if (days == null) {
      setState(() => _invalid = true);
      return;
    }
    context.read<BackupBloc>().add(SafetyCopyRetentionChanged(days));
    setState(() {
      _editing = false;
      _invalid = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.5);
    final smallStyle = AppTextStyle.labelSmall.copyWith(
      color: muted,
      fontSize: 11,
    );

    if (!_editing) {
      return Row(
        children: [
          Icon(Icons.history, size: 16, color: muted),
          const SizedBox(width: Insets.extraSmall),
          Expanded(
            child: Text(
              context.l10n.backupSafetyRetention(widget.days),
              style: smallStyle,
            ),
          ),
          const SizedBox(width: Insets.extraSmall),
          // The same text link as the backup folder's Change.
          InkWell(
            key: SafetyCopyRetentionRow.changeKey,
            onTap: widget.isWorking ? null : _startEditing,
            borderRadius: BorderRadius.circular(Insets.extraSmall),
            child: Padding(
              padding: const EdgeInsets.all(Insets.extraSmall),
              child: Text(
                context.l10n.desktopChange,
                style: smallStyle.copyWith(
                  color: widget.isWorking
                      ? context.colorScheme.onSurface.withValues(alpha: 0.3)
                      : context.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final typed = int.tryParse(_controller.text) ?? widget.days;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: SafetyCopyRetentionRow.fieldWidth,
              child: AppInputField(
                key: SafetyCopyRetentionRow.fieldKey,
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                height: SafetyCopyRetentionRow.controlHeight,
                onChanged: (_) => setState(() => _invalid = false),
              ),
            ),
            const SizedBox(width: Insets.small),
            Text(
              context.l10n.backupSafetyRetentionDaysUnit(typed),
              style: AppTextStyle.bodySmall.copyWith(
                color: context.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            AppButton(
              key: SafetyCopyRetentionRow.cancelKey,
              label: context.l10n.cancel,
              onPressed: _cancel,
              variant: AppButtonVariant.outlined,
              fullWidth: false,
              height: SafetyCopyRetentionRow.controlHeight,
              padding: const EdgeInsets.symmetric(horizontal: Insets.small),
            ),
            const SizedBox(width: Insets.small),
            AppButton(
              key: SafetyCopyRetentionRow.saveKey,
              label: context.l10n.save,
              onPressed: _save,
              fullWidth: false,
              height: SafetyCopyRetentionRow.controlHeight,
              padding: const EdgeInsets.symmetric(horizontal: Insets.small),
            ),
          ],
        ),
        const SizedBox(height: Insets.small),
        if (_invalid)
          Text(
            context.l10n.backupSafetyRetentionInvalid(
              SafetyCopyRetention.minDays,
              SafetyCopyRetention.maxDays,
            ),
            key: SafetyCopyRetentionRow.errorKey,
            style: smallStyle.copyWith(color: AppColors.error),
          )
        else
          Text(context.l10n.backupSafetyRetentionHint, style: smallStyle),
      ],
    );
  }
}
