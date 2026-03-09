import 'dart:async';
import 'dart:io';

import 'package:airdrop/airdrop.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:health_wallet/core/di/injection.dart';
import 'package:health_wallet/features/records/domain/entity/entity.dart';
import 'package:health_wallet/features/records/domain/entity/record_note/record_note.dart';
import 'package:health_wallet/features/records/domain/repository/records_repository.dart';
import 'package:health_wallet/features/share_records/core/ephemeral_session_manager.dart';
import 'package:health_wallet/features/share_records/core/share_permissions_helper.dart';
import 'package:health_wallet/features/share_records/data/service/receive_mode_manager.dart';
import 'package:health_wallet/features/share_records/data/service/share_preferences_service.dart';
import 'package:health_wallet/features/share_records/data/service/share_records_service.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';

@injectable
class ShareRecordsBloc extends Bloc<ShareRecordsEvent, ShareRecordsState>
    with WidgetsBindingObserver {
  final ShareRecordsService _service;
  final RecordsRepository _recordsRepository;
  final SharePreferencesService _preferencesService;

  StreamSubscription<TransferProgress>? _progressSub;
  StreamSubscription<TransferStatus>? _statusSub;
  StreamSubscription<Map<String, dynamic>>? _peerDiscoverySub;
  StreamSubscription<Map<String, dynamic>>? _invitationSub;
  StreamSubscription<ReceivedData>? _receivedDataSub;
  StreamSubscription<List<String>>? _receivedFilesSub;
  StreamSubscription<void>? _killSignalSub;
  StreamSubscription<void>? _sessionEndedSub;
  StreamSubscription<int>? _extendRequestSub;
  StreamSubscription<int>? _extendAcceptedSub;
  StreamSubscription<void>? _extendRejectedSub;
  StreamSubscription<void>? _viewingStartedSub;
  StreamSubscription<void>? _invitationRejectedSub;
  StreamSubscription<void>? _wifiToggleNeededSub;
  StreamSubscription<Map<String, dynamic>>? _connectionHealthSub;

  Timer? _viewingTimer;
  Timer? _monitoringFallbackTimer;

  String? _tempFilePath;
  String _deviceName = 'HealthWallet Device';
  final List<int> _insertedEphemeralNoteIds = [];

  bool _isClosed = false;
  bool _pendingViewingStarted = false;

  ShareRecordsBloc(
    this._service,
    this._recordsRepository,
    this._preferencesService,
  ) : super(ShareRecordsState.initial()) {
    on<ShareRecordsInitialized>(_onInitialized);
    on<ShareRecordsDisposed>(_onDisposed);

    on<SendModeSelected>(_onSendModeSelected);
    on<ReceiveModeSelected>(_onReceiveModeSelected);
    on<ModeCleared>(_onModeCleared);

    on<RecordToggled>(_onRecordToggled);
    on<AllRecordsSelected>(_onAllRecordsSelected);
    on<AllRecordsDeselected>(_onAllRecordsDeselected);
    on<SelectionConfirmed>(_onSelectionConfirmed);
    on<ViewingDurationChanged>(_onViewingDurationChanged);
    on<DefaultViewingDurationSet>(_onDefaultViewingDurationSet);

    on<DiscoveryStarted>(_onDiscoveryStarted);
    on<SymmetricDiscoveryStarted>(_onSymmetricDiscoveryStarted);
    on<PeerDiscovered>(_onPeerDiscovered, transformer: sequential());
    on<PeerSelected>(_onPeerSelected);

    on<TransferStarted>(_onTransferStarted);
    on<TransferProgressUpdated>(_onTransferProgressUpdated, transformer: droppable());
    on<TransferCompleted>(_onTransferCompleted);
    on<TransferFailed>(_onTransferFailed);
    on<TransferCancelled>(_onTransferCancelled);
    on<ConnectionRetried>(_onConnectionRetried);

    on<InvitationReceived>(_onInvitationReceived);
    on<InvitationAccepted>(_onInvitationAccepted);
    on<InvitationRejected>(_onInvitationRejected);
    on<DataReceived>(_onDataReceived);
    on<FilesReceived>(_onFilesReceived);
    on<EphemeralDataParsed>(_onEphemeralDataParsed);

    on<SessionEndRequested>(_onSessionEndRequested);
    on<ContinueViewing>(_onContinueViewing);
    on<AppBackgrounded>(_onAppBackgrounded);
    on<NavigationExitDetected>(_onNavigationExitDetected);
    on<DataDestructionConfirmed>(_onDataDestructionConfirmed);
    on<DataDestroyed>(_onDataDestroyed);
    on<TimerTicked>(_onTimerTicked, transformer: droppable());

    on<KillSessionRequested>(_onKillSessionRequested);
    on<RemoteSessionKilled>(_onRemoteSessionKilled);
    on<ReceiverInitializedWithInvitation>(_onReceiverInitializedWithInvitation);
    on<ReceiverInitializedWithData>(_onReceiverInitializedWithData);

    on<SessionExtendRequested>(_onSessionExtendRequested);
    on<RemoteExtendRequest>(_onRemoteExtendRequest);
    on<ExtendAccepted>(_onExtendAccepted);
    on<ExtendRejected>(_onExtendRejected);
    on<RemoteExtendAccepted>(_onRemoteExtendAccepted);
    on<RemoteExtendRejected>(_onRemoteExtendRejected);
    on<ViewingStartedReceived>(_onViewingStartedReceived);
    on<RemoteInvitationRejected>(_onRemoteInvitationRejected);
    on<ShareFiltersApplied>(_onFiltersApplied);
    on<WifiToggleRequested>(_onWifiToggleRequested);
    on<ConnectionHealthUpdated>(_onConnectionHealthUpdated);
  }

  Future<void> _onInitialized(
    ShareRecordsInitialized event,
    Emitter<ShareRecordsState> emit,
  ) async {
    WidgetsBinding.instance.addObserver(this);

    final receiveModeManager = getIt<ReceiveModeManager>();
    _subscribeToStreams(
      skipInvitationStream: receiveModeManager.isListening,
    );

    EphemeralSessionManager.instance.initialize(
      onSessionDestroyed: (sessionId) {
        if (_isClosed) return;
        add(const ShareRecordsEvent.dataDestroyed());
      },
    );

    await _initDeviceName();

    final defaultDuration = await _preferencesService.getDefaultViewingDuration();
    emit(state.copyWith(
      defaultViewingDuration: defaultDuration,
      selectedViewingDuration: defaultDuration,
      statusMessage: 'Ready to share',
    ));
  }

  Future<void> _onDisposed(
    ShareRecordsDisposed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    WidgetsBinding.instance.removeObserver(this);

    await _cancelSubscriptions();

    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();

    EphemeralSessionManager.instance.destroySession(reason: 'bloc_disposed');

    await _service.disconnect();
  }

  Future<void> _onSendModeSelected(
    SendModeSelected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    emit(state.copyWith(
      mode: ShareMode.sending,
      phase: SharePhase.selectingRecords,
      isSessionActive: false,
      statusMessage: 'Select records to share',
    ));

    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();
    await _service.disconnect();
  }

  Future<void> _onReceiveModeSelected(
    ReceiveModeSelected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final result = await SharePermissionsHelper.requestSharePermissions();

    switch (result) {
      case PermissionGranted():
        emit(state.copyWith(
          mode: ShareMode.receiving,
          phase: SharePhase.discoveringPeers,
          statusMessage: 'Waiting for sender...',
        ));
        await _service.disconnect();
        await _service.startReceivingInMemory();

      case PermissionDenied(:final message):
        emit(state.copyWith(
          errorMessage: message,
          statusMessage: 'Permissions required',
        ));

      case PermissionPermanentlyDenied(:final message):
        emit(state.copyWith(
          errorMessage: message,
          showSettingsDialog: true,
          statusMessage: 'Please enable permissions in Settings',
        ));
    }
  }

  Future<void> _onModeCleared(
    ModeCleared event,
    Emitter<ShareRecordsState> emit,
  ) async {
    await _service.disconnect();

    emit(ShareRecordsState.initial());
  }

  void _onRecordToggled(
    RecordToggled event,
    Emitter<ShareRecordsState> emit,
  ) {
    final newSelection = state.selection.toggle(event.resource);
    emit(state.copyWith(selection: newSelection));
  }

  void _onAllRecordsSelected(
    AllRecordsSelected event,
    Emitter<ShareRecordsState> emit,
  ) {
    final newSelection = state.selection.addAll(event.resources);
    emit(state.copyWith(selection: newSelection));
  }

  void _onAllRecordsDeselected(
    AllRecordsDeselected event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(selection: const ShareSelection()));
  }

  void _onViewingDurationChanged(
    ViewingDurationChanged event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(selectedViewingDuration: event.duration));
  }

  Future<void> _onDefaultViewingDurationSet(
    DefaultViewingDurationSet event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final newDefaultDuration = state.selectedViewingDuration;
    await _preferencesService.setDefaultViewingDuration(newDefaultDuration);
    emit(state.copyWith(
      defaultViewingDuration: newDefaultDuration,
    ));
  }

  void _onSelectionConfirmed(
    SelectionConfirmed event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (state.selection.isEmpty) {
      emit(state.copyWith(errorMessage: 'Please select at least one record'));
      return;
    }

    emit(state.copyWith(
      phase: SharePhase.discoveringPeers,
      statusMessage: 'Looking for nearby devices...',
    ));

    add(const ShareRecordsEvent.symmetricDiscoveryStarted());
  }

  Future<void> _onDiscoveryStarted(
    DiscoveryStarted event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final result = await SharePermissionsHelper.requestSharePermissions();

    switch (result) {
      case PermissionGranted():
        final manager = getIt<ReceiveModeManager>();
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

  Future<void> _onSymmetricDiscoveryStarted(
    SymmetricDiscoveryStarted event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final result = await SharePermissionsHelper.requestSharePermissions();

    switch (result) {
      case PermissionGranted():
        final manager = getIt<ReceiveModeManager>();
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

  void _onPeerDiscovered(
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
          (p) => !_isUnknownName(p.deviceName) && _namesMatch(p.deviceName!, newName!),
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

  void _onFiltersApplied(
    ShareFiltersApplied event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(appliedFilters: event.filters));
  }

  void _onWifiToggleRequested(
    WifiToggleRequested event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(
      wifiToggleNeeded: true,
      statusMessage: 'WiFi Direct unresponsive. Toggle WiFi off/on, then tap Retry.',
    ));
  }

  void _onConnectionHealthUpdated(
    ConnectionHealthUpdated event,
    Emitter<ShareRecordsState> emit,
  ) {
    final status = event.health['status'] as String? ?? 'unknown';
    emit(state.copyWith(
      connectionHealthStatus: status,
    ));
  }

  Future<void> _onPeerSelected(
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

      final selectedRecords = state.selection.selectedRecords.values.toList();
      final enrichedRecords = await _enrichSelectionWithRelatedResources(selectedRecords);

      debugPrint('[SHARE] User selected ${selectedRecords.length} records');
      debugPrint('[SHARE] Enriched to ${enrichedRecords.length} records (including related)');

      final notesMap = <String, List<RecordNote>>{};
      for (final resource in enrichedRecords) {
        try {
          final notes = await _recordsRepository.getRecordNotes(resource.id);
          if (notes.isNotEmpty) {
            notesMap[resource.id] = notes;
          }
        } catch (e) {
          debugPrint('[SHARE] Error fetching notes for ${resource.id}: $e');
        }
      }

      final payload = await _service.createPayload(
        resources: enrichedRecords,
        deviceName: _deviceName,
        expiresInSeconds: state.selectedViewingDuration.inSeconds,
        notesMap: notesMap,
        activeFilters: state.appliedFilters.map((f) => f.name).toList(),
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
          relatedResources = await _recordsRepository.getRelatedResourcesForEncounter(
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
        debugPrint('[SHARE] Error fetching related resources for ${record.id}: $e');
      }
    }

    return enrichedResources.values.toList();
  }

  void _onTransferStarted(
    TransferStarted event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(
      phase: SharePhase.transferring,
      statusMessage: 'Sending records...',
      isSessionActive: true,
    ));
  }

  void _onTransferProgressUpdated(
    TransferProgressUpdated event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(
      transferProgress: event.progress,
      statusMessage: 'Transferring ${(state.progressPercentage * 100).toInt()}%',
    ));
  }

  void _onTransferCompleted(
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
          statusMessage: 'Receiver is viewing records - monitoring session',
        ));
        _startViewingTimer();
      } else {
        debugPrint('[SHARE] Files sent - staying on connecting until receiver accepts');
        emit(state.copyWith(
          phase: SharePhase.connecting,
          isSessionActive: true,
          statusMessage: 'Records sent - waiting for receiver to accept',
        ));
        _startMonitoringFallbackTimer();
      }
    } else {
      debugPrint('[SHARE] Transfer completed for receiver - waiting for data to be parsed');
    }
  }

  Future<void> _onTransferFailed(
    TransferFailed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    if (state.phase == SharePhase.selectingRecords ||
        state.phase == SharePhase.sessionEnded) {
      return;
    }

    // Auto-retry for connection-related failures
    final isConnectionPhase = state.phase == SharePhase.connecting ||
        state.phase == SharePhase.transferring;
    if (isConnectionPhase && state.connectionRetryCount < 3 && !state.wifiToggleNeeded) {
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

  Future<void> _onTransferCancelled(
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

  Future<void> _onConnectionRetried(
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

  void _onInvitationReceived(
    InvitationReceived event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(
      pendingInvitationId: event.invitationId,
      pendingInvitationDeviceName: event.deviceName,
      statusMessage: '${event.deviceName} wants to share records',
    ));
  }

  Future<void> _onInvitationAccepted(
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

  Future<void> _onInvitationRejected(
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

  Future<void> _onDataReceived(
    DataReceived event,
    Emitter<ShareRecordsState> emit,
  ) async {
    debugPrint('[SHARE] onDataReceived: ${event.data.fileName} (${event.data.size} bytes), phase=${state.phase}');
    final container = await _service.parseReceivedData(event.data);

    if (container != null) {
      debugPrint('[SHARE] parseReceivedData succeeded: ${container.recordCount} records');
      add(ShareRecordsEvent.ephemeralDataParsed(container));
    } else {
      debugPrint('[SHARE] parseReceivedData returned null!');
      emit(state.copyWith(
        phase: SharePhase.error,
        errorMessage: 'Failed to parse received data',
      ));
    }
  }

  Future<void> _onFilesReceived(
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

  Future<void> _onEphemeralDataParsed(
    EphemeralDataParsed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    EphemeralSessionManager.instance.startSession(event.container);


    emit(state.copyWith(
      phase: SharePhase.viewingRecords,
      receivedData: event.container,
      viewingTimeRemaining: event.container.viewDuration,
      isSessionActive: true,
      statusMessage: 'Viewing ${event.container.recordCount} records from ${event.container.senderDeviceName}',
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

  Future<void> _insertEphemeralNotes(EphemeralRecordsContainer container) async {
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

  void _onSessionEndRequested(
    SessionEndRequested event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(
      showExitConfirmationDialog: true,
      statusMessage: 'Are you sure you want to exit? Data will be deleted.',
    ));
  }

  void _onContinueViewing(
    ContinueViewing event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(
      showExitConfirmationDialog: false,
      statusMessage: 'Viewing ${state.receivedData?.recordCount ?? 0} records',
    ));
  }

  void _onAppBackgrounded(
    AppBackgrounded event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (state.receivedData != null) {
      add(const ShareRecordsEvent.dataDestructionConfirmed());
    }
  }

  void _onNavigationExitDetected(
    NavigationExitDetected event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (state.receivedData != null) {
      emit(state.copyWith(showExitConfirmationDialog: true));
    }
  }

  Future<void> _onDataDestructionConfirmed(
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

  Future<void> _onDataDestroyed(
    DataDestroyed event,
    Emitter<ShareRecordsState> emit,
  ) async {
    await _cleanupEphemeralData();

    emit(state.copyWith(
      phase: SharePhase.sessionEnded,
      receivedData: null,
      viewingTimeRemaining: null,
      isSessionActive: false,
      isDataDestroyed: true,
      statusMessage: 'Data has been securely deleted',
    ));
  }

  Future<void> _cleanupEphemeralData() async {
    final receivedData = state.receivedData;
    if (receivedData != null) {
      for (final path in receivedData.tempAttachmentPaths) {
        try {
          await File(path).delete();
        } catch (_) {}
      }

      final sessionDir = File(receivedData.tempAttachmentPaths.isNotEmpty
          ? receivedData.tempAttachmentPaths.first
          : '')
          .parent;
      try {
        if (await sessionDir.exists()) {
          await sessionDir.delete(recursive: true);
        }
      } catch (_) {}
    }

    for (final noteId in _insertedEphemeralNoteIds) {
      try {
        await _recordsRepository.deleteRecordNote(
          RecordNote(id: noteId, timestamp: DateTime.now()),
        );
      } catch (_) {}
    }
    _insertedEphemeralNoteIds.clear();
  }

  void _onTimerTicked(
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
          emit(state.copyWith(
            phase: SharePhase.sessionEnded,
            isSessionActive: false,
            viewingTimeRemaining: Duration.zero,
            statusMessage: 'Session expired',
          ));
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

  Future<void> _onKillSessionRequested(
    KillSessionRequested event,
    Emitter<ShareRecordsState> emit,
  ) async {
    emit(state.copyWith(statusMessage: 'Terminating remote session...'));

    try {
      await _service.sendKillSignal();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('[ERROR:❌] Kill signal failed: $e');
    }

    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();

    await _service.disconnect();

    emit(state.copyWith(
      phase: SharePhase.sessionEnded,
      isSessionActive: false,
      statusMessage: 'Session terminated',
    ));
  }

  Future<void> _onRemoteSessionKilled(
    RemoteSessionKilled event,
    Emitter<ShareRecordsState> emit,
  ) async {
    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();

    await _service.disconnect();

    emit(state.copyWith(
      phase: SharePhase.sessionEnded,
      isSessionActive: false,
      statusMessage: 'Remote session terminated',
    ));
  }

  Future<void> _onSessionExtendRequested(
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

  void _onRemoteExtendRequest(
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
      emit(state.copyWith(
        pendingExtendDurationSeconds: event.durationSeconds,
      ));
    }
  }

  Future<void> _onExtendAccepted(
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

    emit(state.copyWith(
      extensionsUsed: state.extensionsUsed + 1,
      pendingExtendDurationSeconds: null,
      viewingTimeRemaining: newRemaining,
      selectedViewingDuration: state.selectedViewingDuration + duration,
    ));
  }

  Future<void> _onExtendRejected(
    ExtendRejected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    try {
      await _service.sendExtendRejected();
    } catch (e) {
      debugPrint('[SHARE] Failed to send extend rejected: $e');
    }

    emit(state.copyWith(
      pendingExtendDurationSeconds: null,
    ));
  }

  void _onRemoteExtendAccepted(
    RemoteExtendAccepted event,
    Emitter<ShareRecordsState> emit,
  ) {
    final duration = Duration(seconds: event.durationSeconds);
    EphemeralSessionManager.instance.extendSession(duration);

    final newRemaining = state.viewingTimeRemaining != null
        ? state.viewingTimeRemaining! + duration
        : duration;

    emit(state.copyWith(
      extensionsUsed: state.extensionsUsed + 1,
      extensionRequestPending: false,
      viewingTimeRemaining: newRemaining,
      selectedViewingDuration: state.selectedViewingDuration + duration,
    ));
  }

  void _onRemoteExtendRejected(
    RemoteExtendRejected event,
    Emitter<ShareRecordsState> emit,
  ) {
    emit(state.copyWith(
      extensionRequestPending: false,
      statusMessage: 'Extension request was declined',
    ));
  }

  void _onViewingStartedReceived(
    ViewingStartedReceived event,
    Emitter<ShareRecordsState> emit,
  ) {
    if (!state.isSending) return;

    if (state.sessionStartedAt != null) {
      debugPrint('[SHARE] viewingStarted already processed, ignoring duplicate');
      return;
    }

    if (state.phase == SharePhase.connecting ||
        state.phase == SharePhase.monitoringSession) {
      _monitoringFallbackTimer?.cancel();
      _monitoringFallbackTimer = null;

      debugPrint('[SHARE] Receiver started viewing - beginning countdown timer');
      emit(state.copyWith(
        phase: SharePhase.monitoringSession,
        sessionStartedAt: DateTime.now(),
        viewingTimeRemaining: state.selectedViewingDuration,
        statusMessage: 'Receiver is viewing records - monitoring session',
      ));
      _startViewingTimer();
      return;
    }

    if (state.phase != SharePhase.monitoringSession) {
      debugPrint('[SHARE] viewingStarted arrived early (phase=${state.phase}), buffering');
      _pendingViewingStarted = true;
      return;
    }
  }

  Future<void> _onRemoteInvitationRejected(
    RemoteInvitationRejected event,
    Emitter<ShareRecordsState> emit,
  ) async {
    if (!state.isSending) {
      return;
    }

    debugPrint('[SHARE] Receiver declined the invitation');

    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();

    emit(state.copyWith(
      phase: SharePhase.sessionEnded,
      isSessionActive: false,
      statusMessage: 'Receiver declined invitation',
    ));

    await _service.disconnect();
  }

  Future<void> _onReceiverInitializedWithInvitation(
    ReceiverInitializedWithInvitation event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final manager = getIt<ReceiveModeManager>();
    manager.clearPendingInvitation();
    manager.pauseListening();

    final pendingData = manager.pendingReceivedData;
    if (pendingData != null) {
      manager.clearPendingReceivedData();
      EphemeralSessionManager.instance.startSession(pendingData);
      emit(state.copyWith(
        mode: ShareMode.receiving,
        phase: SharePhase.viewingRecords,
        receivedData: pendingData,
        viewingTimeRemaining: pendingData.viewDuration,
        isSessionActive: true,
        statusMessage:
            'Viewing ${pendingData.recordCount} records from ${pendingData.senderDeviceName}',
      ));
      _startViewingTimer();
      return;
    }

    if (event.preAccepted) {
      emit(state.copyWith(
        mode: ShareMode.receiving,
        phase: SharePhase.connecting,
        statusMessage: 'Receiving records from ${event.deviceName}...',
      ));
      await _service.acceptInvitation(event.invitationId);
      return;
    }

    emit(state.copyWith(
      mode: ShareMode.receiving,
      phase: SharePhase.discoveringPeers,
      pendingInvitationId: event.invitationId,
      pendingInvitationDeviceName: event.deviceName,
      statusMessage: '${event.deviceName} wants to share records',
    ));
  }

  Future<void> _onReceiverInitializedWithData(
    ReceiverInitializedWithData event,
    Emitter<ShareRecordsState> emit,
  ) async {
    final manager = getIt<ReceiveModeManager>();
    final container = manager.pendingReceivedData;
    manager.clearPendingReceivedData();
    manager.clearPendingInvitation();
    manager.pauseListening();

    if (container == null) {
      emit(state.copyWith(
        phase: SharePhase.error,
        errorMessage: 'No data available',
      ));
      return;
    }

    EphemeralSessionManager.instance.startSession(container);

    emit(state.copyWith(
      mode: ShareMode.receiving,
      phase: SharePhase.viewingRecords,
      receivedData: container,
      viewingTimeRemaining: container.viewDuration,
      isSessionActive: true,
      statusMessage:
          'Viewing ${container.recordCount} records from ${container.senderDeviceName}',
    ));

    _startViewingTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      add(const ShareRecordsEvent.appBackgrounded());
    }
  }

  Future<void> _initDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceName = iosInfo.name;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceName = androidInfo.model;
      }
    } catch (_) {
      _deviceName = 'HealthWallet Device';
    }
  }

  void _subscribeToStreams({bool skipInvitationStream = false}) {
    _progressSub = _service.progressStream.listen((progress) {
      if (!_isClosed) {
        add(ShareRecordsEvent.transferProgressUpdated(progress));
      }
    });

    _statusSub = _service.statusStream.listen((status) {
      if (_isClosed) return;

      final isTransferRelatedPhase = state.phase == SharePhase.connecting ||
          state.phase == SharePhase.transferring;

      if (!isTransferRelatedPhase) return;

      switch (status) {
        case TransferStatus.transferring:
          if (state.phase == SharePhase.connecting) {
            add(const ShareRecordsEvent.transferStarted());
          }
          break;
        case TransferStatus.completed:
        case TransferStatus.batchCompleted:
          add(const ShareRecordsEvent.transferCompleted());
          break;
        case TransferStatus.failed:
          add(const ShareRecordsEvent.transferFailed('Transfer failed'));
          break;
        default:
          break;
      }
    });

    _peerDiscoverySub = _service.peerDiscoveryStream.listen((data) {
      if (_isClosed) return;
      final peer = PeerDevice(
        deviceId: data['deviceId'] as String,
        deviceName: data['deviceName'] as String? ?? 'Unknown Device',
        osType: data['osType'] as String?,
      );
      add(ShareRecordsEvent.peerDiscovered(peer));
    });

    if (!skipInvitationStream) {
      _invitationSub = _service.invitationStream.listen((data) {
        if (_isClosed) return;
        add(ShareRecordsEvent.invitationReceived(
          invitationId: data['invitationId'] as String,
          deviceName: data['deviceName'] as String? ?? 'Unknown Device',
        ));
      });
    }

    _receivedDataSub = _service.receivedDataStream.listen((data) {
      if (_isClosed) return;
      add(ShareRecordsEvent.dataReceived(data));
    });

    _receivedFilesSub = _service.receivedFilesStream.listen((filePaths) {
      if (_isClosed) return;
      add(ShareRecordsEvent.filesReceived(filePaths));
    });

    _killSignalSub = _service.killSignalStream.listen((_) {
      if (_isClosed) return;
      add(const ShareRecordsEvent.dataDestructionConfirmed());
    });

    _sessionEndedSub = _service.sessionEndedStream.listen((_) {
      if (_isClosed) return;
      if (state.isSending &&
          (state.phase == SharePhase.monitoringSession ||
              state.phase == SharePhase.connecting)) {
        _viewingTimer?.cancel();
        _monitoringFallbackTimer?.cancel();
        if (state.sessionStartedAt == null) {
          debugPrint('[SHARE] Session ended before receiver started viewing - treating as rejection');
          add(const ShareRecordsEvent.remoteInvitationRejected());
        } else {
          add(const ShareRecordsEvent.remoteSessionKilled());
        }
      }
    });

    _extendRequestSub = _service.sessionExtendRequestStream.listen((duration) {
      if (_isClosed) return;
      add(ShareRecordsEvent.remoteExtendRequest(duration));
    });

    _extendAcceptedSub = _service.sessionExtendAcceptedStream.listen((duration) {
      if (_isClosed) return;
      add(ShareRecordsEvent.remoteExtendAccepted(duration));
    });

    _extendRejectedSub = _service.sessionExtendRejectedStream.listen((_) {
      if (_isClosed) return;
      add(const ShareRecordsEvent.remoteExtendRejected());
    });

    _viewingStartedSub = _service.viewingStartedStream.listen((_) {
      if (_isClosed) return;
      add(const ShareRecordsEvent.viewingStartedReceived());
    });

    _invitationRejectedSub = _service.invitationRejectedStream.listen((_) {
      if (_isClosed) return;
      add(const ShareRecordsEvent.remoteInvitationRejected());
    });

    _wifiToggleNeededSub = _service.wifiToggleNeededStream.listen((_) {
      if (_isClosed) return;
      add(const ShareRecordsEvent.wifiToggleRequested());
    });

    _connectionHealthSub = _service.connectionHealthStream.listen((health) {
      if (_isClosed) return;
      add(ShareRecordsEvent.connectionHealthUpdated(health));
    });
  }

  Future<void> _cancelSubscriptions() async {
    await _progressSub?.cancel();
    await _statusSub?.cancel();
    await _peerDiscoverySub?.cancel();
    await _invitationSub?.cancel();
    await _receivedDataSub?.cancel();
    await _receivedFilesSub?.cancel();
    await _killSignalSub?.cancel();
    await _sessionEndedSub?.cancel();
    await _extendRequestSub?.cancel();
    await _extendAcceptedSub?.cancel();
    await _extendRejectedSub?.cancel();
    await _viewingStartedSub?.cancel();
    await _invitationRejectedSub?.cancel();
    await _wifiToggleNeededSub?.cancel();
    await _connectionHealthSub?.cancel();
  }

  void _startViewingTimer() {
    _viewingTimer?.cancel();
    _viewingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isClosed) {
        add(const ShareRecordsEvent.timerTicked());
      }
    });
  }

  void _startMonitoringFallbackTimer() {
    _monitoringFallbackTimer?.cancel();
    _monitoringFallbackTimer = Timer(const Duration(seconds: 60), () {
      if (_isClosed) return;
      if (state.isSending &&
          (state.phase == SharePhase.monitoringSession ||
              state.phase == SharePhase.connecting) &&
          state.sessionStartedAt == null) {
        debugPrint('[SHARE] Fallback: no viewingStarted after 60s, starting timer from now');
        add(const ShareRecordsEvent.viewingStartedReceived());
      }
    });
  }

  @override
  Future<void> close() async {
    _isClosed = true;

    _viewingTimer?.cancel();
    _monitoringFallbackTimer?.cancel();

    await _cancelSubscriptions();

    WidgetsBinding.instance.removeObserver(this);


    await _service.disconnect();

    final manager = getIt<ReceiveModeManager>();
    if (manager.isListening) {
      await manager.resumeListening();
    }

    return super.close();
  }
}
