import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/mpc_transport.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/transport_selector.dart';

part 'communication_event.dart';
part 'communication_state.dart';
part 'communication_bloc.freezed.dart';

class CommunicationBloc extends Bloc<CommunicationEvent, DesktopSyncState> {
  final AppPlatform _platform;
  final PairingStorageService _pairingStorage;
  final TcpService _tcpService;
  final DiscoveryService _discoveryService;

  StreamSubscription? _connectionSub;
  StreamSubscription? _mpcStateSub;
  MpcTransport? _mpcTransport;

  static const _mpcTimeout = Duration(seconds: 10);
  static const _initialReconnectDelay = Duration(seconds: 3);
  static const _maxReconnectAttempts = 5;
  int _reconnectAttempts = 0;

  CommunicationBloc(
    this._platform,
    this._pairingStorage,
    this._tcpService,
    this._discoveryService,
  ) : super(DesktopSyncState.initial()) {
    on<CommunicationInitialised>(_onInitialised);
    on<CommunicationPairingRequested>(_onPairingRequested);
    on<CommunicationPairingCompleted>(_onPairingCompleted);
    on<CommunicationConnectionRequested>(_onConnectionRequested);
    on<CommunicationConnected>(_onConnected);
    on<CommunicationDisconnected>(_onDisconnected);
    on<CommunicationManualDisconnect>(_onManualDisconnect);
    on<CommunicationConnectionFailed>(_onConnectionFailed);
    on<CommunicationRemoteDeviceNameReceived>(_onRemoteDeviceName);

    _listenToTcp();
    _initMpcIfAvailable();
  }

  void _listenToTcp() {
    _connectionSub = _tcpService.connectionState.listen((tcpState) {
      switch (tcpState) {
        case ConnectionState.connected:
          add(const CommunicationConnected(ip: '', port: 0));
          break;
        case ConnectionState.disconnected:
          add(const CommunicationDisconnected());
          break;
        case ConnectionState.connecting:
          break;
      }
    });

    _tcpService.messages.listen((message) {
      if (message.type == MessageType.hello) {
        try {
          final json = jsonDecode(message.payloadString) as Map<String, dynamic>;
          var remoteName = json['device_name'] as String?;
          if (remoteName == 'localhost' || remoteName == 'unknown') {
            remoteName = 'Mobile Device';
          }
          if (remoteName != null && remoteName.isNotEmpty) {
            add(CommunicationRemoteDeviceNameReceived(name: remoteName));
          }
        } catch (_) {}
      }
    });
  }

  void _initMpcIfAvailable() {
    if (!TransportSelector.isMpcAvailable()) return;

    _mpcTransport = MpcTransport();
    _mpcStateSub = _mpcTransport!.stateStream.listen((mpcState) {
      if (mpcState == CommunicationState.connected) {
        add(const CommunicationConnected(ip: 'mpc', port: 0));
      } else if (mpcState == CommunicationState.disconnected) {
        if (state.connectionTransport == ConnectionTransport.multipeerConnectivity) {
          add(const CommunicationDisconnected());
        }
      }
    });
  }

  Future<void> _onInitialised(
    CommunicationInitialised event,
    Emitter<DesktopSyncState> emit,
  ) async {
    final pairing = _pairingStorage.loadPairing();
    if (pairing == null) return;

    emit(state.copyWith(pairedDevice: pairing));

    if (_platform.isDesktop) {
      final (:ip, :vpnDetected) = await _getLocalIp();
      if (vpnDetected) {
        debugPrint('[Communication] VPN detected — connection issues may occur');
      }
      final updated = pairing.lastIp != ip
          ? pairing.copyWith(lastIp: ip)
          : pairing;
      if (updated != pairing) {
        await _pairingStorage.savePairing(updated);
      }
      emit(state.copyWith(
        pairedDevice: updated,
        vpnDetected: vpnDetected,
      ));
      await _startDesktopServer(emit, updated);
    } else {
      add(const CommunicationConnectionRequested());
    }
  }

