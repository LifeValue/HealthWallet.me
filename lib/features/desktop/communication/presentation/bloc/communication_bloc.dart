import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/mpc_transport.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/transport_selector.dart';

part 'communication_bloc.freezed.dart';
part 'communication_event.dart';
part 'communication_state.dart';

/// The phone ↔ desktop link as the app sees it: pairing, finding the other
/// device, reconnecting, and on the desktop accepting a phone.
class CommunicationBloc extends Bloc<CommunicationEvent, DesktopSyncState> {
  final AppPlatform _platform;
  final PairingStorageService _pairingStorage;
  final TcpService _tcpService;
  final DiscoveryService _discoveryService;

  /// Runs on the desktop when a phone is (re)connected, e.g. to resend
  /// backup status and handover results.
  final void Function()? onPhoneConnected;

  final _subscriptions = <StreamSubscription>[];
  CommunicationService? _mpcTransport;
  Timer? _reconnectTimer;
  Timer? _networkTimer;
  Timer? _vpnRecheckTimer;
  final Future<List<NetworkInterface>> Function() _listInterfaces;

  @visibleForTesting
  static Duration initialReconnectDelay = const Duration(seconds: 3);
  static const _maxReconnectAttempts = 5;

  /// The longest one connection attempt may take, every address and MPC
  /// included. A step that never returns (a lookup, a platform call) then
  /// ends it like a desktop not found, instead of leaving the phone
  /// connecting until the app restarts.
  @visibleForTesting
  static Duration connectionAttemptTimeout = const Duration(seconds: 60);

  /// Counts connection attempts; an attempt that is no longer the current
  /// one (given up, replaced by a new pairing, or the bloc closed) tries
  /// nothing more.
  int _attempt = 0;

  /// Completed when a new QR code is scanned, so the running attempt ends at
  /// once instead of when the step it waits on returns.
  Completer<void> _attemptReplaced = Completer<void>();
  static const _networkCheckInterval = Duration(seconds: 30);
  int _reconnectAttempts = 0;

  /// Set by a manual disconnect on either side, so the phone doesn't
  /// reconnect by itself; a resume or the Reconnect button clears it.
  bool _stayDisconnected = false;

  /// On the desktop the VPN check runs every [vpnRecheckInterval], so the
  /// notice follows a VPN turned on or off within seconds, connected or not.
  CommunicationBloc(
    this._platform,
    this._pairingStorage,
    this._tcpService,
    this._discoveryService, {
    CommunicationService? mpcTransport,
    bool? mpcAvailable,
    this.onPhoneConnected,
    Duration vpnRecheckInterval = const Duration(seconds: 5),
    Future<List<NetworkInterface>> Function()? listInterfaces,
  }) : _listInterfaces = listInterfaces ?? TcpService.ipv4Interfaces,
       super(DesktopSyncState.initial()) {
    on<CommunicationInitialised>(_onInitialised, transformer: droppable());
    on<CommunicationPairingRequested>(
      _onPairingRequested,
      transformer: sequential(),
    );
    on<CommunicationPairingCompleted>(
      _onPairingCompleted,
      transformer: sequential(),
    );
    on<CommunicationConnectionRequested>(
      _onConnectionRequested,
      transformer: droppable(),
    );
    on<CommunicationLinkStateChanged>(
      _onLinkStateChanged,
      transformer: sequential(),
    );
    on<CommunicationManualDisconnect>(
      _onManualDisconnect,
      transformer: sequential(),
    );
    on<CommunicationApprovalRequested>(
      _onApprovalRequested,
      transformer: sequential(),
    );
    on<CommunicationApprovalAnswered>(
      _onApprovalAnswered,
      transformer: sequential(),
    );
    on<CommunicationPeerApproved>(_onPeerApproved, transformer: sequential());
    on<CommunicationPairingMessage>(
      _onPairingMessage,
      transformer: sequential(),
    );
    on<CommunicationServerFailure>(
      _onServerFailure,
      transformer: sequential(),
    );
    on<CommunicationMpcEnded>(_onMpcEnded, transformer: droppable());
    on<CommunicationNetworkChecked>(
      _onNetworkChecked,
      transformer: droppable(),
    );
    on<CommunicationVpnChecked>(_onVpnChecked, transformer: droppable());

    _mpcTransport =
        mpcTransport ??
        ((mpcAvailable ?? TransportSelector.isMpcAvailable())
            ? MpcTransport()
            : null);
    _tcpService.attachMpc(_mpcTransport, asServer: _platform.isDesktop);

    _subscriptions
      ..add(
        _tcpService.connectionState.listen(
          (s) => add(CommunicationLinkStateChanged(state: s)),
        ),
      )
      ..add(
        _tcpService.approvalRequests.listen(
          (r) => add(CommunicationApprovalRequested(request: r)),
        ),
      )
      ..add(
        _tcpService.peerApproved.listen(
          (peer) => add(CommunicationPeerApproved(peer: peer)),
        ),
      )
      ..add(
        _tcpService.serverFailures.listen(
          (f) => add(CommunicationServerFailure(failure: f)),
        ),
      )
      ..add(
        _tcpService.messages.listen((message) {
          try {
            final json = jsonDecodeMessage(message);
            final type = json?['type'];
            if (type is String && type.startsWith('pairing.')) {
              add(
                CommunicationPairingMessage(
                  type: type,
                  payload:
                      json!['payload'] as Map<String, dynamic>? ?? const {},
                ),
              );
            }
          } catch (e) {
            logger.w('[Communication] unreadable message', e);
          }
        }),
      );

    if (_platform.isDesktop) {
      _vpnRecheckTimer = Timer.periodic(
        vpnRecheckInterval,
        (_) => add(const CommunicationVpnChecked()),
      );
    }

    final mpc = _mpcTransport;
    if (mpc != null && _platform.isDesktop) {
      _subscriptions.add(
        mpc.stateStream.listen((s) {
          if (s == CommunicationState.disconnected) {
            add(const CommunicationMpcEnded());
          }
        }),
      );
    }
  }

