part of '../share_records_bloc.dart';

extension ShareRecordsTransferHandler on ShareRecordsBloc {
  Future<void> handleDiscoveryStarted(
    DiscoveryStarted event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final result = await SharePermissionsHelper.requestSharePermissions();

    switch (result) {
      case PermissionGranted():
        final manager = getIt<ReceiveModeService>();
        if (manager.isListening) {
          manager.pauseListening();
        }

        emit(state.copyWith(
          discoveredPeers: [],
          statusMessage: 'Scanning for devices...',
        ));
        await _service.disconnect();
        await _service.startDiscovery(useBluetooth: event.useBluetooth);

      case PermissionDenied(:final message):
        emit(state.copyWith(
          phase: SharePhase.error,
          errorMessage: message,
          statusMessage: 'Permissions required',
        ));

      case PermissionPermanentlyDenied(:final message):
        emit(state.copyWith(
          phase: SharePhase.error,
          errorMessage: message,
          showSettingsDialog: true,
          statusMessage: 'Please enable permissions in Settings',
        ));
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

        emit(state.copyWith(
          phase: SharePhase.discoveringPeers,
          discoveredPeers: [],
          statusMessage: 'Looking for nearby devices...',
        ));
        await _service.disconnect();
        await _service.startSymmetricDiscovery();

      case PermissionDenied(:final message):
        emit(state.copyWith(
          phase: SharePhase.error,
          errorMessage: message,
          statusMessage: 'Permissions required',
        ));

      case PermissionPermanentlyDenied(:final message):
        emit(state.copyWith(
          phase: SharePhase.error,
          errorMessage: message,
          showSettingsDialog: true,
          statusMessage: 'Please enable permissions in Settings',
        ));
    }
  }

  bool _isUnknownName(String? name) {
    return name == null ||
        name == 'Unknown' ||
        name == 'Unknown Device' ||
        name == 'unknown';
  }

  bool _namesMatch(String a, String b) {
    return a == b || a.startsWith(b) || b.startsWith(a);
  }

