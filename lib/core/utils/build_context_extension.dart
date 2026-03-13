import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:health_wallet/core/l10n/arb/app_localizations.dart';
import 'package:health_wallet/core/theme/app_color.dart';

extension BuildContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  DividerThemeData get dividerTheme => Theme.of(this).dividerTheme;

  StackRouter get appRouter => AutoRouter.of(this);

  Size get screenSize => MediaQuery.of(this).size;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  AppLocalizations get l10n => AppLocalizations.of(this)!;

  void closeKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Color get primaryTextColor =>
      isDarkMode ? AppColors.textPrimaryDark : AppColors.textPrimary;

  Color get secondaryTextColor =>
      isDarkMode ? AppColors.textSecondaryDark : AppColors.textSecondary;

  Color get borderColor =>
      isDarkMode ? AppColors.borderDark : AppColors.border;

  Color get surfaceColor =>
      isDarkMode ? AppColors.surfaceDark : AppColors.surface;

  void popDialog<T extends Object?>([T? result]) {
    Navigator.of(this).pop(result);
  }
}