  Future<void> _onPairingRequested(
    CommunicationPairingRequested event,
    Emitter<DesktopSyncState> emit,
  ) async {
    if (!_platform.isDesktop) return;

    final (:ip, :vpnDetected) = await _getLocalIp();
    if (vpnDetected) {
      debugPrint('[Communication] VPN detected — connection issues may occur');
    }
    var hostname = Platform.localHostname;
    if (hostname.endsWith('.local')) {
      hostname = hostname.substring(0, hostname.length - 6);
    }
    hostname = hostname.replaceAll('-', ' ');

    final pairing = DevicePairing.generate(
      deviceName: hostname,
      localIp: ip,
      os: Platform.operatingSystem,
    );

    await _pairingStorage.savePairing(pairing);
    emit(state.copyWith(pairedDevice: pairing, vpnDetected: vpnDetected));
    await _startDesktopServer(emit, pairing);
  }

  Future<void> _startDesktopServer(
    Emitter<DesktopSyncState> emit,
    DevicePairing pairing,
  ) async {
    final server = await _tcpService.startServer(
      pairingKey: pairing.pairingKey,
      port: pairing.lastPort,
    );

    if (server.port != pairing.lastPort) {
      final updated = pairing.copyWith(
        lastPort: server.port,
        lastIp: server.ip,
      );
      await _pairingStorage.savePairing(updated);
      emit(state.copyWith(pairedDevice: updated));
    }

    await _discoveryService.startDesktopAdvertising(
      ip: server.ip,
      port: server.port,
      deviceId: pairing.deviceId,
    );

    if (_mpcTransport != null) {
      await _mpcTransport!.startServer(port: server.port);
      debugPrint('[Communication] MPC advertising started alongside TCP');
    }
  }

  Future<void> _onPairingCompleted(
    CommunicationPairingCompleted event,
    Emitter<DesktopSyncState> emit,
  ) async {
    await _pairingStorage.savePairing(event.pairing);
    emit(state.copyWith(pairedDevice: event.pairing));

    if (!_platform.isDesktop) {
      add(const CommunicationConnectionRequested());
    }
  }

  Future<void> _onConnectionRequested(
    CommunicationConnectionRequested event,
    Emitter<DesktopSyncState> emit,
  ) async {
    if (_platform.isDesktop) return;
    if (state.pairedDevice == null) return;

    emit(state.copyWith(
      connectionStatus: ConnectionStatus.discovering,
      error: null,
    ));

    if (await _tryMpc()) return;
    if (await _trySavedIp()) return;
    if (await _tryNetworkDiscovery()) return;

    add(const CommunicationConnectionFailed(
        error: 'Desktop not found. Try scanning QR again.'));
  }

  Future<bool> _tryMpc() async {
    if (_mpcTransport == null) return false;

    debugPrint('[Communication] Step 1: MPC (Apple direct)');
    _mpcTransport!.connect(address: '', port: 0);

    for (var i = 0; i < _mpcTimeout.inSeconds; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (_mpcTransport!.currentState == CommunicationState.connected) {
        debugPrint('[Communication] MPC connected after ${i + 1}s');
        return true;
      }
    }
    debugPrint('[Communication] MPC timeout, trying TCP');
    return false;
  }

  Future<bool> _trySavedIp() async {
    final pairing = _pairingStorage.loadPairing();
    if (pairing == null) return false;

    debugPrint('[Communication] Step 2: TCP saved IP ${pairing.lastIp}:${pairing.lastPort}');
    try {
      await _tcpService.connectToServer(
        ip: pairing.lastIp,
        port: pairing.lastPort,
        pairingKey: pairing.pairingKey,
      );
      add(CommunicationConnected(ip: pairing.lastIp, port: pairing.lastPort));
      return true;
    } catch (e) {
      debugPrint('[Communication] Saved IP failed: $e');
      return false;
    }
  }

  Future<bool> _tryNetworkDiscovery() async {
    final pairing = _pairingStorage.loadPairing();
    if (pairing == null) return false;

    debugPrint('[Communication] Step 3: mDNS + SSDP');
    final result = await _discoveryService.discoverViaNetwork();
    if (result == null) return false;

    try {
      await _tcpService.connectToServer(
        ip: result.ip,
        port: result.port,
        pairingKey: pairing.pairingKey,
      );
      add(CommunicationConnected(ip: result.ip, port: result.port));
      return true;
    } catch (e) {
      debugPrint('[Communication] Network discovery failed: $e');
      return false;
    }
  }

