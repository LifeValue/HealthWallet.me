part of '../share_records_bloc.dart';

void _shareLog(String msg) {
  final ts = DateTime.now().toIso8601String().substring(11, 23);
  ShareLogBuffer.instance.log('[$ts][SHARE] $msg');
}

extension ShareRecordsTransferHandler on ShareRecordsBloc {
  Future<void> handleDiscoveryStarted(
    DiscoveryStarted event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _shareLog('Discovery started (bluetooth=${event.useBluetooth})');
    final result = await SharePermissionsHelper.requestSharePermissions();

    switch (result) {
      case PermissionGranted():
        _shareLog('Permissions granted');
        final manager = getIt<ReceiveModeService>();
        if (manager.isListening) {
          manager.pauseListening();
        }

        emit(
          state.copyWith(
            discoveredPeers: [],
            statusMessage: _strings.l10n.shareStatusScanning,
          ),
        );
        await _service.disconnect();
        await _service.startDiscovery(useBluetooth: event.useBluetooth);

      case PermissionDenied():
        _shareLog('ERROR: Permissions denied: ${result.permissions}');
        emit(
          state.copyWith(
            phase: SharePhase.error,
            errorMessage: result.message(_strings.l10n),
            statusMessage: _strings.l10n.shareStatusPermissionsRequired,
          ),
        );

      case PermissionPermanentlyDenied():
        _shareLog(
          'ERROR: Permissions permanently denied: ${result.permissions}',
        );
        emit(
          state.copyWith(
            phase: SharePhase.error,
            errorMessage: result.message(_strings.l10n),
            showSettingsDialog: true,
            statusMessage: _strings.l10n.shareStatusEnablePermissionsInSettings,
          ),
        );
    }
  }

  Future<void> handleSymmetricDiscoveryStarted(
    SymmetricDiscoveryStarted event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final result = await SharePermissionsHelper.requestSharePermissions();

    switch (result) {
      case PermissionGranted():
        final manager = getIt<ReceiveModeService>();
        if (manager.isListening) {
          manager.pauseListening();
        }

        emit(
          state.copyWith(
            phase: SharePhase.discoveringPeers,
            discoveredPeers: [],
            statusMessage: _strings.l10n.shareStatusLookingForDevices,
          ),
        );
        await _service.disconnect();
        await _service.startSymmetricDiscovery();

      case PermissionDenied():
        emit(
          state.copyWith(
            phase: SharePhase.error,
            errorMessage: result.message(_strings.l10n),
            statusMessage: _strings.l10n.shareStatusPermissionsRequired,
          ),
        );

      case PermissionPermanentlyDenied():
        emit(
          state.copyWith(
            phase: SharePhase.error,
            errorMessage: result.message(_strings.l10n),
            showSettingsDialog: true,
            statusMessage: _strings.l10n.shareStatusEnablePermissionsInSettings,
          ),
        );
    }
  }

  /// Names the native layer reports for a peer it could not name. They come
  /// from the other device, not from the app's own strings.
  bool _isUnknownName(String? name) {
    return name == null ||
        name == 'Unknown' ||
        name == 'Unknown Device' ||
        name == 'unknown';
  }

  bool _namesMatch(String a, String b) {
    return a == b || a.startsWith(b) || b.startsWith(a);
  }

  // iPhones found through MultipeerConnectivity carry a per-launch id. Two such
  // ids are always two phones, even when both are called "iPhone" (iOS 16+).
  static const _mpcIdPrefix = 'mpc_';

  bool _isMpcId(String deviceId) => deviceId.startsWith(_mpcIdPrefix);

