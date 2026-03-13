import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class SourceLabelEditDialog extends StatefulWidget {
  final Source source;
  final Function(String) onLabelChanged;

  const SourceLabelEditDialog({
    super.key,
    required this.source,
    required this.onLabelChanged,
  });

  static void show(
    BuildContext context,
    Source source,
    Function(String) onLabelChanged,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: SourceLabelEditDialog(
            source: source,
            onLabelChanged: onLabelChanged,
          ),
        );
      },
    );
  }

  @override
  State<SourceLabelEditDialog> createState() => _SourceLabelEditDialogState();
}

class _SourceLabelEditDialogState extends State<SourceLabelEditDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.source.labelSource ?? widget.source.platformName ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final newLabel = _controller.text.trim();
      widget.onLabelChanged(newLabel);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.errorUpdatingSourceLabel}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;
    final textColor = context.primaryTextColor;
    final iconColor = context.secondaryTextColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(Insets.medium),
      child: Container(
        width: 350,
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.normal, vertical: Insets.small),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6)),
                        child: IconButton(
                          icon: Assets.icons.edit.svg(
                            colorFilter:
                                ColorFilter.mode(textColor, BlendMode.srcIn),
                          ),
                          onPressed: _handleCancel,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: Insets.small),
                      Text(context.l10n.editSourceLabel,
                          style: AppTextStyle.bodySmall
                              .copyWith(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration:
                        BoxDecoration(borderRadius: BorderRadius.circular(6)),
                    child: IconButton(
                      icon: Assets.icons.close.svg(
                        colorFilter:
                            ColorFilter.mode(textColor, BlendMode.srcIn),
                      ),
                      onPressed: _handleCancel,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(Insets.normal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.provideCustomLabel,
                    style: AppTextStyle.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: Insets.small),
                  Text(
                    widget.source.id,
                    style: AppTextStyle.bodySmall.copyWith(
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: Insets.medium),
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.smaller),
                    child: Text(
                      context.l10n.sourceName,
                      style: AppTextStyle.bodySmall.copyWith(
                        color: context.isDarkMode
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: context.l10n.pleaseEnterSourceName,
                      hintStyle: AppTextStyle.labelLarge.copyWith(
                        color: context.isDarkMode
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: context.isDarkMode
                              ? AppColors.borderDark
                              : AppColors.border,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: context.isDarkMode
                              ? AppColors.borderDark
                              : AppColors.border,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: context.colorScheme.primary,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Insets.small,
                        vertical: Insets.small,
                      ),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Assets.icons.close.svg(
                                colorFilter: ColorFilter.mode(
                                  context.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  BlendMode.srcIn,
                                ),
                                width: 16,
                                height: 16,
                              ),
                              onPressed: () {
                                _controller.clear();
                                setState(() {});
                                _focusNode.requestFocus();
                              },
                              padding: EdgeInsets.zero,
                            )
                          : null,
                    ),
                    maxLines: 1,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.medium),
            Padding(
              padding: const EdgeInsets.all(Insets.normal),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: Insets.small),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(context.l10n.cancel,
                          style: AppTextStyle.buttonSmall),
                    ),
                  ),
                  const SizedBox(width: Insets.small),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: Insets.small),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(context.l10n.saveDetails,
                              style: AppTextStyle.buttonSmall),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
