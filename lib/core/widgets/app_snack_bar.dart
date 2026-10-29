import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/gen/assets.gen.dart';

enum AppSnackBarType { error, warning, success, info }

/// The app's short messages: a card in the app's colours and font, with an
/// icon for its [AppSnackBarType] and a close button. On a phone it floats
/// just above the bottom navigation; on a wide desktop screen it is a centred
/// card of fixed width.
class AppSnackBar {
  AppSnackBar._();

  static const Key cardKey = Key('app_snack_bar_card');
  static const Key closeKey = Key('app_snack_bar_close');

  /// Clears the dashboard's bottom navigation: it floats [Insets.small]
  /// above the safe area and is 60 high, and the card keeps another
  /// [Insets.small] from it.
  static const double mobileBottomMargin = Insets.small + 60 + Insets.small;

  /// Width of the card on a wide desktop screen.
  static const double desktopWidth = 480;

  /// Shows [message] in the [ScaffoldMessenger] above [context]; null when
  /// there is none.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    BuildContext context, {
    required String message,
    required AppSnackBarType type,
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;
    return showOn(messenger, message: message, type: type, duration: duration);
  }

  /// Shows [message] in [messenger], for callers that kept the messenger
  /// because their own context may be gone by then (a closed dialog).
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showOn(
    ScaffoldMessengerState messenger, {
    required String message,
    required AppSnackBarType type,
    Duration? duration,
  }) {
    final wide = messenger.context.isDesktopWidth;
    return messenger.showSnackBar(
      SnackBar(
        content: _AppSnackBarCard(message: message, type: type),
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        behavior: SnackBarBehavior.floating,
        // SnackBar takes a width or a margin, not both.
        width: wide ? desktopWidth : null,
        margin: wide
            ? null
            : const EdgeInsets.fromLTRB(
                Insets.normal,
                0,
                Insets.normal,
                mobileBottomMargin,
              ),
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }
}

class _AppSnackBarCard extends StatelessWidget {
  const _AppSnackBarCard({required this.message, required this.type});

  final String message;
  final AppSnackBarType type;

  Color get _accent => switch (type) {
    AppSnackBarType.error => AppColors.error,
    AppSnackBarType.warning => AppColors.warning,
    AppSnackBarType.success => AppColors.success,
    AppSnackBarType.info => AppColors.primary,
  };

  SvgGenImage get _icon => switch (type) {
    AppSnackBarType.error => Assets.icons.warning,
    AppSnackBarType.warning => Assets.icons.warningTriangle,
    AppSnackBarType.success => Assets.icons.checkmarkCircleOutline,
    AppSnackBarType.info => Assets.icons.information,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    // The status colour tints the surface like the vitals cards, but stays
    // opaque so the screen behind does not show through.
    final background = Color.alphaBlend(
      accent.withValues(alpha: context.isDarkMode ? 0.16 : 0.08),
      context.surfaceColor,
    );

    return Container(
      key: AppSnackBar.cardKey,
      padding: const EdgeInsets.fromLTRB(
        Insets.normal,
        Insets.smallNormal,
        Insets.small,
        Insets.smallNormal,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Insets.normal),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: Insets.normal,
            offset: const Offset(0, Insets.extraSmall),
          ),
        ],
      ),
      child: Row(
        children: [
          _icon.svg(
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
          ),
          const SizedBox(width: Insets.smallNormal),
          Expanded(
            child: Text(
              message,
              style: AppTextStyle.bodyMedium.copyWith(
                color: context.primaryTextColor,
              ),
            ),
          ),
          const SizedBox(width: Insets.small),
          IconButton(
            key: AppSnackBar.closeKey,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            icon: Assets.icons.close.svg(
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(
                context.secondaryTextColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