  void handlePeerDiscovered(
    PeerDiscovered event,
    Emitter<ShareRecordsState> emit,
  ) {
    final peers = List<PeerDevice>.from(state.discoveredPeers);
    final newName = event.peer.deviceName;
    final existingIndex = peers.indexWhere(
      (p) => p.deviceId == event.peer.deviceId,
    );

    if (existingIndex >= 0) {
      final existing = peers[existingIndex];
      peers[existingIndex] = existing.copyWith(
        deviceName: _isUnknownName(newName) ? existing.deviceName : newName,
        osType: event.peer.osType ?? existing.osType,
        status: event.peer.status,
      );
    } else {
      if (!_isUnknownName(newName)) {
        final nameMatchIndex = peers.indexWhere(
          (p) =>
              !_isUnknownName(p.deviceName) &&
              _namesMatch(p.deviceName!, newName!) &&
              !(_isMpcId(p.deviceId) && _isMpcId(event.peer.deviceId)),
        );
        if (nameMatchIndex >= 0) {
          final existing = peers[nameMatchIndex];
          final longerName =
              newName!.length >= (existing.deviceName?.length ?? 0)
              ? newName
              : existing.deviceName;
          // Keep the MPC id when merging the same phone's BLE entry: the
          // plugin can invite it exactly.
          peers[nameMatchIndex] = existing.copyWith(
            deviceId:
                _isMpcId(existing.deviceId) && !_isMpcId(event.peer.deviceId)
                ? existing.deviceId
                : event.peer.deviceId,
            deviceName: longerName,
            osType: event.peer.osType ?? existing.osType,
            status: event.peer.status,
          );
          emit(
            state.copyWith(
              discoveredPeers: peers,
              statusMessage: _strings.l10n.shareStatusFoundDevices(
                peers.length,
              ),
            ),
          );
          return;
        }
      }

      if (_isUnknownName(newName)) {
        return;
      }
      peers.add(event.peer);
    }

    emit(
      state.copyWith(
        discoveredPeers: peers,
        statusMessage: _strings.l10n.shareStatusFoundDevices(peers.length),
      ),
    );
  }

  Future<void> handlePeerSelected(
    PeerSelected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _shareLog('Peer selected: ${event.deviceId}');
    final peer = state.discoveredPeers.firstWhere(
      (p) => p.deviceId == event.deviceId,
      orElse: () => PeerDevice(deviceId: event.deviceId),
    );

    _shareLog('Connecting to ${peer.deviceName}...');
    _pendingViewingStarted = false;
    emit(
      state.copyWith(
        selectedPeer: peer,
        sessionStartedAt: null,
        remoteEndUnconfirmed: false,
        phase: SharePhase.connecting,
        statusMessage: _strings.l10n.shareStatusConnectingTo(
          peer.displayName(_strings.l10n),
        ),
      ),
    );

    if (state.isSending && state.selection.isNotEmpty) {
      emit(
        state.copyWith(
          statusMessage: _strings.l10n.shareStatusPreparingRecords,
        ),
      );

      final selectedRecords = state.selection.selectedRecords.values.toList();
      _shareLog(
        'Selected ${selectedRecords.length} records, enriching with related...',
      );
      final enrichedRecords = await _enrichSelectionWithRelatedResources(
        selectedRecords,
      );

      _shareLog(
        'Enriched to ${enrichedRecords.length} records (types: ${enrichedRecords.map((r) => r.fhirType.name).toSet().toList()})',
      );

      final notesMap = <String, List<RecordNote>>{};
      for (final resource in enrichedRecords) {
        try {
          final notes = await _recordsRepository.getRecordNotes(resource.id);
          if (notes.isNotEmpty) {
            notesMap[resource.id] = notes;
          }
        } catch (e) {
          _shareLog('WARNING: Error fetching notes for ${resource.id}: $e');
        }
      }
      _shareLog('Notes: ${notesMap.length} resources have notes');

      _shareLog('Creating payload...');
      final payload = await _service.createPayload(
        resources: enrichedRecords,
        deviceName: _deviceName,
        expiresInSeconds: state.selectedViewingDuration.inSeconds,
        notesMap: notesMap,
        activeFilters: state.appliedFilters.map((f) => f.name).toList(),
      );
      _shareLog('Encrypting and preparing files for sending...');
      // A retry selects a peer again with a new payload: drop the old one.
      await _deleteSentPayload();
      await _disposeSecureSession();
      final session = _service.createSecureSession();
      _secureSession = session;
      _tempFilePath = await _service.prepareFilesForSending(payload, session);
      // Writing the payload takes a while (sealing generates keys). If the
      // share screen closed meanwhile, its cleanup has already run: delete
      // this payload here and start no key exchange on the closed session.
      if (_isClosed || !identical(session, _secureSession)) {
        await _deleteSentPayload();
        return;
      }
      if (_tempFilePath == null) {
        _shareLog('ERROR: Failed to prepare files for sending');
        emit(
          state.copyWith(
            phase: SharePhase.error,
            errorMessage: _strings.l10n.shareErrorPrepareFiles,
          ),
        );
        return;
      }
      unawaited(_awaitReceiverKey(session));
    }

    await _service.selectPeer(event.deviceId);
  }

  /// Runs in the background until the receiver answers with its key, which
  /// happens only after it has the encrypted records.
  Future<void> _awaitReceiverKey(SecureShareSession session) async {
    try {
      final code = await session.awaitReceiver();
      if (_isClosed || !identical(session, _secureSession)) return;
      add(ShareRecordsEvent.verificationCodeReady(code));
    } on SecureShareCancelled {
      return;
    } on SecureShareException catch (e) {
      _shareLog('ERROR: Key exchange failed: ${e.message}');
      if (_isClosed || !identical(session, _secureSession)) return;
      add(ShareRecordsEvent.secureShareFailed(e.message));
    }
  }

