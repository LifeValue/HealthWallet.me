part of '../share_records_bloc.dart';

extension ShareRecordsSessionHandler on ShareRecordsBloc {
  void handleSessionEndRequested(
    SessionEndRequested event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(
      state.copyWith(
        showExitConfirmationDialog: true,
        statusMessage: _strings.l10n.shareStatusConfirmExit,
      ),
    );
  }

  void handleContinueViewing(
    ContinueViewing event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(
      state.copyWith(
        showExitConfirmationDialog: false,
        statusMessage: _strings.l10n.shareStatusViewingRecords(
          state.receivedData?.recordCount ?? 0,
        ),
      ),
    );
  }

  void handleAppBackgrounded(
    AppBackgrounded event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (state.receivedData != null) {
      add(const ShareRecordsEvent.dataDestructionConfirmed());
    }
  }

  void handleNavigationExitDetected(
    NavigationExitDetected event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (state.receivedData != null) {
      emit(state.copyWith(showExitConfirmationDialog: true));
    }
  }

  Future<void> handleDataDestructionConfirmed(
    DataDestructionConfirmed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    emit(state.copyWith(showExitConfirmationDialog: false));

    _viewingTimer?.cancel();

    try {
      await _service.sendKillSignal();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('[SHARE] Failed to send kill signal to sender: $e');
    }

    EphemeralSessionManager.instance.destroySession(reason: 'user_confirmed');

    await _service.disconnect();

    add(const ShareRecordsEvent.dataDestroyed());
  }

  Future<void> handleDataDestroyed(
    DataDestroyed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    await _cleanupEphemeralData();

    emit(
      state.copyWith(
        phase: SharePhase.sessionEnded,
        receivedData: null,
        viewingTimeRemaining: null,
        isSessionActive: false,
        isDataDestroyed: true,
        sessionEndReason: ShareSessionEndReason.dataDeleted,
        statusMessage: _strings.l10n.shareStatusDataDeleted,
      ),
    );
  }

  Future<void> _cleanupEphemeralData() async {
    final receivedData = state.receivedData;
    if (receivedData != null) {
      // The attachments all live in the session's own directory, found by
      // its id (never derived from the attachment paths).
      await _service.cleanupSessionTempDir(receivedData.sessionId);
    }

    for (final noteId in _insertedEphemeralNoteIds) {
      try {
        await _recordsRepository.deleteRecordNote(
          RecordNote(id: noteId, timestamp: DateTime.now()),
        );
      } catch (e) {
        debugPrint('[SHARE] Error deleting ephemeral note $noteId: $e');
      }
    }
    _insertedEphemeralNoteIds.clear();
  }

  void handleTimerTicked(
    TimerTicked event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (state.isSending && state.phase == SharePhase.monitoringSession) {
      final sessionStart = state.sessionStartedAt;
      if (sessionStart != null) {
        final elapsed = DateTime.now().difference(sessionStart);
        final remaining = state.selectedViewingDuration - elapsed;

        if (remaining <= Duration.zero) {
          _monitoringFallbackTimer?.cancel();
          emit(
            state.copyWith(
              phase: SharePhase.sessionEnded,
              isSessionActive: false,
              viewingTimeRemaining: Duration.zero,
              sessionEndReason: ShareSessionEndReason.expired,
              statusMessage: _strings.l10n.shareStatusSessionExpired,
            ),
          );
          _viewingTimer?.cancel();
          return;
        }

        emit(state.copyWith(viewingTimeRemaining: remaining));
      }
      return;
    }

    final remaining = EphemeralSessionManager.instance.timeRemaining;

    if (remaining == null || remaining <= Duration.zero) {
      add(const ShareRecordsEvent.dataDestructionConfirmed());
      return;
    }

    emit(state.copyWith(viewingTimeRemaining: remaining));
  }

