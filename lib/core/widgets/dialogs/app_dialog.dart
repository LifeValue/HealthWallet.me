import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

/// Unified dialog widget that handles all selection cases (single, multi, filter)
/// Uses the exact design pattern from filter_home_dialog.dart
class AppDialog extends StatefulWidget {
  final String title;
  final String description;
  final List<DialogItem> items;
  final AppDialogMode mode;
  final List<String>? initiallySelected;
  final String cancelText;
  final String confirmText;
  final String? validationMessage;
  final bool Function(List<String> selected)? canConfirm;
  final void Function(List<String> selected)? onConfirm;
  final VoidCallback? onCancel;
  final Widget? customContent;
  final Color? confirmButtonColor;

  const AppDialog({
    super.key,
    required this.title,
    this.description = '',
    this.items = const [],
    this.mode = AppDialogMode.multiSelect,
    this.initiallySelected,
    this.cancelText = 'Cancel',
    this.confirmText = 'Add',
    this.validationMessage,
    this.canConfirm,
    this.onConfirm,
    this.onCancel,
    this.customContent,
    this.confirmButtonColor,
  });

  /// Show multi-select dialog
  static Future<List<String>?> showMultiSelect({
    required BuildContext context,
    required String title,
    required String description,
    required List<DialogItem> items,
    List<String>? initiallySelected,
    String cancelText = 'Cancel',
    String confirmText = 'Add',
    String? validationMessage,
  }) async {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        description: description,
        items: items,
        mode: AppDialogMode.multiSelect,
        initiallySelected: initiallySelected,
        cancelText: cancelText,
        confirmText: confirmText,
        validationMessage: validationMessage,
      ),
    );
  }

  /// Show single-select dialog
  static Future<String?> showSingleSelect({
    required BuildContext context,
    required String title,
    required String description,
    required List<DialogItem> items,
    String? initiallySelected,
    String cancelText = 'Cancel',
    String confirmText = 'Add',
  }) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AppDialog(
        title: title,
        description: description,
        items: items,
        mode: AppDialogMode.singleSelect,
        initiallySelected:
            initiallySelected != null ? [initiallySelected] : null,
        cancelText: cancelText,
        confirmText: confirmText,
      ),
    );
    return result?.firstOrNull;
  }

  @override
  State<AppDialog> createState() => _AppDialogState();
}

enum AppDialogMode {
  singleSelect,
  multiSelect,
  confirmation,
}

class DialogItem {
  final String id;
  final String label;

  const DialogItem({
    required this.id,
    required this.label,
  });
}

class _AppDialogState extends State<AppDialog> {
  late Map<String, bool> _selectedItems;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _selectedItems = {};
    for (final item in widget.items) {
      _selectedItems[item.id] =
          widget.initiallySelected?.contains(item.id) ?? false;
    }
  }

  bool _canConfirm() {
    if (widget.mode == AppDialogMode.confirmation) {
      return true; // Confirmation dialogs are always confirmable
    }
    if (widget.canConfirm != null) {
      return widget.canConfirm!(_getSelectedIds());
    }
    return _selectedItems.values.any((isSelected) => isSelected);
  }

  List<String> _getSelectedIds() {
    return _selectedItems.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  void _selectAll() {
    setState(() {
      for (final item in widget.items) {
        _selectedItems[item.id] = true;
      }
      _showDropdown = false;
    });
  }

  void _clearAll() {
    setState(() {
      for (final item in widget.items) {
        _selectedItems[item.id] = false;
      }
      _showDropdown = false;
    });
  }

  void _toggleItem(String id) {
    setState(() {
      if (widget.mode == AppDialogMode.singleSelect) {
        // For single select, clear all and set only this one
        for (final key in _selectedItems.keys) {
          _selectedItems[key] = false;
        }
        _selectedItems[id] = true;
      } else {
        // For multi-select, toggle
        _selectedItems[id] = !(_selectedItems[id] ?? false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final borderColor =
        context.isDarkMode ? AppColors.borderDark : AppColors.border;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(Insets.normal),
        child: Container(
          width: 350,
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.normal,
                      vertical: Insets.small,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.title,
                          style: AppTextStyle.bodyMedium
                              .copyWith(color: textColor),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.close,
                              color: textColor,
                              size: 24,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onCancel?.call();
                            },
                            padding: const EdgeInsets.all(9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(height: 1, color: borderColor),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(Insets.normal),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description row (only show if not confirmation mode or if no customContent)
                        if (widget.mode != AppDialogMode.confirmation ||
                            widget.customContent == null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 227,
                                child: Text(
                                  widget.description,
                                  style: AppTextStyle.labelLarge
                                      .copyWith(color: textColor),
                                ),
                              ),
                              if (widget.mode == AppDialogMode.multiSelect)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showDropdown = !_showDropdown;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: textColor, width: 2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _showDropdown
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: textColor,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        if (widget.mode != AppDialogMode.confirmation) ...[
                          const SizedBox(height: Insets.normal),
                          Container(height: 1, color: borderColor),
                          const SizedBox(height: Insets.normal),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 400),
                            child: SingleChildScrollView(
                              child: Column(
                                children: _buildItemList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: Insets.normal),
                        ] else ...[
                          if (widget.customContent != null)
                            widget.customContent!,
                        ],
                        if (!_canConfirm() &&
                            widget.mode != AppDialogMode.confirmation)
                          Container(
                            padding: const EdgeInsets.all(Insets.smallNormal),
                            margin:
                                const EdgeInsets.only(bottom: Insets.normal),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.error.withOpacity(0.3),
                                  width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: Insets.small),
                                Expanded(
                                  child: Text(
                                    widget.validationMessage ??
                                        'Select at least one item to continue.',
                                    style: AppTextStyle.labelLarge
                                        .copyWith(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onCancel?.call();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: Insets.small),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  widget.cancelText,
                                  style: AppTextStyle.buttonSmall
                                      .copyWith(color: AppColors.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: Insets.small),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _canConfirm()
                                    ? () {
                                        final selectedIds = _getSelectedIds();
                                        if (widget.onConfirm != null) {
                                          widget.onConfirm!(selectedIds);
                                        }
                                        Navigator.of(context).pop(selectedIds);
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _canConfirm()
                                      ? (widget.confirmButtonColor ??
                                          AppColors.primary)
                                      : textColor.withOpacity(0.2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: Insets.small),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  widget.confirmText,
                                  style: AppTextStyle.buttonSmall.copyWith(
                                    color: _canConfirm()
                                        ? Colors.white
                                        : textColor.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Dropdown overlay (only for multi-select)
              if (_showDropdown && widget.mode == AppDialogMode.multiSelect)
                Positioned(
                  top: 109,
                  left: Insets.normal,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    shadowColor: Colors.black.withOpacity(0.12),
                    child: Container(
                      width: 318,
                      decoration: BoxDecoration(
                        color: context.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        children: [
                          _buildDropdownItem(
                              context.l10n.selectAll, _selectAll),
                          _buildDropdownItem(context.l10n.clearAll, _clearAll),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownItem(String text, VoidCallback onTap) {
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text(
              text,
              style: AppTextStyle.labelLarge.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItemList() {
    return widget.items.map((item) {
      final isSelected = _selectedItems[item.id] ?? false;
      return _buildSelectableItem(
          item.label, isSelected, () => _toggleItem(item.id));
    }).toList();
  }

  Widget _buildSelectableItem(
      String label, bool isSelected, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyle.bodySmall.copyWith(color: textColor),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : textColor,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: colorScheme.onPrimary,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
