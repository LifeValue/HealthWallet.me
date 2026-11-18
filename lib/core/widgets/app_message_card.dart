import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/gen/assets.gen.dart';

enum AppMessageType { error, warning, success, info }

/// A short message in the app's colours and font: the surface tinted with
/// the status colour, an icon for its [AppMessageType] and, with [onClose],
/// a close button. [AppSnackBar] floats it above the screen; inline, it sits
/// in the layout, such as an error at the top of a dialog.
class AppMessageCard extends StatelessWidget {
  const AppMessageCard({
    required this.message,
    required this.type,
    this.onClose,
    this.elevated = false,
    super.key,
  });

  static const Key cardKey = Key('app_message_card');
  static const Key closeKey = Key('app_message_card_close');

  final String message;
  final AppMessageType type;
  final VoidCallback? onClose;

  /// Adds a shadow, for a card floating above the screen.
  final bool elevated;

  Color get _accent => switch (type) {
    AppMessageType.error => AppColors.error,
    AppMessageType.warning => AppColors.warning,
    AppMessageType.success => AppColors.success,
    AppMessageType.info => AppColors.primary,
  };

  SvgGenImage get _icon => switch (type) {
    AppMessageType.error => Assets.icons.warning,
    AppMessageType.warning => Assets.icons.warningTriangle,
    AppMessageType.success => Assets.icons.checkmarkCircleOutline,
    AppMessageType.info => Assets.icons.information,
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
      key: cardKey,
      padding: EdgeInsets.fromLTRB(
        Insets.normal,
        Insets.smallNormal,
        onClose != null ? Insets.small : Insets.normal,
        Insets.smallNormal,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Insets.normal),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: context.colorScheme.shadow.withValues(alpha: 0.2),
                  blurRadius: Insets.normal,
                  offset: const Offset(0, Insets.extraSmall),
                ),
              ]
            : null,
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
          if (onClose != null) ...[
            const SizedBox(width: Insets.small),
            IconButton(
              key: closeKey,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
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
        ],
      ),
    );
  }
}
