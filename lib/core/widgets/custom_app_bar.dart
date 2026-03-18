import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;
  final double extraTopPadding;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.backgroundColor,
    this.bottom,
    this.extraTopPadding = 0,
  }) : assert(
          title != null || titleWidget != null,
          'Either title or titleWidget must be provided',
        );

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return AppBar(
      toolbarHeight: extraTopPadding > 0
          ? kToolbarHeight + extraTopPadding
          : kToolbarHeight,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      centerTitle: false,
      titleSpacing: leading != null
          ? 0
          : context.isTablet
              ? context.screenHorizontalPadding
              : NavigationToolbar.kMiddleSpacing,
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: AppTextStyle.titleMedium,
                )
              : null),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight +
            extraTopPadding +
            (bottom != null ? bottom!.preferredSize.height : 0),
      );
}

