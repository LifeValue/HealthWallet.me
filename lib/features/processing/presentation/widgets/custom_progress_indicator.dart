import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class CustomProgressIndicator extends StatefulWidget {
  const CustomProgressIndicator({
    required this.progress,
    this.text,
    this.secondaryText,
    this.showProgressBar = true,
    super.key,
  });

  final double progress;
  final String? text;
  final String? secondaryText;
  final bool showProgressBar;

  @override
  State<CustomProgressIndicator> createState() =>
      _CustomProgressIndicatorState();
}

class _CustomProgressIndicatorState extends State<CustomProgressIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = context.colorScheme.onSurface.withValues(alpha: 0.7);
    final highlightColor = context.colorScheme.onSurface.withValues(alpha: 0.3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.text != null)
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, _) {
              final slidePercent = _shimmerController.value;
              const slideDistance = 1.5;
              final gradientStart =
                  -slideDistance + (slidePercent * 2 * slideDistance);
              final gradientEnd = gradientStart + slideDistance;

              return ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [baseColor, highlightColor, baseColor],
                  stops: const [0.3, 0.5, 0.7],
                  begin: Alignment(gradientStart, 0.0),
                  end: Alignment(gradientEnd, 0.0),
                ).createShader(bounds),
                child: Text(
                  widget.text!,
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        if (widget.secondaryText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.secondaryText!,
            style: AppTextStyle.bodySmall.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 14),
        if (widget.showProgressBar)
          LinearProgressIndicator(
            value: widget.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: context.colorScheme.primary.withValues(alpha: 0.1),
            color: context.colorScheme.primary,
          ),
      ],
    );
  }
}