  /// Deletes the encrypted payload being sent, if there is one.
  Future<void> _deleteSentPayload() async {
    final path = _tempFilePath;
    if (path == null) return;
    _tempFilePath = null;
    await _service.cleanupTempFile(path);
  }

  Future<List<IFhirResource>> _enrichSelectionWithRelatedResources(
    List<IFhirResource> selectedRecords,
  ) async {
    final enrichedResources = <String, IFhirResource>{};
    for (final record in selectedRecords) {
      enrichedResources[record.id] = record;
    }

    for (final record in selectedRecords) {
      try {
        List<IFhirResource> relatedResources = [];

        if (record.fhirType == FhirType.Encounter) {
          relatedResources = await _recordsRepository
              .getRelatedResourcesForEncounter(
                encounterId: record.resourceId,
              );
        } else {
          relatedResources = await _recordsRepository.getRelatedResources(
            resource: record,
          );
        }

        for (final relatedResource in relatedResources) {
          if (!enrichedResources.containsKey(relatedResource.id)) {
            enrichedResources[relatedResource.id] = relatedResource;
          }
        }
      } catch (e) {
        debugPrint(
          '[SHARE] Error fetching related resources for ${record.id}: $e',
        );
      }
    }

    return enrichedResources.values.toList();
  }

  void handleTransferStarted(
    TransferStarted event,
    Emitter<ShareRecordsState> emit,
  ) {
    _shareLog('=== Transfer started ===');
    emit(
      state.copyWith(
        phase: SharePhase.transferring,
        statusMessage: null,
        isSessionActive: true,
      ),
    );
  }

  void handleTransferProgressUpdated(
    TransferProgressUpdated event,
    Emitter<ShareRecordsState> emit,
  ) {
    final percent = (event.progress.progress * 100).toInt();
    _shareLog('Transfer progress: $percent%');
    emit(
      state.copyWith(
        transferProgress: event.progress,
        statusMessage: _strings.l10n.shareStatusTransferring(percent),
      ),
    );
  }

  Future<void> handleTransferCompleted(
    TransferCompleted event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _shareLog('=== Transfer completed (isSending=${state.isSending}) ===');
    if (state.isSending) {
      if (_pendingViewingStarted) {
        _pendingViewingStarted = false;
        debugPrint('[SHARE] Applying buffered viewingStarted signal');
        emit(
          state.copyWith(
            phase: SharePhase.monitoringSession,
            isSessionActive: true,
            sessionStartedAt: DateTime.now(),
            viewingTimeRemaining: state.selectedViewingDuration,
            statusMessage: _strings.l10n.shareStatusReceiverViewing,
          ),
        );
        _startViewingTimer();
      } else if (state.phase != SharePhase.verifyingCode &&
          state.phase != SharePhase.awaitingViewer) {
        // The monitoring fallback starts only once the codes are confirmed:
        // until then the receiver cannot open the records.
        debugPrint(
          '[SHARE] Files sent - staying on connecting until receiver accepts',
        );
        emit(
          state.copyWith(
            phase: SharePhase.connecting,
            isSessionActive: true,
            statusMessage: _strings.l10n.shareStatusRecordsSentWaiting,
          ),
        );
      }
      // The payload has been sent; its encrypted copy in temp isn't needed.
      // Deleted after the state changes so no other event sees a stale phase.
      await _deleteSentPayload();
    } else {
      debugPrint(
        '[SHARE] Transfer completed for receiver - waiting for data to be parsed',
      );
    }
  }

  Future<void> handleTransferFailed(
    TransferFailed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _shareLog('ERROR: Transfer failed: ${event.error}');
    if (state.phase == SharePhase.selectingRecords ||
        state.phase == SharePhase.sessionEnded) {
      return;
    }

    final isConnectionPhase =
        state.phase == SharePhase.connecting ||
        state.phase == SharePhase.transferring;
    if (isConnectionPhase &&
        state.connectionRetryCount < 3 &&
        !state.wifiToggleNeeded) {
      final retryCount = state.connectionRetryCount + 1;
      emit(
        state.copyWith(
          phase: SharePhase.connecting,
          connectionRetryCount: retryCount,
          statusMessage: _strings.l10n.shareRetryingCount(retryCount),
          errorMessage: null,
        ),
      );
      add(const ShareRecordsEvent.connectionRetried());
      return;
    }

    await _deleteSentPayload();
    await _disposeSecureSession();

    emit(
      state.copyWith(
        phase: SharePhase.error,
        isSessionActive: false,
        errorMessage: event.error,
        statusMessage: _strings.l10n.shareStatusTransferFailed,
        connectionRetryCount: 0,
      ),
    );
  }

