import 'package:flutter/material.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class AnimatedStickyHeader extends StatefulWidget {
  final List<Widget> children;
  final Widget body;
  final Duration duration;
  final Curve curve;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const AnimatedStickyHeader({
    required this.children,
    required this.body,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOut,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.backgroundColor,
    super.key,
  });

  @override
  State<AnimatedStickyHeader> createState() => _AnimatedStickyHeaderState();
}

class _AnimatedStickyHeaderState extends State<AnimatedStickyHeader> {
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 0;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());
  }

  @override
  void didUpdateWidget(AnimatedStickyHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());
  }

  void _measureHeader() {
    final RenderBox? renderBox =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && mounted) {
      final height = renderBox.size.height;
      if (height != _headerHeight && height > 0) {
        setState(() {
          _headerHeight = height;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: widget.duration,
              curve: widget.curve,
              height: _headerHeight,
              color: Colors.transparent,
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  final scrolled = notification.metrics.pixels > 0;
                  if (scrolled != _isScrolled) {
                    setState(() => _isScrolled = scrolled);
                  }
                  return false;
                },
                child: widget.body,
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            key: _headerKey,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? context.colorScheme.surface,
              borderRadius: _isScrolled
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    )
                  : BorderRadius.zero,
              boxShadow: _isScrolled
                  ? [
                      BoxShadow(
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                    ]
                  : [],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: widget.padding!.left,
                top: widget.padding!.top,
                right: widget.padding!.right,
                bottom: _isScrolled ? widget.padding!.bottom : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
