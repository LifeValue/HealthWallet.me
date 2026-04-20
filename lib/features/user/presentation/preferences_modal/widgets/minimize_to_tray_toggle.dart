import 'package:flutter/material.dart';
import 'package:health_wallet/core/config/constants/shared_prefs_constants.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MinimizeToTrayToggle extends StatefulWidget {
  const MinimizeToTrayToggle({super.key});

  @override
  State<MinimizeToTrayToggle> createState() => _MinimizeToTrayToggleState();
}

class _MinimizeToTrayToggleState extends State<MinimizeToTrayToggle> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final prefs = getIt<SharedPreferences>();
    _enabled = prefs.getBool(SharedPrefsConstants.minimizeToTray) ?? false;
  }

  void _toggle() {
    final prefs = getIt<SharedPreferences>();
    setState(() {
      _enabled = !_enabled;
      prefs.setBool(SharedPrefsConstants.minimizeToTray, _enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = context.colorScheme;
    final borderColor = context.theme.dividerColor;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 76,
        height: 40,
        padding: const EdgeInsets.all(Insets.extraSmall),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: !_enabled ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'OFF',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: !_enabled
                          ? (context.isDarkMode
                              ? Colors.white
                              : colorScheme.onPrimary)
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: _enabled ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'ON',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: _enabled
                          ? (context.isDarkMode
                              ? Colors.white
                              : colorScheme.onPrimary)
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