  void handlePeerDiscovered(
    PeerDiscovered event,
    Emitter<ShareRecordsState> emit,
  ) {
    final peers = List<PeerDevice>.from(state.discoveredPeers);
    final newName = event.peer.deviceName;
    final existingIndex =
        peers.indexWhere((p) => p.deviceId == event.peer.deviceId);

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
              _namesMatch(p.deviceName!, newName!),
        );
        if (nameMatchIndex >= 0) {
          final existing = peers[nameMatchIndex];
          final longerName =
              newName!.length >= (existing.deviceName?.length ?? 0)
                  ? newName
                  : existing.deviceName;
          peers[nameMatchIndex] = existing.copyWith(
            deviceId: event.peer.deviceId,
            deviceName: longerName,
            osType: event.peer.osType ?? existing.osType,
            status: event.peer.status,
          );
          emit(state.copyWith(
            discoveredPeers: peers,
            statusMessage: 'Found ${peers.length} device(s)',
          ));
          return;
        }
      }

      if (_isUnknownName(newName)) {
        return;
      }
      peers.add(event.peer);
    }

    emit(state.copyWith(
      discoveredPeers: peers,
      statusMessage: 'Found ${peers.length} device(s)',
    ));
  }

  Future<void> handlePeerSelected(
    PeerSelected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final peer = state.discoveredPeers.firstWhere(
      (p) => p.deviceId == event.deviceId,
      orElse: () => PeerDevice(
        deviceId: event.deviceId,
        deviceName: 'Unknown Device',
      ),
    );

    emit(state.copyWith(
      selectedPeer: peer,
      phase: SharePhase.connecting,
      statusMessage: 'Connecting to ${peer.deviceName}...',
    ));

    if (state.isSending && state.selection.isNotEmpty) {
      emit(state.copyWith(
        statusMessage: 'Preparing records...',
      ));

      final selectedRecords =
          state.selection.selectedRecords.values.toList();
      final enrichedRecords =
          await _enrichSelectionWithRelatedResources(selectedRecords);

      debugPrint(
          '[SHARE] User selected ${selectedRecords.length} records');
      debugPrint(
          '[SHARE] Enriched to ${enrichedRecords.length} records (including related)');

      final notesMap = <String, List<RecordNote>>{};
      for (final resource in enrichedRecords) {
        try {
          final notes =
              await _recordsRepository.getRecordNotes(resource.id);
          if (notes.isNotEmpty) {
            notesMap[resource.id] = notes;
          }
        } catch (e) {
          debugPrint(
              '[SHARE] Error fetching notes for ${resource.id}: $e');
        }
      }

      final payload = await _service.createPayload(
        resources: enrichedRecords,
        deviceName: _deviceName,
        expiresInSeconds: state.selectedViewingDuration.inSeconds,
        notesMap: notesMap,
        activeFilters:
            state.appliedFilters.map((f) => f.name).toList(),
      );
      _tempFilePath = await _service.prepareFilesForSending(payload);
      if (_tempFilePath == null) {
        emit(state.copyWith(
          phase: SharePhase.error,
          errorMessage: 'Failed to prepare files for sending',
        ));
        return;
      }
    }

    await _service.selectPeer(event.deviceId);
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
          relatedResources =
              await _recordsRepository.getRelatedResourcesForEncounter(
            encounterId: record.resourceId,
          );
        } else {
          relatedResources =
              await _recordsRepository.getRelatedResources(
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
            '[SHARE] Error fetching related resources for ${record.id}: $e');
      }
    }

    return enrichedResources.values.toList();
  }

  void handleTransferStarted(
    TransferStarted event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(
      phase: SharePhase.transferring,
      statusMessage: 'Sending records...',
      isSessionActive: true,
    ));
  }

  void handleTransferProgressUpdated(
    TransferProgressUpdated event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(
      transferProgress: event.progress,
      statusMessage:
          'Transferring ${(state.progressPercentage * 100).toInt()}%',
    ));
  }

  void handleTransferCompleted(
    TransferCompleted event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (state.isSending) {
      if (_pendingViewingStarted) {
        _pendingViewingStarted = false;
        debugPrint('[SHARE] Applying buffered viewingStarted signal');
        emit(state.copyWith(
          phase: SharePhase.monitoringSession,
          isSessionActive: true,
          sessionStartedAt: DateTime.now(),
          viewingTimeRemaining: state.selectedViewingDuration,
          statusMessage:
              'Receiver is viewing records - monitoring session',
        ));
        _startViewingTimer();
      } else {
        debugPrint(
            '[SHARE] Files sent - staying on connecting until receiver accepts');
        emit(state.copyWith(
          phase: SharePhase.connecting,
          isSessionActive: true,
          statusMessage:
              'Records sent - waiting for receiver to accept',
        ));
        _startMonitoringFallbackTimer();
      }
    } else {
      debugPrint(
          '[SHARE] Transfer completed for receiver - waiting for data to be parsed');
    }
  }

  Future<void> handleTransferFailed(
    TransferFailed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    if (state.phase == SharePhase.selectingRecords ||
        state.phase == SharePhase.sessionEnded) {
      return;
    }

    final isConnectionPhase = state.phase == SharePhase.connecting ||
        state.phase == SharePhase.transferring;
    if (isConnectionPhase &&
        state.connectionRetryCount < 3 &&
        !state.wifiToggleNeeded) {
      final retryCount = state.connectionRetryCount + 1;
      emit(state.copyWith(
        phase: SharePhase.connecting,
        connectionRetryCount: retryCount,
        statusMessage: 'Retrying ($retryCount/3)...',
        errorMessage: null,
      ));
      add(const ShareRecordsEvent.connectionRetried());
      return;
    }

    if (_tempFilePath != null) {
      await _service.cleanupTempFile(_tempFilePath!);
      _tempFilePath = null;
    }

    emit(state.copyWith(
      phase: SharePhase.error,
      isSessionActive: false,
      errorMessage: event.error,
      statusMessage: 'Transfer failed',
      connectionRetryCount: 0,
    ));
  }

  Future<void> handleTransferCancelled(
    TransferCancelled event,
    Emitter<ShareRecordsState> emit,
  ) async {
    await _service.disconnect();
    emit(state.copyWith(
      mode: ShareMode.idle,
      isSessionActive: false,
      statusMessage: 'Transfer cancelled',
    ));
  }

  Future<void> handleConnectionRetried(
    ConnectionRetried event,
    Emitter<ShareRecordsState> emit,
  ) async {
    await _service.disconnect();
    emit(state.copyWith(
      phase: SharePhase.discoveringPeers,
      errorMessage: null,
      statusMessage: state.isSending
          ? 'Looking for nearby devices...'
          : 'Waiting for sender...',
      discoveredPeers: [],
      selectedPeer: null,
      isSessionActive: false,
    ));

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
    emit(state.copyWith(
      pendingInvitationId: event.invitationId,
      pendingInvitationDeviceName: event.deviceName,
      statusMessage: '${event.deviceName} wants to share records',
    ));
  }

  Future<void> handleInvitationAccepted(
    InvitationAccepted event,
    Emitter<ShareRecordsState> emit,
  ) async {
    emit(state.copyWith(
      pendingInvitationId: null,
      phase: SharePhase.transferring,
      statusMessage: 'Receiving records...',
    ));

    await _service.acceptInvitation(event.invitationId);
  }
  Future<void> handleInvitationRejected(
    InvitationRejected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    emit(state.copyWith(
      pendingInvitationId: null,
      pendingInvitationDeviceName: null,
      statusMessage: 'Invitation rejected',
    ));

    await _service.rejectInvitation(event.invitationId);
  }
  Future<void> handleDataReceived(
    DataReceived event,
    Emitter<ShareRecordsState> emit,
  ) async {
    debugPrint(
        '[SHARE] onDataReceived: ${event.data.fileName} (${event.data.size} bytes), phase=${state.phase}');
    final container = await _service.parseReceivedData(event.data);
    if (container != null) {
      debugPrint(
          '[SHARE] parseReceivedData succeeded: ${container.recordCount} records');
      add(ShareRecordsEvent.ephemeralDataParsed(container));
    } else {
      debugPrint('[SHARE] parseReceivedData returned null!');
      emit(state.copyWith(
        phase: SharePhase.error,
        errorMessage: 'Failed to parse received data',
      ));
    }
  }

  Future<void> handleFilesReceived(
    FilesReceived event,
    Emitter<ShareRecordsState> emit,
  ) async {
    emit(state.copyWith(statusMessage: 'Processing received records...'));

    for (final filePath in event.filePaths) {
      final container = await _service.parseReceivedFile(filePath);
      if (container != null) {
        add(ShareRecordsEvent.ephemeralDataParsed(container));
      } else {
        emit(state.copyWith(
          phase: SharePhase.error,
          errorMessage: 'Failed to parse received file',
        ));
      }
    }
  }

  Future<void> handleEphemeralDataParsed(
    EphemeralDataParsed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    EphemeralSessionManager.instance.startSession(event.container);
    emit(state.copyWith(
      phase: SharePhase.viewingRecords,
      receivedData: event.container,
      viewingTimeRemaining: event.container.viewDuration,
      isSessionActive: true,
      statusMessage:
          'Viewing ${event.container.recordCount} records from ${event.container.senderDeviceName}',
    ));

    _startViewingTimer();

    await _insertEphemeralNotes(event.container);

    try {
      await _service.sendViewingStarted();
      debugPrint('[SHARE] Sent viewing started signal to sender');
    } catch (e) {
      debugPrint('[SHARE] Failed to send viewing started signal: $e');
    }
  }

  Future<void> _insertEphemeralNotes(
      EphemeralRecordsContainer container) async {
    for (final resource in container.records) {
      final notes = container.notes[resource.id];
      if (notes == null) continue;
      for (final note in notes) {
        try {
          final noteId = await _recordsRepository.addRecordNote(
            resourceId: resource.id,
            content: note.content,
          );
          _insertedEphemeralNoteIds.add(noteId);
        } catch (e) {
          debugPrint('[SHARE] Error inserting ephemeral note: $e');
        }
      }
    }
  }
}