  static Map<String, dynamic>? jsonDecodeMessage(TcpMessage message) {
    final decoded = jsonDecode(message.payloadString);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  // ---------------------------------------------------------------------------
  // Start-up and pairing

  Future<void> _onInitialised(
    CommunicationInitialised event,
    Emitter<DesktopSyncState> emit,
  ) async {
    final pairing = await _pairingStorage.load();

    if (_platform.isDesktop) {
      final pairingToUse = pairing ?? await _newDesktopPairing();
      emit(state.copyWith(pairedDevice: pairingToUse));
      await _startDesktopServer(emit, pairingToUse);
      _networkTimer?.cancel();
      _networkTimer = Timer.periodic(
        _networkCheckInterval,
        (_) => add(const CommunicationNetworkChecked()),
      );
      return;
    }

    if (pairing == null) return;
    emit(state.copyWith(pairedDevice: pairing));
    add(const CommunicationConnectionRequested());
  }

  Future<DevicePairing> _newDesktopPairing() async {
    final (:ip, :vpnDetected) = await TcpService.localAddress(
      await _listInterfaces(),
    );
    var hostname = Platform.localHostname;
    if (hostname.endsWith('.local')) {
      hostname = hostname.substring(0, hostname.length - 6);
    }
    final pairing = DevicePairing.generate(
      deviceName: hostname.replaceAll('-', ' '),
      localIp: ip ?? '',
      os: Platform.operatingSystem,
    );
    await _pairingStorage.savePairing(pairing);
    return pairing;
  }

  /// Desktop: a fresh pairing, which the phone must scan. The old phone can
  /// no longer connect.
  Future<void> _onPairingRequested(
    CommunicationPairingRequested event,
    Emitter<DesktopSyncState> emit,
  ) async {
    if (!_platform.isDesktop) return;
    await _tcpService.disconnect();
    final pairing = await _newDesktopPairing();
    emit(
      state.copyWith(
        pairedDevice: pairing,
        connectedDeviceName: null,
        pendingApprovalName: null,
        outdatedPhoneSeen: false,
      ),
    );
    await _startDesktopServer(emit, pairing);
  }

  Future<void> _startDesktopServer(
    Emitter<DesktopSyncState> emit,
    DevicePairing pairing,
  ) async {
    final (:ip, :vpnDetected) = await TcpService.localAddress(
      await _listInterfaces(),
    );
    final int port;
    try {
      port = await _tcpService.startServer(
        pairingKeys: pairing.acceptedKeys,
        deviceId: pairing.deviceId,
        deviceName: pairing.deviceName,
        pairedPeerId: pairing.peerDeviceId,
        port: pairing.lastPort,
      );
    } catch (e) {
      logger.e('[Communication] the server did not start', e);
      emit(state.copyWith(networkUnavailable: true));
      return;
    }

    var updated = pairing.copyWith(lastIp: ip ?? '', lastPort: port);
    if (updated != pairing) {
      await _pairingStorage.savePairing(updated);
    } else {
      updated = pairing;
    }
    emit(
      state.copyWith(
        pairedDevice: updated,
        vpnDetected: vpnDetected,
        networkUnavailable: ip == null,
      ),
    );
    await _advertise(updated);
  }

  Future<void> _advertise(DevicePairing pairing) async {
    final ip = pairing.lastIp.isEmpty ? null : pairing.lastIp;
    final token = discoveryToken(pairing.pairingKey, pairing.deviceId);
    await _discoveryService.startDesktopAdvertising(
      ip: ip,
      port: pairing.lastPort,
      deviceId: pairing.deviceId,
      token: token,
    );
    await _mpcTransport?.startServer(port: pairing.lastPort, token: token);
  }

  /// Desktop: the address may change (another network, a new lease). The
  /// server listens on every interface; what changes is what the QR code
  /// and the advertisements say.
  Future<void> _onNetworkChecked(
    CommunicationNetworkChecked event,
    Emitter<DesktopSyncState> emit,
  ) async {
    final pairing = state.pairedDevice;
    if (pairing == null) return;
    final (:ip, :vpnDetected) = await TcpService.localAddress(
      await _listInterfaces(),
    );
    final address = ip ?? '';
    if (address == pairing.lastIp && state.networkUnavailable == (ip == null)) {
      return;
    }
    final updated = pairing.copyWith(lastIp: address);
    await _pairingStorage.savePairing(updated);
    emit(
      state.copyWith(
        pairedDevice: updated,
        vpnDetected: vpnDetected,
        networkUnavailable: ip == null,
      ),
    );
    if (ip != null) {
      await _discoveryService.startDesktopAdvertising(
        ip: ip,
        port: updated.lastPort,
        deviceId: updated.deviceId,
        token: discoveryToken(updated.pairingKey, updated.deviceId),
      );
    }
  }

  Future<void> _onVpnChecked(
    CommunicationVpnChecked event,
    Emitter<DesktopSyncState> emit,
  ) async {
    if (!_platform.isDesktop) return;

    try {
      final (ip: _, :vpnDetected) = await TcpService.localAddress(
        await _listInterfaces(),
      );
      emit(state.copyWith(vpnDetected: vpnDetected));
    } on SocketException catch (e) {
      debugPrint('[Communication] VPN check failed: $e');
    }
  }

  /// Phone: a desktop's QR code was scanned.
  Future<void> _onPairingCompleted(
    CommunicationPairingCompleted event,
    Emitter<DesktopSyncState> emit,
  ) async {
    final previous = state.pairedDevice;
    final changed =
        previous == null ||
        previous.deviceId != event.pairing.deviceId ||
        previous.pairingKey != event.pairing.pairingKey;
    if (changed) {
      // A running attempt uses the old key: it ends now, tries nothing more
      // and reports nothing.
      _attempt++;
      if (!_attemptReplaced.isCompleted) _attemptReplaced.complete();
      _reconnectTimer?.cancel();
      // Still on the old desktop otherwise, until that link drops.
      await _tcpService.disconnect();
      await _mpcTransport?.disconnect();
    }
    await _pairingStorage.savePairing(event.pairing);
    _reconnectAttempts = 0;
    _stayDisconnected = false;
    emit(state.copyWith(pairedDevice: event.pairing, issue: null));
    if (_platform.isDesktop) return;
    // Added once the microtasks that end the replaced attempt's handler have
    // run; while that handler runs, droppable() would drop the request.
    Timer.run(() {
      if (!isClosed) add(const CommunicationConnectionRequested());
    });
  }

  // ---------------------------------------------------------------------------
  // Connecting (phone)

  Future<void> _onConnectionRequested(
    CommunicationConnectionRequested event,
    Emitter<DesktopSyncState> emit,
  ) async {
    final pairing = state.pairedDevice;
    if (pairing == null || _platform.isDesktop) return;
    if (_tcpService.isConnected ||
        _tcpService.currentState == ConnectionState.awaitingApproval) {
      return;
    }
    _reconnectTimer?.cancel();
    _stayDisconnected = false;
    emit(
      state.copyWith(
        connectionStatus: ConnectionStatus.discovering,
        connectionTransport: ConnectionTransport.unknown,
        issue: null,
      ),
    );

    final attempt = ++_attempt;
    final replaced = _attemptReplaced = Completer<void>();
    final ({bool connected, LinkFailure? failure})? outcome;
    try {
      outcome = await Future.any([
        _connect(pairing, attempt).timeout(connectionAttemptTimeout),
        replaced.future.then((_) => null),
      ]);
    } on TimeoutException {
      logger.w('[Communication] no desktop found in time; trying again later');
      _attempt++;
      _stopMpcClient();
      return _failed(emit, null);
    }
    // Replaced by a new pairing, which gets an attempt of its own, or the
    // bloc closed: nothing to report.
    if (outcome == null || attempt != _attempt) return;
    if (!outcome.connected) _failed(emit, outcome.failure);
  }

  /// One attempt to reach the desktop: the saved address, then every address
  /// discovery finds, then MPC. Once [attempt] is given up it tries nothing
  /// more, whatever step it is waiting on returns.
  Future<({bool connected, LinkFailure? failure})> _connect(
    DevicePairing pairing,
    int attempt,
  ) async {
    bool abandoned() => attempt != _attempt;
    const notConnected = (connected: false, failure: null);

    final localId = await _pairingStorage.localDeviceId();
    if (abandoned()) return notConnected;
    final candidates = <({String ip, int port})>[
      if (pairing.lastIp.isNotEmpty)
        (ip: pairing.lastIp, port: pairing.lastPort),
    ];

    LinkFailure? failure;
    Future<bool> tryTcp(String ip, int port) async {
      try {
        await _tcpService.connectToServer(
          ip: ip,
          port: port,
          pairingKey: pairing.pairingKey,
          expectedDeviceId: pairing.deviceId,
          localDeviceId: localId,
        );
        // Saved only now that the handshake proved it is the desktop.
        await _pairingStorage.updateLastConnection(ip: ip, port: port);
        return true;
      } on LinkException catch (e) {
        failure = e.failure;
        return false;
      } catch (e) {
        debugPrint('[Communication] $ip:$port: $e');
        return false;
      }
    }

    bool stop() => switch (failure) {
      LinkFailure.unknownKey ||
      LinkFailure.declined ||
      LinkFailure.version => true,
      _ => false,
    };

    for (final c in candidates) {
      if (await tryTcp(c.ip, c.port)) return (connected: true, failure: null);
      if (stop()) return (connected: false, failure: failure);
      if (abandoned()) return notConnected;
    }

    final found = await _discoveryService.discoverViaNetwork(
      deviceId: pairing.deviceId,
      token: discoveryToken(pairing.pairingKey, pairing.deviceId),
    );
    if (abandoned()) return notConnected;
    for (final c in found) {
      if (candidates.any((k) => k.ip == c.ip && k.port == c.port)) continue;
      if (await tryTcp(c.ip, c.port)) return (connected: true, failure: null);
      if (stop()) return (connected: false, failure: failure);
      if (abandoned()) return notConnected;
    }

    final mpc = _mpcTransport;
    if (mpc != null) {
      try {
        await mpc.connect(
          address: '',
          port: 0,
          token: discoveryToken(pairing.pairingKey, pairing.deviceId),
        );
        if (abandoned()) return notConnected;
        await _tcpService.connectOverMpc(
          pairingKey: pairing.pairingKey,
          expectedDeviceId: pairing.deviceId,
          localDeviceId: localId,
          timeout: const Duration(seconds: 12),
        );
        return (connected: true, failure: null);
      } on LinkException catch (e) {
        failure = e.failure;
      } catch (e) {
        debugPrint('[Communication] MPC: $e');
      }
      // Given up, it was stopped already; a newer attempt may be using MPC.
      if (abandoned()) return notConnected;
      // Not found: stop browsing, so a desktop found later can't take over
      // a link made some other way.
      _tcpService.cancelMpcClient();
      await mpc.disconnect();
    }

    return (connected: false, failure: failure);
  }

  /// Phone: stops browsing for the Mac over MPC without waiting, so a
  /// platform call that hangs can't hold up the next attempt.
  void _stopMpcClient() {
    final mpc = _mpcTransport;
    if (mpc == null) return;
    _tcpService.cancelMpcClient();
    unawaited(
      mpc.disconnect().catchError(
        (Object e) => logger.w('[Communication] MPC not stopped', e),
      ),
    );
  }

  void _failed(Emitter<DesktopSyncState> emit, LinkFailure? failure) {
    final issue = switch (failure) {
      LinkFailure.unknownKey => LinkIssue.keyRejected,
      LinkFailure.declined => LinkIssue.declined,
      LinkFailure.version => LinkIssue.desktopOutdated,
      _ => LinkIssue.notFound,
    };
    emit(
      state.copyWith(
        connectionStatus: ConnectionStatus.disconnected,
        connectionTransport: ConnectionTransport.unknown,
        issue: issue,
      ),
    );
    // The desktop answered and said no: trying again won't change that.
    if (issue == LinkIssue.notFound) _scheduleReconnect();
  }

  /// Retries with a doubling delay. After the last attempt the phone waits
  /// for the app to come back to the foreground or for Reconnect; the
  /// pairing is kept.
  void _scheduleReconnect() {
    if (_platform.isDesktop || _stayDisconnected) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[Communication] giving up until the app resumes');
      return;
    }
    final delay = initialReconnectDelay * (1 << _reconnectAttempts);
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!isClosed) add(const CommunicationConnectionRequested());
    });
  }

  // ---------------------------------------------------------------------------
  // Link state

  Future<void> _onLinkStateChanged(
    CommunicationLinkStateChanged event,
    Emitter<DesktopSyncState> emit,
  ) async {
    switch (event.state) {
      case ConnectionState.connected:
        _reconnectTimer?.cancel();
        _reconnectAttempts = 0;
        final peer = _tcpService.peer;
        final transport = _tcpService.transport == LinkTransport.mpc
            ? ConnectionTransport.multipeerConnectivity
            : ConnectionTransport.tcp;
        emit(
          state.copyWith(
            connectionStatus: ConnectionStatus.connected,
            connectionTransport: transport,
            connectedDeviceName: (peer?.name.isNotEmpty ?? false)
                ? peer!.name
                : null,
            issue: null,
            pendingApprovalName: null,
          ),
        );
        if (_platform.isDesktop) {
          await _onDesktopPhoneConnected(emit);
          onPhoneConnected?.call();
        }
      case ConnectionState.awaitingApproval:
        emit(
          state.copyWith(
            connectionStatus: ConnectionStatus.awaitingApproval,
            issue: null,
          ),
        );
      case ConnectionState.connecting:
        if (state.connectionStatus != ConnectionStatus.discovering) {
          emit(state.copyWith(connectionStatus: ConnectionStatus.discovering));
        }
      case ConnectionState.disconnected:
        final wasConnected =
            state.connectionStatus == ConnectionStatus.connected ||
            state.connectionStatus == ConnectionStatus.awaitingApproval;
        if (state.connectionStatus != ConnectionStatus.discovering) {
          emit(
            state.copyWith(
              connectionStatus: ConnectionStatus.disconnected,
              connectionTransport: ConnectionTransport.unknown,
              connectedDeviceName: _platform.isDesktop
                  ? null
                  : state.connectedDeviceName,
            ),
          );
        }
        // A full-tunnel VPN lets the phone connect and then drops the link.
        if (_platform.isDesktop) add(const CommunicationVpnChecked());
        if (!wasConnected || _platform.isDesktop) return;
        if (_tcpService.lastPeerCloseReason == 'user') {
          // The desktop's user disconnected this phone on purpose.
          _stayDisconnected = true;
          return;
        }
        final failure = _tcpService.lastClientFailure;
        if (failure == LinkFailure.declined ||
            failure == LinkFailure.unknownKey ||
            failure == LinkFailure.version) {
          // E.g. declined while waiting for approval.
          _failed(emit, failure);
          return;
        }
        _scheduleReconnect();
    }
  }

  Future<void> _onManualDisconnect(
    CommunicationManualDisconnect event,
    Emitter<DesktopSyncState> emit,
  ) async {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _stayDisconnected = true;
    await _tcpService.disconnect();
    if (_platform.isMobile) {
      _tcpService.cancelMpcClient();
      await _mpcTransport?.disconnect();
    }
    emit(
      state.copyWith(
        connectionStatus: ConnectionStatus.disconnected,
        connectionTransport: ConnectionTransport.unknown,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop: accepting a phone and moving to a key only it knows

  void _onApprovalRequested(
    CommunicationApprovalRequested event,
    Emitter<DesktopSyncState> emit,
  ) {
    final name = event.request?.peer.name;
    emit(
      state.copyWith(
        pendingApprovalName: event.request == null
            ? null
            : (name == null || name.isEmpty ? '?' : name),
      ),
    );
  }

  void _onApprovalAnswered(
    CommunicationApprovalAnswered event,
    Emitter<DesktopSyncState> emit,
  ) {
    if (event.accepted) {
      _tcpService.approvePending();
    } else {
      _tcpService.declinePending();
    }
    emit(state.copyWith(pendingApprovalName: null));
  }

  /// A phone became the paired one: remember it, and give it a key nobody
  /// else has seen, so the QR code that was shown no longer works.
  Future<void> _onPeerApproved(
    CommunicationPeerApproved event,
    Emitter<DesktopSyncState> emit,
  ) async {
    final pairing = state.pairedDevice;
    if (pairing == null) return;
    final updated = pairing.copyWith(
      peerDeviceId: event.peer.deviceId,
      peerDeviceName: event.peer.name,
      pendingKey: DevicePairing.newKey(),
    );
    await _pairingStorage.savePairing(updated);
    _tcpService.updateServerKeys(updated.acceptedKeys);
    emit(state.copyWith(pairedDevice: updated));
    await _sendRekey(updated);
  }

  Future<void> _onDesktopPhoneConnected(Emitter<DesktopSyncState> emit) async {
    final pairing = state.pairedDevice;
    if (pairing == null || pairing.pendingKey == null) return;
    if (_tcpService.activeKeyIndex == 1) {
      // The phone already uses the new key; its ack got lost.
      await _promotePendingKey(emit);
    } else {
      await _sendRekey(pairing);
    }
  }

  Future<void> _sendRekey(DevicePairing pairing) async {
    final key = pairing.pendingKey;
    if (key == null || !_tcpService.isConnected) return;
    try {
      await _tcpService.sendData('pairing.rekey', {'key': key});
    } catch (e) {
      // Sent again on the next connection.
      logger.w('[Communication] new key not sent yet', e);
    }
  }

  Future<void> _promotePendingKey(Emitter<DesktopSyncState> emit) async {
    final pairing = state.pairedDevice;
    final pending = pairing?.pendingKey;
    if (pairing == null || pending == null) return;
    final updated = pairing.copyWith(pairingKey: pending, pendingKey: null);
    await _pairingStorage.savePairing(updated);
    _tcpService.updateServerKeys(updated.acceptedKeys);
    emit(state.copyWith(pairedDevice: updated));
    // The discovery token comes from the key.
    await _advertise(updated);
  }

  Future<void> _onPairingMessage(
    CommunicationPairingMessage event,
    Emitter<DesktopSyncState> emit,
  ) async {
    switch (event.type) {
      case 'pairing.rekey' when _platform.isMobile:
        final key = event.payload['key'];
        final pairing = state.pairedDevice;
        if (key is! String || !isValidPairingKey(key) || pairing == null) {
          logger.w('[Communication] ignored an unusable new key');
          return;
        }
        final updated = pairing.copyWith(pairingKey: key);
        await _pairingStorage.savePairing(updated);
        emit(state.copyWith(pairedDevice: updated));
        try {
          await _tcpService.sendData('pairing.rekey_ack', {});
        } catch (e) {
          // The desktop notices the new key on the next connection.
          logger.w('[Communication] key change not confirmed yet', e);
        }
      case 'pairing.rekey_ack' when _platform.isDesktop:
        await _promotePendingKey(emit);
      default:
        logger.w('[Communication] unexpected ${event.type}');
    }
  }

  void _onServerFailure(
    CommunicationServerFailure event,
    Emitter<DesktopSyncState> emit,
  ) {
    if (event.failure == LinkFailure.version) {
      emit(state.copyWith(outdatedPhoneSeen: true));
    }
  }

  Future<void> _onMpcEnded(
    CommunicationMpcEnded event,
    Emitter<DesktopSyncState> emit,
  ) async {
    final pairing = state.pairedDevice;
    if (pairing == null || isClosed) return;
    await _mpcTransport?.startServer(
      port: pairing.lastPort,
      token: discoveryToken(pairing.pairingKey, pairing.deviceId),
    );
  }

  /// Desktop: tells the phone this app is quitting, so it reconnects later
  /// instead of treating the drop as a disconnect by the user.
  Future<void> shutdown() => _tcpService.disconnect(reason: 'shutdown');

  @override
  Future<void> close() {
    _attempt++;
    _reconnectTimer?.cancel();
    _networkTimer?.cancel();
    _vpnRecheckTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    return super.close();
  }
}
