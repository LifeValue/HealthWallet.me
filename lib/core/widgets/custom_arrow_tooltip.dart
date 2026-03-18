import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';

enum TooltipAlignment {
  auto,
  center,
  alignRight,
}

class CustomArrowTooltip {
  static OverlayEntry? _currentOverlay;

  static void show({
    required BuildContext context,
    required GlobalKey buttonKey,
    required String message,
    Color backgroundColor = const Color(0xFF1C1C1E),
    TooltipAlignment alignment = TooltipAlignment.auto,
    double width = 180.0,
  }) {
    dismiss();

    final RenderBox button =
        buttonKey.currentContext!.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero);
    final buttonSize = button.size;

    _currentOverlay = OverlayEntry(
      builder: (context) => _TooltipOverlay(
        buttonPosition: buttonPosition,
        buttonSize: buttonSize,
        message: message,
        backgroundColor: backgroundColor,
        alignment: alignment,
        width: width,
        onDismiss: dismiss,
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  static void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _TooltipOverlay extends StatelessWidget {
  final Offset buttonPosition;
  final Size buttonSize;
  final String message;
  final Color backgroundColor;
  final TooltipAlignment alignment;
  final double width;
  final VoidCallback onDismiss;

  const _TooltipOverlay({
    required this.buttonPosition,
    required this.buttonSize,
    required this.message,
    required this.backgroundColor,
    required this.alignment,
    required this.width,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final position = _calculatePosition(context);

    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Positioned(
            left: position.tooltipLeft,
            top: buttonPosition.dy + buttonSize.height + 4,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: position.arrowLeft),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CustomPaint(
                          size: const Size(16, 8),
                          painter: _ArrowPainter(color: backgroundColor),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        message,
                        style: AppTextStyle.labelSmall.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TooltipPosition _calculatePosition(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonCenterX = buttonPosition.dx + buttonSize.width / 2;
    const screenMargin = 16.0;
    const arrowWidth = 16.0;

    double tooltipLeft;
    double arrowLeft;

    switch (alignment) {
      case TooltipAlignment.center:
        tooltipLeft = buttonCenterX - width / 2;
        tooltipLeft = tooltipLeft.clamp(
          screenMargin,
          screenWidth - width - screenMargin,
        );
        arrowLeft = (width - arrowWidth) / 2;
        break;

      case TooltipAlignment.alignRight:
        tooltipLeft = screenWidth - width - screenMargin;
        arrowLeft = buttonCenterX - tooltipLeft - (arrowWidth / 2);
        break;

      case TooltipAlignment.auto:
        final isOnRightSide = buttonCenterX > screenWidth * 0.65;
        if (isOnRightSide) {
          tooltipLeft = screenWidth - width + 4;
          arrowLeft = buttonCenterX - tooltipLeft - (arrowWidth / 2);
        } else {
          tooltipLeft = buttonCenterX - width / 2;
          tooltipLeft = tooltipLeft.clamp(
            screenMargin,
            screenWidth - width - screenMargin,
          );
          arrowLeft = buttonCenterX - tooltipLeft - (arrowWidth / 2);
        }
        break;
    }

    arrowLeft = arrowLeft.clamp(0, width - arrowWidth);

    return _TooltipPosition(
      tooltipLeft: tooltipLeft,
      arrowLeft: arrowLeft,
    );
  }
}

class _TooltipPosition {
  final double tooltipLeft;
  final double arrowLeft;

  const _TooltipPosition({
    required this.tooltipLeft,
    required this.arrowLeft,
  });
}

class _ArrowPainter extends CustomPainter {
  final Color color;

  const _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2 - 8, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width / 2 + 8, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