  Future<void> handleKillSessionRequested(
    KillSessionRequested event,
    Emitter<ShareRecordsState> emit,
  ) async {
    emit(
      state.copyWith(
        statusMessage: _strings.l10n.shareStatusTerminatingSession,
      ),
    );

    try {
      await _service.sendKillSignal();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('[ERROR] Kill signal failed: $e');
    }

    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();

    await _service.disconnect();

    emit(
      state.copyWith(
        phase: SharePhase.sessionEnded,
        isSessionActive: false,
        sessionEndReason: ShareSessionEndReason.terminated,
        statusMessage: _strings.l10n.shareStatusSessionTerminated,
      ),
    );
  }

  Future<void> handleRemoteSessionKilled(
    RemoteSessionKilled event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();

    await _service.disconnect();

    emit(
      state.copyWith(
        phase: SharePhase.sessionEnded,
        isSessionActive: false,
        sessionEndReason: ShareSessionEndReason.remoteTerminated,
        statusMessage: _strings.l10n.shareStatusRemoteSessionTerminated,
      ),
    );
  }

  Future<void> handleSessionExtendRequested(
    SessionExtendRequested event,
    Emitter<ShareRecordsState> emit,
  ) async {
    if (state.extensionsUsed >= state.maxExtensions) {
      debugPrint('[SHARE] Extension request denied - max extensions reached');
      return;
    }
    if (state.extensionRequestPending) {
      debugPrint('[SHARE] Extension request already pending');
      return;
    }

    emit(state.copyWith(extensionRequestPending: true));

    try {
      await _service.sendExtendRequest(durationSeconds: event.durationSeconds);
    } catch (e) {
      debugPrint('[SHARE] Failed to send extend request: $e');
      emit(state.copyWith(extensionRequestPending: false));
    }
  }

  void handleRemoteExtendRequest(
    RemoteExtendRequest event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (state.extensionsUsed >= state.maxExtensions) {
      debugPrint('[SHARE] Auto-rejecting extension - max extensions reached');
      _service.sendExtendRejected();
      return;
    }

    if (state.isReceiving) {
      add(ShareRecordsEvent.extendAccepted(event.durationSeconds));
    } else {
      emit(
        state.copyWith(
          pendingExtendDurationSeconds: event.durationSeconds,
        ),
      );
    }
  }

  Future<void> handleExtendAccepted(
    ExtendAccepted event,
    Emitter<ShareRecordsState> emit,
  ) async {
    try {
      await _service.sendExtendAccepted(durationSeconds: event.durationSeconds);
    } catch (e) {
      debugPrint('[SHARE] Failed to send extend accepted: $e');
    }

    final duration = Duration(seconds: event.durationSeconds);
    EphemeralSessionManager.instance.extendSession(duration);

    final newRemaining = state.viewingTimeRemaining != null
        ? state.viewingTimeRemaining! + duration
        : duration;

    emit(
      state.copyWith(
        extensionsUsed: state.extensionsUsed + 1,
        pendingExtendDurationSeconds: null,
        viewingTimeRemaining: newRemaining,
        selectedViewingDuration: state.selectedViewingDuration + duration,
      ),
    );
  }

  Future<void> handleExtendRejected(
    ExtendRejected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    try {
      await _service.sendExtendRejected();
    } catch (e) {
      debugPrint('[SHARE] Failed to send extend rejected: $e');
    }

    emit(
      state.copyWith(
        pendingExtendDurationSeconds: null,
      ),
    );
  }

  void handleRemoteExtendAccepted(
    RemoteExtendAccepted event,
    Emitter<ShareRecordsState> emit,
  ) {
    final duration = Duration(seconds: event.durationSeconds);
    EphemeralSessionManager.instance.extendSession(duration);

    final newRemaining = state.viewingTimeRemaining != null
        ? state.viewingTimeRemaining! + duration
        : duration;

    emit(
      state.copyWith(
        extensionsUsed: state.extensionsUsed + 1,
        extensionRequestPending: false,
        viewingTimeRemaining: newRemaining,
        selectedViewingDuration: state.selectedViewingDuration + duration,
      ),
    );
  }

  void handleRemoteExtendRejected(
    RemoteExtendRejected event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(
      state.copyWith(
        extensionRequestPending: false,
        statusMessage: _strings.l10n.shareStatusExtensionDeclined,
      ),
    );
  }

