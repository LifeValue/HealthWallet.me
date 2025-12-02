import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/date_format_utils.dart';
import 'package:health_wallet/core/widgets/dialogs/delete_confirmation_dialog.dart';
import 'package:health_wallet/features/sync/domain/entities/source.dart';
import 'package:health_wallet/gen/assets.gen.dart';

class SourceListDialog extends StatefulWidget {
  final List<Source> sources;
  final String? selectedSource;
  final Function(Source) onSourceSelected;
  final Function(Source)? onSourceEdit;
  final Function(Source)? onSourceDelete;

  const SourceListDialog({
    super.key,
    required this.sources,
    required this.selectedSource,
    required this.onSourceSelected,
    this.onSourceEdit,
    this.onSourceDelete,
  });

  static void show(
    BuildContext context,
    List<Source> sources,
    String? selectedSource,
    Function(Source) onSourceSelected, {
    Function(Source)? onSourceEdit,
    Function(Source)? onSourceDelete,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: SourceListDialog(
            sources: sources,
            selectedSource: selectedSource,
            onSourceSelected: onSourceSelected,
            onSourceEdit: onSourceEdit,
            onSourceDelete: onSourceDelete,
          ),
        );
      },
    );
  }

  @override
  State<SourceListDialog> createState() => _SourceListDialogState();
}

class _SourceListDialogState extends State<SourceListDialog> {
  @override
  Widget build(BuildContext context) {
    final borderColor = context.theme.dividerColor;
    final textColor =
        context.isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final iconColor = context.isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

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
                          icon: Assets.icons.settings.svg(
                            colorFilter:
                                ColorFilter.mode(textColor, BlendMode.srcIn),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: Insets.small),
                      Text('Sources',
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
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: borderColor),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: Insets.small),
                itemCount: _getSortedSources().length,
                itemBuilder: (context, index) {
                  final source = _getSortedSources()[index];
                  final isSelected = source.id == widget.selectedSource;
                  final isWallet = source.id == 'wallet';
                  final isAll = source.id == 'All';

                  return InkWell(
                    onTap: () {
                      widget.onSourceSelected(source);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: Insets.small),
                      padding:
                          const EdgeInsets.symmetric(vertical: Insets.small),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              source.platformType == 'wallet'
                                  ? Icons.account_balance_wallet
                                  : Icons.source,
                              size: 16,
                              color: source.platformType == 'wallet'
                                  ? Colors.green
                                  : (isSelected
                                      ? context.colorScheme.primary
                                      : iconColor),
                            ),
                          ),
                          const SizedBox(width: Insets.small),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getSourceDisplayName(context, source),
                                  style: AppTextStyle.bodyMedium.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : (source.platformType == 'wallet'
                                            ? FontWeight.w600
                                            : FontWeight.normal),
                                    color: isSelected
                                        ? context.colorScheme.primary
                                        : textColor,
                                  ),
                                ),
                                if (source.platformName == 'wallet-manual' &&
                                    source.createdAt != null)
                                  Text(
                                    'Uploaded ${DateFormatUtils.humanReadable(source.createdAt)}',
                                    style: AppTextStyle.bodySmall.copyWith(
                                      color: context.isDarkMode
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onSourceEdit != null &&
                                  !isAll &&
                                  !(isWallet &&
                                      source.platformType == 'wallet'))
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: GestureDetector(
                                    onTap: () {
                                      widget.onSourceEdit!(source);
                                    },
                                    child: Assets.icons.edit.svg(
                                      width: 20,
                                      color: context.theme.iconTheme.color ??
                                          context.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              if (widget.onSourceDelete != null &&
                                  !isAll &&
                                  !(isWallet &&
                                      source.platformType == 'wallet')) ...[
                                const SizedBox(width: 16),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: GestureDetector(
                                    onTap: () => _showDeleteConfirmationDialog(
                                        context, source),
                                    child: Assets.icons.trashCan.svg(
                                      width: 20,
                                      color: context.theme.iconTheme.color ??
                                          context.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Source> _getSortedSources() {
    final sources = List<Source>.from(widget.sources);

    final allSource = sources.where((s) => s.id == 'All').toList();

    List<Source> walletSource = [];
    final genericWalletList = sources
        .where((s) => s.id == 'wallet' && s.platformType == 'wallet')
        .toList();
    if (genericWalletList.isNotEmpty) {
      walletSource = [genericWalletList.first];
    } else {
      final walletList = sources
          .where((s) => s.platformType == 'wallet' && s.id != 'All')
          .toList();
      if (walletList.isNotEmpty) {
        walletSource = [walletList.first];
      }
    }

    final walletIds = walletSource.map((s) => s.id).toSet();
    final otherSources = sources
        .where((s) =>
            s.id != 'All' &&
            !walletIds.contains(s.id) &&
            s.platformType != 'wallet')
        .toList();

    otherSources.sort((a, b) {
      final nameA = _getSourceDisplayName(context, a).toLowerCase();
      final nameB = _getSourceDisplayName(context, b).toLowerCase();
      return nameA.compareTo(nameB);
    });

    return [...allSource, ...walletSource, ...otherSources];
  }

  String _getSourceDisplayName(BuildContext context, Source source) {
    if (source.id == 'All') {
      return 'All';
    }

    if (source.labelSource?.isNotEmpty == true) {
      return source.labelSource!;
    }
    if (source.platformName?.isNotEmpty == true) {
      return source.platformName!;
    }
    if (source.id.length > 20) {
      return context.l10n.unknownSource;
    }
    return source.id;
  }

  void _showDeleteConfirmationDialog(BuildContext context, Source source) {
    DeleteConfirmationDialog.show(
      context: context,
      title:
          'Are you sure you want to delete "${_getSourceDisplayName(context, source)}"?',
      onConfirm: () {
        widget.onSourceDelete!(source);
        Navigator.of(context).pop();
      },
    );
  }
}
