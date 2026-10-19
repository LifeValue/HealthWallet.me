import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:health_wallet/features/home/presentation/widgets/shaking_card.dart';

/// A reusable reorderable grid for any type of item.
class ReorderableGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final bool enabled;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsets? padding;

  const ReorderableGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.childAspectRatio = 2,
    this.enabled = true,
    this.physics,
    this.shrinkWrap = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return ReorderableGridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics ?? const NeverScrollableScrollPhysics(),
        padding: padding ?? EdgeInsets.zero,
        placeholderBuilder: (dropIndex, dropInIndex, dragWidget) {
          return const SizedBox();
        },
        dragWidgetBuilderV2: DragWidgetBuilderV2(
          builder: (index, child, screenshot) => Material(
            color: Colors.transparent,
            child: child,
          ),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: items.length,
        dragStartDelay: const Duration(milliseconds: 100),
        itemBuilder: (context, index) {
          final item = items[index];
          return ReorderableDragStartListener(
            key: ValueKey(item),
            index: index,
            child: ShakingCard(
              isShaking: enabled,
              child: itemBuilder(context, item, index),
            ),
          );
        },
        onReorder: onReorder,
      );
    } else {
      return GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics ?? const NeverScrollableScrollPhysics(),
        padding: padding ?? EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return itemBuilder(context, item, index);
        },
      );
    }
  }
}
