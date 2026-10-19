import 'package:flutter/widgets.dart';

abstract final class Breakpoints {
  static const double tablet = 600;
  static const double desktop = 1024;
  static const double smallPhone = 380;
}

extension ResponsiveExtension on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isDesktopWidth => screenWidth >= Breakpoints.desktop;
  bool get isTablet => screenWidth >= Breakpoints.tablet;
  bool get isSmallPhone => screenWidth < Breakpoints.smallPhone;
  double get screenHorizontalPadding =>
      isDesktopWidth ? 48.0 : isTablet ? 32.0 : 16.0;

  double get dialogWidth =>
      isDesktopWidth ? 480.0 : isTablet ? 450.0 : 350.0;

  double get wideDialogWidth =>
      isDesktopWidth ? 560.0 : isTablet ? 520.0 : 400.0;

  double get contentMaxWidth =>
      isDesktopWidth ? 700.0 : 600.0;
}

class ConstrainedContent extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ConstrainedContent({
    super.key,
    this.maxWidth = 700,
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
