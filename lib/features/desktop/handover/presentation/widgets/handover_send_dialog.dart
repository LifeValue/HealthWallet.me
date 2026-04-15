import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_sender_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';

class HandoverSendDialog extends StatefulWidget {
  final List<String> filePaths;

  const HandoverSendDialog({super.key, required this.filePaths});

  static void show(BuildContext context, List<String> filePaths) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: HandoverSendDialog(filePaths: filePaths),
        ),
      ),
    );
  }

  @override
  State<HandoverSendDialog> createState() => _HandoverSendDialogState();
}

class _HandoverSendDialogState extends State<HandoverSendDialog> {
  final HandoverSenderService _senderService = getIt<HandoverSenderService>();
  StreamSubscription<HandoverSession>? _subscription;
  HandoverSession? _session;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _subscription = _senderService.sessionUpdates.listen((session) {
      if (mounted) {
        setState(() => _session = session);
      }
    });
    _startSending();
  }

  Future<void> _startSending() async {
    if (_started) return;
    _started = true;
    await _senderService.sendHandover(widget.filePaths);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get _isTerminal =>
      _session?.status == HandoverStatus.complete ||
      _session?.status == HandoverStatus.error;

  String get _statusText {
    if (_session == null) return 'Preparing...';

    switch (_session!.status) {
      case HandoverStatus.sending:
        return 'Sending files...';
      case HandoverStatus.waitingForResults:
        return 'Processing on desktop...';
      case HandoverStatus.complete:
        return 'Complete!';
      case HandoverStatus.error:
        if (_session!.error != null) {
          return 'Error: ${_session!.error}';
        }
        return 'Error occurred';
      default:
        return 'Sending...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(Insets.medium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Sending to Desktop',
                  style: AppTextStyle.bodyMedium.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_isTerminal)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: context.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.normal),
            Text(
              '${widget.filePaths.length} ${widget.filePaths.length == 1 ? 'file' : 'files'}',
              style: AppTextStyle.labelLarge.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: Insets.normal),
            if (_session?.status == HandoverStatus.complete) ...[
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: AppColors.success,
              ),
              const SizedBox(height: Insets.small),
              Text(
                'Results received',
                style: AppTextStyle.bodySmall.copyWith(
                  color: AppColors.success,
                ),
              ),
            ] else ...[
              LinearProgressIndicator(
                value: _session?.progress,
                backgroundColor: context.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ],
            const SizedBox(height: Insets.small),
            if (_session?.status != HandoverStatus.complete)
              Text(
                _statusText,
                style: AppTextStyle.labelSmall.copyWith(
                  color: _session?.status == HandoverStatus.error
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: Insets.normal),
            if (!_isTerminal)
              SizedBox(
                width: 160,
                child: AppButton(
                  label: 'Cancel',
                  onPressed: () {
                    if (_session != null) {
                      _senderService.cancelHandover(_session!.sessionId);
                    }
                    Navigator.of(context).pop();
                  },
                  height: 36,
                ),
              ),
            if (_isTerminal)
              SizedBox(
                width: 160,
                child: AppButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  height: 36,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
