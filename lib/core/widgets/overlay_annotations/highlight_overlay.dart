import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/widgets/overlay_annotations/tooltip_position.dart';

/// A custom overlay widget that highlights multiple widgets simultaneously
/// with a dark semi-transparent background and cut-outs around the target widgets.
class MultiHighlightOverlay extends StatefulWidget {
  /// GlobalKeys of the widgets to highlight.
  final List<GlobalKey> targetKeys;

  /// Message to display in the tooltip.
  final String message;

  /// Subtitle to display below the message.
  final String? subtitle;

  /// Callback when the overlay is dismissed.
  final VoidCallback onDismiss;

  /// Padding around highlighted areas.
  final double highlightPadding;

  /// Border radius for the highlight cut-outs.
  final double highlightBorderRadius;

  /// Position of the tooltip (auto, top, or bottom).
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

    // Try to calculate rects after frame is built
    _scheduleRectCalculation();
  }

  void _scheduleRectCalculation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calculateHighlightRects();

      // If no rects found and we haven't retried too many times, try again
      if (_highlightRects.isEmpty && _retryCount < _maxRetries) {
        _retryCount++;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _scheduleRectCalculation();
          }
        });
      } else {
        // Start animation once we have rects or exhausted retries
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

        // Validate the rect is reasonable
        if (size.width > 0 && size.height > 0 && position.dy >= 0) {
          rects.add(Rect.fromLTWH(
            position.dx - widget.highlightPadding,
            position.dy - widget.highlightPadding,
            size.width + widget.highlightPadding * 2,
            size.height + widget.highlightPadding * 2,
          ));
        }
      } catch (e) {
        // Silently continue if we can't get rect for this key
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
            // Dark overlay with cut-outs
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismiss,
                child: CustomPaint(
                  size: screenSize,
                  painter: _HighlightPainter(
                    rects: _highlightRects,
                    borderRadius: widget.highlightBorderRadius,
                    overlayColor: Colors.black.withOpacity(0.9),
                  ),
                ),
              ),
            ),

            // Always show tooltip - position it based on available rects
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
    // Handle fixed positions first
    switch (widget.tooltipPosition) {
      case TooltipPosition.top:
        // Position at the top with safe area margin
        final topPadding = MediaQuery.of(context).padding.top;
        return topPadding + Insets.large;
      case TooltipPosition.bottom:
        // Position at the bottom with safe area margin
        return screenSize.height - 200;
      case TooltipPosition.auto:
        // Fall through to auto-calculation
        break;
    }

    // Auto-calculation logic
    // If no rects, position in upper-middle area
    if (_highlightRects.isEmpty) {
      return screenSize.height * 0.1;
    }

    // Position tooltip between the two highlighted areas if possible
    if (_highlightRects.length >= 2) {
      final firstRect = _highlightRects[0];
      final secondRect = _highlightRects[1];

      // Calculate space between the two rects
      final firstBottom = firstRect.bottom;
      final secondTop = secondRect.top;

      if (secondTop > firstBottom + 100) {
        // There's enough space between them, center the tooltip there
        return firstBottom + (secondTop - firstBottom) / 2 - 60;
      }
    }

    // Default: position below the first rect with some margin
    if (_highlightRects.isNotEmpty) {
      final bottomOfFirst = _highlightRects[0].bottom;
      // Make sure tooltip doesn't go off screen
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
              color: Colors.black.withOpacity(0.3),
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
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
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

/// Custom painter that draws a dark overlay with rounded rectangle cut-outs.
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

    // Create full screen path
    final fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // If no rects, just draw the full overlay
    if (rects.isEmpty) {
      canvas.drawPath(fullScreenPath, paint);
      return;
    }

    // Combine with holes for each highlighted rect
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

    // Draw highlight borders around the cut-outs
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
