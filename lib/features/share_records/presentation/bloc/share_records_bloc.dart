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
import 'package:health_wallet/features/share_records/domain/services/receive_mode_service.dart';
import 'package:health_wallet/features/share_records/data/service/share_preferences_service.dart';
import 'package:health_wallet/features/share_records/data/service/share_records_service.dart';
import 'package:health_wallet/features/share_records/domain/entity/entity.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_event.dart';
import 'package:health_wallet/features/share_records/presentation/bloc/share_records_state.dart';

part 'handlers/share_records_transfer_handler.dart';
part 'handlers/share_records_session_handler.dart';

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

    on<DiscoveryStarted>(handleDiscoveryStarted);
    on<SymmetricDiscoveryStarted>(handleSymmetricDiscoveryStarted);
    on<PeerDiscovered>(handlePeerDiscovered, transformer: sequential());
    on<PeerSelected>(handlePeerSelected);

    on<TransferStarted>(handleTransferStarted);
    on<TransferProgressUpdated>(handleTransferProgressUpdated,
        transformer: droppable());
    on<TransferCompleted>(handleTransferCompleted);
    on<TransferFailed>(handleTransferFailed);
    on<TransferCancelled>(handleTransferCancelled);
    on<ConnectionRetried>(handleConnectionRetried);

    on<InvitationReceived>(handleInvitationReceived);
    on<InvitationAccepted>(handleInvitationAccepted);
    on<InvitationRejected>(handleInvitationRejected);
    on<DataReceived>(handleDataReceived);
    on<FilesReceived>(handleFilesReceived);
    on<EphemeralDataParsed>(handleEphemeralDataParsed);

    on<SessionEndRequested>(handleSessionEndRequested);
    on<ContinueViewing>(handleContinueViewing);
    on<AppBackgrounded>(handleAppBackgrounded);
    on<NavigationExitDetected>(handleNavigationExitDetected);
    on<DataDestructionConfirmed>(handleDataDestructionConfirmed);
    on<DataDestroyed>(handleDataDestroyed);
    on<TimerTicked>(handleTimerTicked, transformer: droppable());

    on<KillSessionRequested>(handleKillSessionRequested);
    on<RemoteSessionKilled>(handleRemoteSessionKilled);
    on<ReceiverInitializedWithInvitation>(
        handleReceiverInitializedWithInvitation);
    on<ReceiverInitializedWithData>(handleReceiverInitializedWithData);

    on<SessionExtendRequested>(handleSessionExtendRequested);
    on<RemoteExtendRequest>(handleRemoteExtendRequest);
    on<ExtendAccepted>(handleExtendAccepted);
    on<ExtendRejected>(handleExtendRejected);
    on<RemoteExtendAccepted>(handleRemoteExtendAccepted);
    on<RemoteExtendRejected>(handleRemoteExtendRejected);
    on<ViewingStartedReceived>(handleViewingStartedReceived);
    on<RemoteInvitationRejected>(handleRemoteInvitationRejected);
    on<ShareFiltersApplied>(_onFiltersApplied);
    on<WifiToggleRequested>(_onWifiToggleRequested);
    on<ConnectionHealthUpdated>(_onConnectionHealthUpdated);
  }

  Future<void> _onInitialized(
    ShareRecordsInitialized event,
    Emitter<ShareRecordsState> emit,
  ) async {
    WidgetsBinding.instance.addObserver(this);

    final receiveModeManager = getIt<ReceiveModeService>();
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

    final defaultDuration =
        await _preferencesService.getDefaultViewingDuration();
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
      statusMessage:
          'WiFi Direct unresponsive. Toggle WiFi off/on, then tap Retry.',
    ));
  }

  void _onConnectionHealthUpdated(
    ConnectionHealthUpdated event,
    Emitter<ShareRecordsState> emit,
  ) {
    final status = event.health['status'] as String? ?? 'unknown';
    emit(state.copyWith(connectionHealthStatus: status));
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
        case TransferStatus.completed:
        case TransferStatus.batchCompleted:
          add(const ShareRecordsEvent.transferCompleted());
        case TransferStatus.failed:
          add(const ShareRecordsEvent.transferFailed('Transfer failed'));
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
          debugPrint(
              '[SHARE] Session ended before receiver started viewing - treating as rejection');
          add(const ShareRecordsEvent.remoteInvitationRejected());
        } else {
          add(const ShareRecordsEvent.remoteSessionKilled());
        }
      }
    });
    _extendRequestSub =
        _service.sessionExtendRequestStream.listen((duration) {
      if (_isClosed) return;
      add(ShareRecordsEvent.remoteExtendRequest(duration));
    });
    _extendAcceptedSub =
        _service.sessionExtendAcceptedStream.listen((duration) {
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
    _invitationRejectedSub =
        _service.invitationRejectedStream.listen((_) {
      if (_isClosed) return;
      add(const ShareRecordsEvent.remoteInvitationRejected());
    });
    _wifiToggleNeededSub = _service.wifiToggleNeededStream.listen((_) {
      if (_isClosed) return;
      add(const ShareRecordsEvent.wifiToggleRequested());
    });
    _connectionHealthSub =
        _service.connectionHealthStream.listen((health) {
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
        debugPrint(
            '[SHARE] Fallback: no viewingStarted after 60s, starting timer from now');
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
    final manager = getIt<ReceiveModeService>();
    if (manager.isListening) {
      await manager.resumeListening();
    }
    return super.close();
  }
}
