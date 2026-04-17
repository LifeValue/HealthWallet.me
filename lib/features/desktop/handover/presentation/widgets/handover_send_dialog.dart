import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/theme/app_color.dart';
import 'package:health_wallet/core/theme/app_text_style.dart';
import 'package:health_wallet/core/theme/app_insets.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/app_button.dart';
import 'package:collection/collection.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/dashboard/presentation/helpers/page_view_navigation_controller.dart';
import 'package:health_wallet/features/processing/domain/repository/processing_repository.dart';
import 'package:health_wallet/features/processing/presentation/bloc/processing_bloc.dart';
import 'package:health_wallet/features/desktop/handover/data/services/handover_sender_service.dart';
import 'package:health_wallet/features/desktop/handover/domain/entity/handover_session.dart';

class HandoverSendDialog extends StatefulWidget {
  final List<String> filePaths;
  final String? continueLabel;
  final String? sourceSessionId;
  final Map<String, dynamic>? phase1Data;

  const HandoverSendDialog({
    super.key,
    required this.filePaths,
    this.continueLabel,
    this.sourceSessionId,
    this.phase1Data,
  });

  static void show(
    BuildContext context,
    List<String> filePaths, {
    String? continueLabel,
    String? sourceSessionId,
    Map<String, dynamic>? phase1Data,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: HandoverSendDialog(
            filePaths: filePaths,
            continueLabel: continueLabel,
            sourceSessionId: sourceSessionId,
            phase1Data: phase1Data,
          ),
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
  bool _processingCancelled = false;

  @override
  void initState() {
    super.initState();
    _subscription = _senderService.sessionUpdates.listen((session) {
      if (mounted) {
        debugPrint('[Handover] session update: ${session.status}, isSent=$_isSent');
        setState(() => _session = session);
        if (_isSent && !_processingCancelled) {
          _processingCancelled = true;
          _cancelMobileProcessing();
        }
      }
    });
    _startSending();
  }

  void _cancelMobileProcessing() {
    debugPrint('[Handover] _cancelMobileProcessing called, sourceId=${widget.sourceSessionId}');
    if (widget.sourceSessionId == null) return;
    try {
      final processingBloc = getIt<ProcessingBloc>();
      final session = processingBloc.state.sessions
          .firstWhereOrNull((s) => s.id == widget.sourceSessionId);
      debugPrint('[Handover] found session: ${session?.id}, status=${session?.status}, isProcessing=${session?.isProcessing}');
      if (session != null && session.isProcessing) {
        debugPrint('[Handover] calling cancelGeneration + disposeModel + MappingCancelled');
        getIt<ProcessingRepository>().cancelGeneration();
        getIt<ProcessingRepository>().disposeModel();
        processingBloc.add(MappingCancelled(sessionId: session.id));
      }
    } catch (e) {
      debugPrint('[Handover] cancel error: $e');
    }
  }

  void _clearSourceSession() {
    if (widget.sourceSessionId == null) return;
    try {
      final processingBloc = getIt<ProcessingBloc>();
      final session = processingBloc.state.sessions
          .firstWhereOrNull((s) => s.id == widget.sourceSessionId);
      if (session != null) {
        processingBloc.add(SessionCleared(session: session));
      }
    } catch (_) {}
  }

  Future<void> _startSending() async {
    if (_started) return;
    _started = true;
    await _senderService.sendHandover(widget.filePaths, phase1Data: widget.phase1Data);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get _isTerminal =>
      _session?.status == HandoverStatus.complete ||
      _session?.status == HandoverStatus.waitingForResults ||
      _session?.status == HandoverStatus.error;

  bool get _isSent =>
      _session?.status == HandoverStatus.complete ||
      _session?.status == HandoverStatus.waitingForResults;

  String _statusText(BuildContext context) {
    if (_session == null) return 'Preparing...';

    switch (_session!.status) {
      case HandoverStatus.sending:
        return 'Sending files...';
      case HandoverStatus.waitingForResults:
        return 'Processing on desktop...';
      case HandoverStatus.complete:
        return 'Complete!';
      case HandoverStatus.error:
        final error = _session!.error ?? '';
        if (error.contains('Model file not found') ||
            (error.contains('model') && error.contains('not found'))) {
          return context.l10n.noAiModelOnDesktop;
        }
        return error.isNotEmpty ? error : 'Error occurred';
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
            if (_session?.status != HandoverStatus.error)
              Text(
                '${widget.filePaths.length} ${widget.filePaths.length == 1 ? 'file' : 'files'}',
                style: AppTextStyle.labelLarge.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(height: Insets.normal),
            if (_isSent) ...[
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: AppColors.success,
              ),
              const SizedBox(height: Insets.small),
              Text(
                'Handed over to Desktop',
                style: AppTextStyle.bodySmall.copyWith(
                  color: AppColors.success,
                ),
              ),
            ] else if (_session?.status != HandoverStatus.error) ...[
              LinearProgressIndicator(
                value: _session?.progress,
                backgroundColor: context.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ],
            const SizedBox(height: Insets.small),
            if (_session?.status != HandoverStatus.complete)
              Text(
                _statusText(context),
                style: AppTextStyle.labelSmall.copyWith(
                  color: _session?.status == HandoverStatus.error
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
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
            if (_isTerminal && _isSent) ...[
              if (!getIt<AppPlatform>().isDesktop) ...[
                AppButton(
                  label: widget.continueLabel ?? context.l10n.continueScanning,
                  variant: AppButtonVariant.outlined,
                  height: 36,
                  onPressed: () {
                    _clearSourceSession();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                const SizedBox(height: Insets.small),
              ],
              AppButton(
                label: context.l10n.goToRecords,
                variant: AppButtonVariant.primary,
                height: 36,
                onPressed: () {
                  _clearSourceSession();
                  final navController = getIt<PageViewNavigationController>();
                  navController.jumpToPage(1);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ] else if (_isTerminal) ...[
              SizedBox(
                width: 160,
                child: AppButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  height: 36,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
