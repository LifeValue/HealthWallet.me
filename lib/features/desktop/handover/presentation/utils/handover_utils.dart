import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/core/utils/build_context_extension.dart';
import 'package:health_wallet/core/widgets/dialogs/app_simple_dialog.dart';
import 'package:health_wallet/features/desktop/communication/presentation/bloc/communication_bloc.dart';
import 'package:health_wallet/features/desktop/handover/presentation/widgets/handover_reconnect_dialog.dart';
import 'package:health_wallet/features/desktop/handover/presentation/widgets/handover_send_dialog.dart';
import 'package:health_wallet/features/desktop/presentation/widgets/connection_dialog.dart';
import 'package:health_wallet/features/processing/domain/entity/processing_session.dart';
import 'package:health_wallet/features/processing/domain/entity/staged_resource.dart';

class HandoverUtils {
  static Future<void> initiateHandover(
    BuildContext context, {
    required ProcessingSession session,
  }) async {
    if (session.filePaths.isEmpty) return;

    if (session.isProcessing) {
      final confirmed = await AppSimpleDialog.showDestructiveConfirmation(
        context: context,
        title: 'Handover to Desktop',
        message: 'Processing is in progress. Handover will cancel the current processing and send files to desktop.',
        confirmText: 'Handover',
        cancelText: context.l10n.cancel,
        confirmButtonColor: context.colorScheme.primary,
        onConfirm: () {},
      );
      if (confirmed != true || !context.mounted) return;
    }

    if (!_isDesktopConnected()) {
      final connected = await _ensureConnection(context, session);
      if (!connected || !context.mounted) return;
    }

    _showSendDialog(context, session);
  }

  static bool _isDesktopConnected() {
    try {
      return getIt<CommunicationBloc>().state.connectionStatus ==
          ConnectionStatus.connected;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _ensureConnection(
    BuildContext context,
    ProcessingSession session,
  ) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: HandoverReconnectDialog(session: session),
        ),
      ),
    );

    if (result == true) return true;

    if (result == 'pair' && context.mounted) {
      ConnectionDialog.show(context);
      return await _waitForConnection();
    }

    return false;
  }

  static Future<bool> _waitForConnection() async {
    final completer = Completer<bool>();
    Timer? timeout;

    final sub = getIt<CommunicationBloc>().stream.listen((state) {
      if (state.connectionStatus == ConnectionStatus.connected &&
          !completer.isCompleted) {
        completer.complete(true);
      }
    });

    timeout = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    final result = await completer.future;
    sub.cancel();
    timeout.cancel();
    return result;
  }

  static void _showSendDialog(
    BuildContext context,
    ProcessingSession session,
  ) {
    Map<String, dynamic>? phase1Data;
    if (session.patient.hasSelection) {
      phase1Data = {
        'patient': stagedPatientToJson(session.patient),
        if (session.encounter.draft != null)
          'encounter': stagedEncounterToJson(session.encounter),
        if (session.diagnosticReport != null)
          'diagnosticReport':
              stagedDiagnosticReportToJson(session.diagnosticReport!),
      };
    }

    HandoverSendDialog.show(
      context,
      session.filePaths,
      sourceSessionId: session.id,
      phase1Data: phase1Data,
      continueLabel: session.origin == ProcessingOrigin.import ||
              session.origin == ProcessingOrigin.handover
          ? 'Continue Importing'
          : null,
    );
  }
}
