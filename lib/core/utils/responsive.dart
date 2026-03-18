import 'package:flutter/widgets.dart';

abstract final class Breakpoints {
  static const double tablet = 600;
  static const double smallPhone = 380;
}

extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isTablet => screenWidth >= Breakpoints.tablet;
  bool get isSmallPhone => screenWidth < Breakpoints.smallPhone;
  double get screenHorizontalPadding => isTablet ? 32.0 : 16.0;
  double get dialogWidth => isTablet ? 450.0 : 350.0;
  double get wideDialogWidth => isTablet ? 520.0 : 400.0;
  double get contentMaxWidth => 500.0;
}

class ConstrainedContent extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ConstrainedContent({
    super.key,
    this.maxWidth = 500,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
