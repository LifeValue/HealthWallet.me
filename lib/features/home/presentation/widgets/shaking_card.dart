import 'package:flutter/material.dart';

class ShakingCard extends StatefulWidget {
  final Widget child;
  final bool isShaking;

  const ShakingCard({super.key, required this.child, required this.isShaking});

  @override
  State<ShakingCard> createState() => _ShakingCardState();
}

class _ShakingCardState extends State<ShakingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    if (widget.isShaking) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ShakingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShaking != oldWidget.isShaking) {
      if (widget.isShaking) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = widget.isShaking ? (_controller.value - 0.5) * 0.05 : 0.0;
        return Transform.rotate(
          angle: angle,
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}