  void handleViewingStartedReceived(
    ViewingStartedReceived event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (!state.isSending) return;

    if (state.sessionStartedAt != null) {
      debugPrint(
        '[SHARE] viewingStarted already processed, ignoring duplicate',
      );
      return;
    }

    if (state.phase == SharePhase.connecting ||
        state.phase == SharePhase.monitoringSession) {
      _monitoringFallbackTimer?.cancel();
      _monitoringFallbackTimer = null;

      debugPrint(
        '[SHARE] Receiver started viewing - beginning countdown timer',
      );
      emit(
        state.copyWith(
          phase: SharePhase.monitoringSession,
          sessionStartedAt: DateTime.now(),
          viewingTimeRemaining: state.selectedViewingDuration,
          statusMessage: _strings.l10n.shareStatusReceiverViewing,
        ),
      );
      _startViewingTimer();
      return;
    }

    if (state.phase != SharePhase.monitoringSession) {
      debugPrint(
        '[SHARE] viewingStarted arrived early (phase=${state.phase}), buffering',
      );
      _pendingViewingStarted = true;
      return;
    }
  }

  Future<void> handleRemoteInvitationRejected(
    RemoteInvitationRejected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    if (!state.isSending) {
      return;
    }

    debugPrint('[SHARE] Receiver declined the invitation');

    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();

    emit(
      state.copyWith(
        phase: SharePhase.sessionEnded,
        isSessionActive: false,
        sessionEndReason: ShareSessionEndReason.invitationDeclined,
        statusMessage: _strings.l10n.shareStatusReceiverDeclined,
      ),
    );

    await _service.disconnect();
  }

  Future<void> handleReceiverInitializedWithInvitation(
    ReceiverInitializedWithInvitation event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final manager = getIt<ReceiveModeService>();
    manager.clearPendingInvitation();
    manager.pauseListening();

    final pendingData = manager.pendingReceivedData;
    if (pendingData != null) {
      manager.clearPendingReceivedData();
      EphemeralSessionManager.instance.startSession(pendingData);
      emit(
        state.copyWith(
          mode: ShareMode.receiving,
          phase: SharePhase.viewingRecords,
          receivedData: pendingData,
          viewingTimeRemaining: pendingData.viewDuration,
          isSessionActive: true,
          statusMessage: _strings.l10n.shareStatusViewingRecordsFrom(
            pendingData.recordCount,
            pendingData.senderDeviceName,
          ),
        ),
      );
      _startViewingTimer();
      return;
    }

    if (event.preAccepted) {
      emit(
        state.copyWith(
          mode: ShareMode.receiving,
          phase: SharePhase.connecting,
          statusMessage: _strings.l10n.shareStatusReceivingFrom(
            event.deviceName,
          ),
        ),
      );
      await _service.acceptInvitation(event.invitationId);
      return;
    }

    emit(
      state.copyWith(
        mode: ShareMode.receiving,
        phase: SharePhase.discoveringPeers,
        pendingInvitationId: event.invitationId,
        pendingInvitationDeviceName: event.deviceName,
        statusMessage: _strings.l10n.shareStatusDeviceWantsToShare(
          event.deviceName,
        ),
      ),
    );
  }

  Future<void> handleReceiverInitializedWithData(
    ReceiverInitializedWithData event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final manager = getIt<ReceiveModeService>();
    final container = manager.pendingReceivedData;
    manager.clearPendingReceivedData();
    manager.clearPendingInvitation();
    manager.pauseListening();

    if (container == null) {
      emit(
        state.copyWith(
          phase: SharePhase.error,
          errorMessage: _strings.l10n.shareNoDataAvailable,
        ),
      );
      return;
    }

    EphemeralSessionManager.instance.startSession(container);

    emit(
      state.copyWith(
        mode: ShareMode.receiving,
        phase: SharePhase.viewingRecords,
        receivedData: container,
        viewingTimeRemaining: container.viewDuration,
        isSessionActive: true,
        statusMessage: _strings.l10n.shareStatusViewingRecordsFrom(
          container.recordCount,
          container.senderDeviceName,
        ),
      ),
    );

    _startViewingTimer();
  }
}