  Future<void> handleTransferCancelled(
    TransferCancelled event,
    Emitter<ShareRecordsState> emit,
  ) async {
    await _service.disconnect();
    emit(
      state.copyWith(
        mode: ShareMode.idle,
        isSessionActive: false,
        statusMessage: _strings.l10n.shareStatusTransferCancelled,
      ),
    );
  }

  Future<void> handleConnectionRetried(
    ConnectionRetried event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _shareLog('Connection retry attempt ${state.connectionRetryCount}');
    await _disposeSecureSession();
    await _service.disconnect();
    emit(
      state.copyWith(
        phase: SharePhase.discoveringPeers,
        errorMessage: null,
        statusMessage: state.isSending
            ? _strings.l10n.shareStatusLookingForDevices
            : _strings.l10n.shareStatusWaitingForSender,
        discoveredPeers: [],
        selectedPeer: null,
        isSessionActive: false,
      ),
    );

    if (state.isSending) {
      add(const ShareRecordsEvent.discoveryStarted());
    } else {
      await _service.startReceivingInMemory();
    }
  }

  void handleInvitationReceived(
    InvitationReceived event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(
      state.copyWith(
        pendingInvitationId: event.invitationId,
        pendingInvitationDeviceName: event.deviceName,
        statusMessage: _strings.l10n.shareStatusDeviceWantsToShare(
          event.deviceName,
        ),
      ),
    );
  }

  Future<void> handleInvitationAccepted(
    InvitationAccepted event,
    Emitter<ShareRecordsState> emit,
  ) async {
    emit(
      state.copyWith(
        pendingInvitationId: null,
        phase: SharePhase.transferring,
        statusMessage: _strings.l10n.shareReceivingRecords,
      ),
    );

    await _service.acceptInvitation(event.invitationId);
  }

  Future<void> handleInvitationRejected(
    InvitationRejected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    emit(
      state.copyWith(
        pendingInvitationId: null,
        pendingInvitationDeviceName: null,
        statusMessage: _strings.l10n.shareStatusInvitationRejected,
      ),
    );

    await _service.rejectInvitation(event.invitationId);
  }

  Future<void> handleDataReceived(
    DataReceived event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _shareLog(
      'Data received: ${event.data.fileName} (${event.data.size} bytes)',
    );
    await _receiveSecurePayload(event.data.data, emit);
  }

  Future<void> handleFilesReceived(
    FilesReceived event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _shareLog('Files received: ${event.filePaths.length} file(s)');
    emit(
      state.copyWith(
        statusMessage: _strings.l10n.shareStatusProcessingReceived,
      ),
    );

    for (final filePath in event.filePaths) {
      _shareLog('Reading file: $filePath');
      final bytes = await _service.readReceivedFile(filePath);
      if (bytes == null) {
        _shareLog('ERROR: Failed to read file: $filePath');
        emit(
          state.copyWith(
            phase: SharePhase.error,
            errorMessage: _strings.l10n.shareErrorParseFile,
          ),
        );
        return;
      }
      await _receiveSecurePayload(bytes, emit);
    }
  }

  /// Receiver: runs the key exchange for an encrypted share, shows the code,
  /// and opens the records once the sender confirms it.
  Future<void> _receiveSecurePayload(
    Uint8List bytes,
    Emitter<ShareRecordsState> emit,
  ) async {
    if (!ShareEnvelope.looksLikeEnvelope(bytes)) {
      _shareLog('ERROR: Received an unencrypted share');
      emit(
        state.copyWith(
          phase: SharePhase.error,
          errorMessage: _strings.l10n.shareErrorOlderVersion,
        ),
      );
      return;
    }

    await _disposeSecureSession();
    final session = _service.createSecureSession();
    _secureSession = session;

    try {
      final code = await session.open(bytes);
      if (emit.isDone || !identical(session, _secureSession)) return;
      _shareLog('Key exchange done, waiting for the sender to confirm');
      emit(
        state.copyWith(
          mode: ShareMode.receiving,
          phase: SharePhase.verifyingCode,
          verificationCode: code,
          statusMessage: _strings.l10n.shareStatusCompareWithSender,
        ),
      );

      final plaintext = await session.awaitPayload();
      if (emit.isDone || !identical(session, _secureSession)) return;
      final container = await _service.parsePayload(plaintext);
      // Cancelled, backgrounded or closed while decrypting: the session was
      // ended already, so the records must not open.
      if (emit.isDone || !identical(session, _secureSession)) {
        if (container != null) {
          await _service.cleanupSessionTempDir(container.sessionId);
        }
        return;
      }
      await _disposeSecureSession();
      if (container == null) {
        _shareLog('ERROR: Failed to parse the decrypted payload');
        emit(
          state.copyWith(
            phase: SharePhase.error,
            verificationCode: null,
            errorMessage: _strings.l10n.shareErrorParseData,
          ),
        );
        return;
      }
      _shareLog(
        'Parsed ${container.recordCount} records from ${container.senderDeviceName}',
      );
      add(ShareRecordsEvent.ephemeralDataParsed(container));
    } on SecureShareCancelled {
      return;
    } on SecureShareException catch (e) {
      _shareLog('ERROR: Key exchange failed: ${e.message}');
      if (emit.isDone || !identical(session, _secureSession)) return;
      add(ShareRecordsEvent.secureShareFailed(e.message));
    }
  }