  void _onConnected(
    CommunicationConnected event,
    Emitter<DesktopSyncState> emit,
  ) {

    final transport = event.ip == 'mpc'
        ? ConnectionTransport.multipeerConnectivity
        : ConnectionTransport.tcp;

    emit(state.copyWith(
      connectionStatus: ConnectionStatus.connected,
      connectionTransport: transport,
      connectedIp: event.ip == 'mpc' ? null : event.ip,
      connectedPort: event.port == 0 ? null : event.port,
      error: null,
    ));
  }

  Future<void> _onDisconnected(
    CommunicationDisconnected event,
    Emitter<DesktopSyncState> emit,
  ) async {
    final wasConnected = state.connectionStatus == ConnectionStatus.connected;

    emit(state.copyWith(
      connectionStatus: ConnectionStatus.disconnected,
      connectionTransport: ConnectionTransport.unknown,
      connectedIp: null,
      connectedPort: null,
    ));

    if (wasConnected && _platform.isDesktop) {
      debugPrint('[Communication] Client disconnected');
    }

    if (wasConnected && state.pairedDevice != null && _platform.isMobile) {
      _reconnectAttempts++;
      if (_reconnectAttempts > _maxReconnectAttempts) {
        debugPrint('[Communication] Max reconnect attempts reached, clearing pairing');
        _reconnectAttempts = 0;
        await _pairingStorage.clearPairing();
        emit(state.copyWith(pairedDevice: null));
        add(const CommunicationConnectionFailed(
            error: 'Could not connect. Scan QR code to pair again.'));
        return;
      }
      final delay = _initialReconnectDelay * (1 << (_reconnectAttempts - 1));
      debugPrint('[Communication] Lost connection, reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
      Future.delayed(delay, () {
        if (!isClosed && state.connectionStatus == ConnectionStatus.disconnected) {
          add(const CommunicationConnectionRequested());
        }
      });
    }
  }

  Future<void> _onManualDisconnect(
    CommunicationManualDisconnect event,
    Emitter<DesktopSyncState> emit,
  ) async {
    _reconnectAttempts = 0;
    await _tcpService.disconnect();

    emit(state.copyWith(
      connectionStatus: ConnectionStatus.disconnected,
      connectionTransport: ConnectionTransport.unknown,
      connectedIp: null,
      connectedPort: null,
    ));
  }

  void _onConnectionFailed(
    CommunicationConnectionFailed event,
    Emitter<DesktopSyncState> emit,
  ) {
    emit(state.copyWith(
      connectionStatus: ConnectionStatus.disconnected,
      error: event.error,
    ));
  }

  void _onRemoteDeviceName(
    CommunicationRemoteDeviceNameReceived event,
    Emitter<DesktopSyncState> emit,
  ) {
    _reconnectAttempts = 0;
    emit(state.copyWith(connectedDeviceName: event.name));
  }

  Future<({String ip, bool vpnDetected})> _getLocalIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    if (interfaces.isEmpty) return (ip: '127.0.0.1', vpnDetected: false);

    final vpnPrefixes = ['utun', 'tun', 'tap', 'ppp', 'ipsec', 'wg'];
    final lanPrefixes = ['en', 'eth', 'wlan', 'Wi-Fi', 'Ethernet'];

    bool isVpnInterface(String name) =>
        vpnPrefixes.any((p) => name.toLowerCase().startsWith(p));
    bool isLanInterface(String name) =>
        lanPrefixes.any((p) => name.toLowerCase().startsWith(p.toLowerCase()));

    final hasVpn = interfaces.any((i) => isVpnInterface(i.name));

    for (final iface in interfaces) {
      if (isLanInterface(iface.name) && iface.addresses.isNotEmpty) {
        final addr = iface.addresses.first.address;
        if (!addr.startsWith('169.254.')) {
          return (ip: addr, vpnDetected: hasVpn);
        }
      }
    }

    for (final iface in interfaces) {
      if (!isVpnInterface(iface.name) && iface.addresses.isNotEmpty) {
        return (ip: iface.addresses.first.address, vpnDetected: hasVpn);
      }
    }

    return (ip: interfaces.first.addresses.first.address, vpnDetected: hasVpn);
  }

  @override
  Future<void> close() {
    _connectionSub?.cancel();
    _mpcStateSub?.cancel();
    return super.close();
  }
}
