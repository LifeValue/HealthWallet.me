import 'package:flutter/material.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/responsive.dart';
import 'package:health_wallet/core/widgets/app_message_card.dart';

export 'package:health_wallet/core/widgets/app_message_card.dart'
    show AppMessageType;

typedef AppSnackBarType = AppMessageType;

/// The app's short messages: an [AppMessageCard] with a close button. On a
/// phone it floats just above the bottom navigation; on a wide desktop screen
/// it is a centred card of fixed width.
class AppSnackBar {
  AppSnackBar._();

  static const Key cardKey = AppMessageCard.cardKey;
  static const Key closeKey = AppMessageCard.closeKey;

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
        content: AppMessageCard(
          message: message,
          type: type,
          elevated: true,
          onClose: messenger.hideCurrentSnackBar,
        ),
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
