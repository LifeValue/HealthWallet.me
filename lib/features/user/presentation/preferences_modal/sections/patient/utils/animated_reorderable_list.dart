import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';

class AnimatedReorderableList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(
    BuildContext context,
    T item,
    int index,
    bool isBeingMoved,
  )
  itemBuilder;
  final String Function(T item) itemIdExtractor;
  final double itemHeight;
  final double itemSpacing;
  final Duration animationDuration;
  final Duration slideDelay;
  final Duration fadeDelay;
  final Function(String itemId, int oldIndex, int newIndex)? onReorder;

  const AnimatedReorderableList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemIdExtractor,
    this.itemHeight = 120.0,
    this.itemSpacing = Insets.small,
    this.animationDuration = const Duration(milliseconds: 900),
    this.slideDelay = const Duration(milliseconds: 720),
    this.fadeDelay = const Duration(milliseconds: 360),
    this.onReorder,
  });

  @override
  State<AnimatedReorderableList<T>> createState() =>
      _AnimatedReorderableListState<T>();
}

class _AnimatedReorderableListState<T> extends State<AnimatedReorderableList<T>>
    with TickerProviderStateMixin {
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _slideAnimations = {};
  final Map<String, Animation<double>> _fadeAnimations = {};

  @override
  void dispose() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeAnimations(List<T> items) {
    final currentItemIds = items
        .map((item) => widget.itemIdExtractor(item))
        .toSet();
    final existingItemIds = _animationControllers.keys.toSet();

    for (final itemId in existingItemIds) {
      if (!currentItemIds.contains(itemId)) {
        _animationControllers[itemId]?.dispose();
        _animationControllers.remove(itemId);
        _slideAnimations.remove(itemId);
        _fadeAnimations.remove(itemId);
      }
    }

    for (final item in items) {
      final itemId = widget.itemIdExtractor(item);
      if (!_animationControllers.containsKey(itemId)) {
        final controller = AnimationController(
          duration: widget.animationDuration,
          vsync: this,
        );

        final slideAnimation =
            Tween<double>(
              begin: 0.0,
              end: 0.0,
            ).animate(
              CurvedAnimation(
                parent: controller,
                curve: Curves.easeInOutCubic,
              ),
            );

        final fadeAnimation =
            Tween<double>(
              begin: 1.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: controller,
                curve: Curves.easeInOutCubic,
              ),
            );

        _animationControllers[itemId] = controller;
        _slideAnimations[itemId] = slideAnimation;
        _fadeAnimations[itemId] = fadeAnimation;
      }
    }
  }

  Future<void> _animateReorder(
    String itemId,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex || !_animationControllers.containsKey(itemId)) {
      return;
    }

    final controller = _animationControllers[itemId]!;

    await Future.delayed(widget.slideDelay);

    final slideDistance =
        (newIndex - oldIndex) * (widget.itemHeight + widget.itemSpacing);

    final fadeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 0.3),
            weight: 20.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.3, end: 0.3),
            weight: 60.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.3, end: 1.0),
            weight: 20.0,
          ),
        ]).animate(
          CurvedAnimation(
            parent: controller,
            curve: Curves.easeInOutCubic,
          ),
        );

    final slideAnimation =
        Tween<double>(
          begin: 0.0,
          end: slideDistance,
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: const Interval(0.2, 0.8, curve: Curves.easeInOutCubic),
          ),
        );

    _slideAnimations[itemId] = slideAnimation;
    _fadeAnimations[itemId] = fadeAnimation;

    await controller.forward();

    await Future.delayed(widget.fadeDelay);

    controller.reset();
    _slideAnimations[itemId] =
        Tween<double>(
          begin: 0.0,
          end: 0.0,
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: Curves.easeInOutCubic,
          ),
        );

    _fadeAnimations[itemId] =
        Tween<double>(
          begin: 1.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: controller,
            curve: Curves.easeInOutCubic,
          ),
        );
  }

  void handleReorder(String fromItemId, String toItemId) {
    final oldIndex = widget.items.indexWhere(
      (item) => widget.itemIdExtractor(item) == fromItemId,
    );
    final newIndex = widget.items.indexWhere(
      (item) => widget.itemIdExtractor(item) == toItemId,
    );

    if (oldIndex != -1 && newIndex != -1 && oldIndex != newIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateReorder(fromItemId, oldIndex, newIndex);
      });

      widget.onReorder?.call(fromItemId, oldIndex, newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    _initializeAnimations(widget.items);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final itemId = widget.itemIdExtractor(item);
        final isBeingMoved =
            _animationControllers.containsKey(itemId) &&
            _animationControllers[itemId]!.isAnimating;

        if (isBeingMoved) {
          return AnimatedBuilder(
            animation: _animationControllers[itemId]!,
            builder: (context, child) {
              final slideOffset = _slideAnimations[itemId]?.value ?? 0.0;
              final fadeOpacity = _fadeAnimations[itemId]?.value ?? 1.0;

              return Transform.translate(
                offset: Offset(0, slideOffset),
                child: Opacity(
                  opacity: fadeOpacity,
                  child: widget.itemBuilder(context, item, index, true),
                ),
              );
            },
          );
        } else {
          return widget.itemBuilder(context, item, index, false);
        }
      },
    );
  }
}

class AnimatedReorderableListController<T> {
  final GlobalKey<_AnimatedReorderableListState<T>> _key =
      GlobalKey<_AnimatedReorderableListState<T>>();

  AnimatedReorderableList<T> get widget =>
      _key.currentWidget as AnimatedReorderableList<T>;

  void reorderItem(String fromItemId, String toItemId) {
    final state = _key.currentState;
    state?.handleReorder(fromItemId, toItemId);
  }

  GlobalKey<State<AnimatedReorderableList<T>>> get key => _key;
}
