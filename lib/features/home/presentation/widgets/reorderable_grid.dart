import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health_wallet/features/home/presentation/widgets/shaking_card.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

/// A reusable reorderable grid for any type of item.
class ReorderableGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  /// Cells are never shorter than this, whatever [childAspectRatio] gives: a
  /// narrow column (a small tablet, a large text size) leaves the ratio too
  /// little height for the card's text. Measure it with [measureLineHeight].
  final double minItemHeight;
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
    this.minItemHeight = 0,
    this.enabled = true,
    this.physics,
    this.shrinkWrap = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildGrid(_gridDelegate(constraints.maxWidth)),
    );
  }

  SliverGridDelegate _gridDelegate(double width) {
    final cellWidth =
        (width -
            (padding?.horizontal ?? 0) -
            crossAxisSpacing * (crossAxisCount - 1)) /
        crossAxisCount;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: childAspectRatio,
      // Without a bounded width the ratio alone decides, as before.
      mainAxisExtent: width.isFinite
          ? math.max(cellWidth / childAspectRatio, minItemHeight)
          : null,
    );
  }

  Widget _buildGrid(SliverGridDelegate gridDelegate) {
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
        gridDelegate: gridDelegate,
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
        gridDelegate: gridDelegate,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return itemBuilder(context, item, index);
        },
      );
    }
  }
}

/// The height of one line of [style] at the context's text size, for working
/// out a [ReorderableGrid.minItemHeight].
double measureLineHeight(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'Hg', style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}
