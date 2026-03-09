import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';

class TimelineEntry extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final bool isSelectionMode;

  const TimelineEntry({
    super.key,
    required this.isFirst,
    required this.isLast,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    required this.child,
    this.isSelectionMode = false,
  });

  static const double _dotSize = 16.0;
  static const double _lineWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.normal),
              child: GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                behavior: isSelectionMode
                    ? HitTestBehavior.opaque
                    : HitTestBehavior.deferToChild,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : context.theme.dividerColor,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.normal),
                    child: isSelectionMode
                        ? IgnorePointer(child: child)
                        : child,
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(-_dotSize / 2, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      width: _lineWidth,
                      color:
                          !isFirst ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : context.colorScheme.surface,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 1),
                          color: AppColors.primary.withValues(alpha: 0.6),
                          blurRadius: 3,
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: _lineWidth,
                      color:
                          !isLast ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
