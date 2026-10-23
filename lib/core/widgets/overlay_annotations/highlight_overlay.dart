import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/tooltip_position.dart';

class MultiHighlightOverlay extends StatefulWidget {
  final List<GlobalKey> targetKeys;

  final String message;

  final String? subtitle;

  final VoidCallback onDismiss;

  final double highlightPadding;

  final double highlightBorderRadius;

  final TooltipPosition tooltipPosition;

  const MultiHighlightOverlay({
    super.key,
    required this.targetKeys,
    required this.message,
    this.subtitle,
    required this.onDismiss,
    this.highlightPadding = 8.0,
    this.highlightBorderRadius = 12.0,
    this.tooltipPosition = TooltipPosition.auto,
  });

  @override
  State<MultiHighlightOverlay> createState() => _MultiHighlightOverlayState();
}

class _MultiHighlightOverlayState extends State<MultiHighlightOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Rect> _highlightRects = [];
  int _retryCount = 0;
  static const int _maxRetries = 5;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scheduleRectCalculation();
  }

  void _scheduleRectCalculation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calculateHighlightRects();

      if (_highlightRects.isEmpty && _retryCount < _maxRetries) {
        _retryCount++;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _scheduleRectCalculation();
          }
        });
      } else {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateHighlightRects() {
    final rects = <Rect>[];

    for (final key in widget.targetKeys) {
      try {
        final currentContext = key.currentContext;
        if (currentContext == null) continue;

        final renderObject = currentContext.findRenderObject();
        if (renderObject == null || renderObject is! RenderBox) continue;

        final renderBox = renderObject;
        if (!renderBox.hasSize) continue;

        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        if (size.width > 0 && size.height > 0 && position.dy >= 0) {
          rects.add(Rect.fromLTWH(
            position.dx - widget.highlightPadding,
            position.dy - widget.highlightPadding,
            size.width + widget.highlightPadding * 2,
            size.height + widget.highlightPadding * 2,
          ));
        }
      } catch (e) {
        continue;
      }
    }

    if (mounted) {
      setState(() {
        _highlightRects = rects;
      });
    }
  }

  Future<void> _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismiss,
                child: CustomPaint(
                  size: screenSize,
                  painter: _HighlightPainter(
                    rects: _highlightRects,
                    borderRadius: widget.highlightBorderRadius,
                    overlayColor: Colors.black.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            Positioned(
              left: Insets.small,
              right: Insets.small,
              top: _calculateTooltipPosition(screenSize),
              child: _buildTooltip(context),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTooltipPosition(Size screenSize) {
    switch (widget.tooltipPosition) {
      case TooltipPosition.top:
        final topPadding = MediaQuery.of(context).padding.top;
        return topPadding + Insets.large;
      case TooltipPosition.bottom:
        return screenSize.height - 200;
      case TooltipPosition.auto:
        break;
    }

    if (_highlightRects.isEmpty) {
      return screenSize.height * 0.1;
    }

    if (_highlightRects.length >= 2) {
      final firstRect = _highlightRects[0];
      final secondRect = _highlightRects[1];

      final firstBottom = firstRect.bottom;
      final secondTop = secondRect.top;

      if (secondTop > firstBottom + 100) {
        return firstBottom + (secondTop - firstBottom) / 2 - 60;
      }
    }

    if (_highlightRects.isNotEmpty) {
      final bottomOfFirst = _highlightRects[0].bottom;
      final maxTop = screenSize.height - 200;
      return (bottomOfFirst + 20).clamp(100.0, maxTop);
    }

    return screenSize.height * 0.3;
  }

  Widget _buildTooltip(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(Insets.small),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: AppTextStyle.bodyLarge.copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
              const SizedBox(height: Insets.smallNormal),
              Center(
                child: Text(
                  widget.subtitle!,
                  style: AppTextStyle.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final List<Rect> rects;
  final double borderRadius;
  final Color overlayColor;

  _HighlightPainter({
    required this.rects,
    required this.borderRadius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    final fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (rects.isEmpty) {
      canvas.drawPath(fullScreenPath, paint);
      return;
    }

    Path finalPath = fullScreenPath;

    for (final rect in rects) {
      final holePath = Path()
        ..addRRect(RRect.fromRectAndRadius(
          rect,
          Radius.circular(borderRadius),
        ));

      finalPath = Path.combine(
        PathOperation.difference,
        finalPath,
        holePath,
      );
    }

    canvas.drawPath(finalPath, paint);

    final borderPaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final rect in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.rects != rects ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}