  void handleVerificationCodeReady(
    VerificationCodeReady event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (!state.isSending || _secureSession == null) return;
    _shareLog('Receiver key received, showing verification code');
    emit(
      state.copyWith(
        phase: SharePhase.verifyingCode,
        verificationCode: event.code,
        statusMessage: _strings.l10n.shareStatusCompareWithReceiver,
      ),
    );
  }

  Future<void> handleVerificationConfirmed(
    VerificationConfirmed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final session = _secureSession;
    if (!state.isSending || session == null) return;

    // Leave the verification phase before the key goes out, so a fast
    // viewingStarted from the receiver is not buffered and lost.
    final viewing = state.sessionStartedAt != null;
    emit(
      state.copyWith(
        phase: viewing
            ? SharePhase.monitoringSession
            : SharePhase.awaitingViewer,
        verificationCode: null,
        statusMessage: viewing
            ? _strings.l10n.shareStatusReceiverViewing
            : _strings.l10n.shareStatusRecordsSentAwaitingViewer,
      ),
    );

    try {
      await session.confirm();
      _shareLog('Codes confirmed, payload key sent');
    } on SecureShareException catch (e) {
      _shareLog('ERROR: Could not send the payload key: ${e.message}');
      add(ShareRecordsEvent.secureShareFailed(e.message));
      return;
    } on SecureShareCancelled {
      return;
    }
    await _disposeSecureSession();
    if (!viewing) _startMonitoringFallbackTimer();
  }

  Future<void> handleSecureShareFailed(
    SecureShareFailed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();
    await _disposeSecureSession();
    await _deleteSentPayload();
    try {
      await _service.sendKillSignal();
    } catch (e) {
      debugPrint('[SHARE] Failed to send kill signal: $e');
    }
    await _service.disconnect();

    emit(
      state.copyWith(
        phase: SharePhase.error,
        isSessionActive: false,
        verificationCode: null,
        errorMessage: _strings.l10n.shareErrorSecureConnection,
        statusMessage: _strings.l10n.shareStatusSecureConnectionFailed,
      ),
    );
  }

  Future<void> handleEphemeralDataParsed(
    EphemeralDataParsed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    // A cancel can land between parsing and this event.
    if (state.phase != SharePhase.verifyingCode) {
      await _service.cleanupSessionTempDir(event.container.sessionId);
      return;
    }
    _shareLog('=== Session started: ${event.container.sessionId} ===');
    _shareLog(
      'Records: ${event.container.recordCount}, Duration: ${event.container.viewDuration.inMinutes}min',
    );
    _shareLog('Filters: ${event.container.activeFilters}');
    _shareLog('Temp files: ${event.container.tempAttachmentPaths.length}');
    EphemeralSessionManager.instance.startSession(event.container);
    emit(
      state.copyWith(
        phase: SharePhase.viewingRecords,
        receivedData: event.container,
        verificationCode: null,
        viewingTimeRemaining: event.container.viewDuration,
        isSessionActive: true,
        statusMessage: _strings.l10n.shareStatusViewingRecordsFrom(
          event.container.recordCount,
          event.container.senderDeviceName,
        ),
      ),
    );

    _recordsRepository.showSharedNotes(event.container.notes);
    _startViewingTimer();

    try {
      await _service.sendViewingStarted();
      _shareLog('Sent viewing started signal to sender');
    } catch (e) {
      _shareLog('WARNING: Failed to send viewing started signal: $e');
    }
  }
}
