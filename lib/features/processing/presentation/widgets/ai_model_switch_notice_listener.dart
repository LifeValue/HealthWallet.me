import 'package:flutter/widgets.dart' hide Notification;
import 'package:health_wallet/core/config/constants/ai_model_config.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/l10n/l10n.dart';
import 'package:health_wallet/features/notifications/bloc/notification_bloc.dart';
import 'package:health_wallet/features/notifications/domain/entities/notification.dart';
import 'package:health_wallet/features/processing/domain/services/ai_model_selection_guard.dart';

const String kAiModelSwitchedNotificationId = 'ai_model_switched_to_lite';

/// Tells the user, once and in their language, that the Lite model replaced a
/// selected model this device can't run ([AiModelSelectionGuard]).
class AiModelSwitchNoticeListener extends StatefulWidget {
  const AiModelSwitchNoticeListener({
    required this.child,
    this.guard,
    this.notificationBloc,
    super.key,
  });

  final Widget child;

  /// From `getIt` unless given; for tests.
  final AiModelSelectionGuard? guard;
  final NotificationBloc? notificationBloc;

  @override
  State<AiModelSwitchNoticeListener> createState() =>
      _AiModelSwitchNoticeListenerState();
}

class _AiModelSwitchNoticeListenerState
    extends State<AiModelSwitchNoticeListener> {
  @override
  void initState() {
    super.initState();
    // After the first frame, so the notice is in the app's language.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNotice());
  }

  void _showNotice() {
    if (!mounted) return;
    final replaced = (widget.guard ?? getIt<AiModelSelectionGuard>())
        .takeSwitchNotice();
    if (replaced == null) return;

    final l10n = context.l10n;
    final modelName = AiModelConfig.fromVariant(replaced).localizedName(l10n);
    (widget.notificationBloc ?? getIt<NotificationBloc>()).add(
      NotificationAdded(
        notification: Notification(
          id: kAiModelSwitchedNotificationId,
          text: l10n.aiModelSwitchedToLiteTitle,
          description: l10n.aiModelSwitchedToLiteMessage(modelName),
          time: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
