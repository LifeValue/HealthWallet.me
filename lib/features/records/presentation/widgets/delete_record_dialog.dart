import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/display_names.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';

/// Asks which of a record's related resources to delete along with it. The
/// related resources are an optional checklist; Cancel and Delete stay at the
/// bottom while the list scrolls. Pops the selected ids (empty to delete only
/// the record), or null when closed without deleting.
class DeleteRecordDialog extends StatefulWidget {
  const DeleteRecordDialog({
    required this.recordTitle,
    required this.relatedResources,
    super.key,
  });

  final String recordTitle;
  final List<IFhirResource> relatedResources;

  static const Key closeKey = Key('delete_record_dialog_close');
  static const Key toggleAllKey = Key('delete_record_dialog_toggle_all');
  static const Key cancelKey = Key('delete_record_dialog_cancel');
  static const Key deleteKey = Key('delete_record_dialog_delete');

  static Future<List<String>?> show(
    BuildContext context, {
    required String recordTitle,
    required List<IFhirResource> relatedResources,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => DeleteRecordDialog(
        recordTitle: recordTitle,
        relatedResources: relatedResources,
      ),
    );
  }

  @override
  State<DeleteRecordDialog> createState() => _DeleteRecordDialogState();
}

class _DeleteRecordDialogState extends State<DeleteRecordDialog> {
  final _selectedIds = <String>{};

  bool get _allSelected =>
      _selectedIds.length == widget.relatedResources.length;

  void _toggle(String id) => setState(() {
    if (!_selectedIds.remove(id)) _selectedIds.add(id);
  });

  void _toggleAll() => setState(() {
    if (_allSelected) {
      _selectedIds.clear();
    } else {
      _selectedIds.addAll(widget.relatedResources.map((r) => r.id));
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textColor = context.primaryTextColor;
    final borderColor = context.borderColor;
    final error = context.colorScheme.error;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(Insets.normal),
        child: Container(
          width: context.dialogWidth,
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.normal,
                  Insets.small,
                  Insets.small,
                  Insets.small,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.deleteRecordOfType(widget.recordTitle),
                        style: AppTextStyle.bodyMedium.copyWith(
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      key: DeleteRecordDialog.closeKey,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: Icon(Icons.close, color: textColor, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: borderColor),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.normal,
                    Insets.normal,
                    Insets.normal,
                    0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.relatedResourcesKeptHint,
                        style: AppTextStyle.bodySmall.copyWith(
                          color: context.secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: Insets.normal),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.relatedResourcesCount(
                                widget.relatedResources.length,
                              ),
                              style: AppTextStyle.labelLarge.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AppButton(
                            key: DeleteRecordDialog.toggleAllKey,
                            label: _allSelected
                                ? l10n.deselectAll
                                : l10n.selectAll,
                            onPressed: _toggleAll,
                            variant: AppButtonVariant.transparent,
                            fullWidth: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.small,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.small),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: widget.relatedResources.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Insets.small),
                          itemBuilder: (_, index) {
                            final resource = widget.relatedResources[index];
                            return _RelatedResourceTile(
                              resource: resource,
                              selected: _selectedIds.contains(resource.id),
                              onTap: () => _toggle(resource.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Insets.normal),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        key: DeleteRecordDialog.cancelKey,
                        label: l10n.cancel,
                        onPressed: () => Navigator.of(context).pop(),
                        variant: AppButtonVariant.outlined,
                        padding: const EdgeInsets.symmetric(
                          vertical: Insets.smallNormal,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.small),
                    Expanded(
                      child: AppButton(
                        key: DeleteRecordDialog.deleteKey,
                        label: _selectedIds.isEmpty
                            ? l10n.deletePage
                            : l10n.deletePlusRelated(_selectedIds.length),
                        onPressed: () =>
                            Navigator.of(context).pop(_selectedIds.toList()),
                        backgroundColor: error,
                        padding: const EdgeInsets.symmetric(
                          vertical: Insets.smallNormal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelatedResourceTile extends StatelessWidget {
  const _RelatedResourceTile({
    required this.resource,
    required this.selected,
    required this.onTap,
  });

  final IFhirResource resource;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final error = context.colorScheme.error;
    final secondary = context.secondaryTextColor;

    return Material(
      color: selected
          ? error.withValues(alpha: context.isDarkMode ? 0.12 : 0.06)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Insets.small),
        side: BorderSide(
          color: selected ? error.withValues(alpha: 0.5) : context.borderColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.smallNormal),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? error : Colors.transparent,
                  border: Border.all(
                    color: selected ? error : secondary,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(Insets.extraSmall),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: Insets.smallNormal),
              resource.fhirType.icon.svg(
                width: 18,
                colorFilter: ColorFilter.mode(secondary, BlendMode.srcIn),
              ),
              const SizedBox(width: Insets.smallNormal),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.displayTitle,
                      style: AppTextStyle.bodySmall.copyWith(
                        color: context.primaryTextColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resource.fhirType.localizedName(context.l10n),
                      style: AppTextStyle.labelSmall.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
