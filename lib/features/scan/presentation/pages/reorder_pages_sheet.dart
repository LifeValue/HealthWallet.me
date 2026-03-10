import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class ReorderPagesSheet extends StatefulWidget {
  final List<String> imagePaths;

  const ReorderPagesSheet({super.key, required this.imagePaths});

  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> imagePaths,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ReorderPagesSheet(imagePaths: imagePaths),
    );
  }

  @override
  State<ReorderPagesSheet> createState() => _ReorderPagesSheetState();
}

class _ReorderPagesSheetState extends State<ReorderPagesSheet> {
  late List<String> _paths;

  @override
  void initState() {
    super.initState();
    _paths = List.from(widget.imagePaths);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        context.isDarkMode ? AppColors.borderDark : AppColors.border;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.normal,
              vertical: Insets.smallNormal,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.l10n.cancel,
                    style: AppTextStyle.buttonSmall
                        .copyWith(color: AppColors.primary),
                  ),
                ),
                Text(
                  context.l10n.reorderPages,
                  style: AppTextStyle.bodyMedium,
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_paths),
                  child: Text(
                    context.l10n.done,
                    style: AppTextStyle.buttonSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: borderColor),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: scrollController,
              padding: const EdgeInsets.all(Insets.smallNormal),
              itemCount: _paths.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _paths.removeAt(oldIndex);
                  _paths.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                return _ReorderablePageItem(
                  key: ValueKey(_paths[index]),
                  index: index,
                  path: _paths[index],
                  totalCount: _paths.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderablePageItem extends StatelessWidget {
  final int index;
  final String path;
  final int totalCount;

  const _ReorderablePageItem({
    super.key,
    required this.index,
    required this.path,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        context.isDarkMode ? AppColors.borderDark : AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: Insets.small),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const SizedBox(width: Insets.smallNormal),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(path),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 24),
              ),
            ),
          ),
          const SizedBox(width: Insets.smallNormal),
          Expanded(
            child: Text(
              '${context.l10n.page} ${index + 1} / $totalCount',
              style: AppTextStyle.labelLarge,
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(Insets.smallNormal),
              child: Icon(
                Icons.drag_handle,
                color: context.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
