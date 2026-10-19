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
import 'package:health_wallet/core/l10n/l10n.dart';

class HandoverUtils {
  static Future<void> initiateHandover(
    BuildContext context, {
    required ProcessingSession session,
  }) async {
    if (session.filePaths.isEmpty) return;

    if (session.isProcessing) {
      final confirmed = await AppSimpleDialog.showDestructiveConfirmation(
        context: context,
        title: context.l10n.desktopHandoverToDesktop,
        message: context.l10n.desktopHandoverProcessingMessage,
        confirmText: context.l10n.desktopHandover,
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
    final commBloc = getIt<CommunicationBloc>();
    final hasPairing = commBloc.state.pairedDevice != null;

    if (hasPairing) {
      commBloc.add(const CommunicationConnectionRequested());
      final connected = await _waitForConnection(timeout: 5);
      if (connected) return true;
    }

    if (!context.mounted) return false;
    ConnectionDialog.show(context);
    return await _waitForConnection(timeout: 60);
  }

  static Future<bool> _waitForConnection({int timeout = 30}) async {
    final completer = Completer<bool>();

    if (getIt<CommunicationBloc>().state.connectionStatus ==
        ConnectionStatus.connected) {
      return true;
    }

    final sub = getIt<CommunicationBloc>().stream.listen((state) {
      if (state.connectionStatus == ConnectionStatus.connected &&
          !completer.isCompleted) {
        completer.complete(true);
      }
    });

    final timer = Timer(Duration(seconds: timeout), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    final result = await completer.future;
    sub.cancel();
    timer.cancel();
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
          ? context.l10n.desktopContinueImporting
          : null,
    );
  }
}
