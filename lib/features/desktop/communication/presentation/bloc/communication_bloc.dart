import 'dart:async';
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
    on<CommunicationConnectionFailed>(_onConnectionFailed);

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

    if (TransportSelector.isMpcAvailable()) {
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
  }

  Future<void> _onInitialised(
    CommunicationInitialised event,
    Emitter<DesktopSyncState> emit,
  ) async {
    final pairing = _pairingStorage.loadPairing();
    if (pairing != null) {
      emit(state.copyWith(pairedDevice: pairing));

      if (_platform.isDesktop) {
        await _startDesktopServer(emit, pairing);
      } else {
        add(const CommunicationConnectionRequested());
      }
    }
  }

  Future<void> _onPairingRequested(
    CommunicationPairingRequested event,
    Emitter<DesktopSyncState> emit,
  ) async {
    if (!_platform.isDesktop) return;

    final localIp = await _getLocalIp();
    final pairing = DevicePairing.generate(
      deviceName: Platform.localHostname,
      localIp: localIp,
      os: Platform.operatingSystem,
    );

    await _pairingStorage.savePairing(pairing);
    emit(state.copyWith(pairedDevice: pairing));

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
      debugPrint('[CommunicationBloc] MPC advertising started alongside TCP');
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

    emit(state.copyWith(
      connectionStatus: ConnectionStatus.discovering,
      error: null,
    ));

    if (_mpcTransport != null) {
      debugPrint('[CommunicationBloc] Step 1: MPC (Apple direct, no network needed)');
      _mpcTransport!.connect(address: '', port: 0);

      for (var i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (_mpcTransport!.currentState == CommunicationState.connected) {
          debugPrint('[CommunicationBloc] MPC connected after ${i + 1}s');
          return;
        }
      }
      debugPrint('[CommunicationBloc] MPC not connected after 10s, trying TCP');
    }

    final pairing = _pairingStorage.loadPairing();
    if (pairing == null) {
      emit(state.copyWith(
        connectionStatus: ConnectionStatus.disconnected,
        error: 'Not paired',
      ));
      return;
    }

    debugPrint('[CommunicationBloc] Step 2: TCP saved IP ${pairing.lastIp}:${pairing.lastPort}');
    try {
      await _tcpService.connectToServer(
        ip: pairing.lastIp,
        port: pairing.lastPort,
        pairingKey: pairing.pairingKey,
      );
      add(CommunicationConnected(ip: pairing.lastIp, port: pairing.lastPort));
      return;
    } catch (e) {
      debugPrint('[CommunicationBloc] Saved IP failed: $e');
    }

    debugPrint('[CommunicationBloc] Step 3: Network discovery (mDNS + SSDP)');
    final result = await _discoveryService.discoverViaNetwork();
    if (result != null) {
      try {
        await _tcpService.connectToServer(
          ip: result.ip,
          port: result.port,
          pairingKey: pairing.pairingKey,
        );
        add(CommunicationConnected(ip: result.ip, port: result.port));
        return;
      } catch (e) {
        debugPrint('[CommunicationBloc] Network discovery connect failed: $e');
      }
    }

    debugPrint('[CommunicationBloc] All connection methods failed');
    add(const CommunicationConnectionFailed(error: 'Desktop not found. Try scanning QR again.'));
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

  void _onDisconnected(
    CommunicationDisconnected event,
    Emitter<DesktopSyncState> emit,
  ) {
    final wasConnected = state.connectionStatus == ConnectionStatus.connected;
    emit(state.copyWith(
      connectionStatus: ConnectionStatus.disconnected,
      connectionTransport: ConnectionTransport.unknown,
      connectedIp: null,
      connectedPort: null,
    ));

    if (wasConnected && state.pairedDevice != null) {
      debugPrint('[CommunicationBloc] Connection lost, auto-reconnecting in 3s...');
      Future.delayed(const Duration(seconds: 3), () {
        if (!isClosed && state.connectionStatus == ConnectionStatus.disconnected) {
          add(const CommunicationConnectionRequested());
        }
      });
    }
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

  Future<String> _getLocalIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface_ in interfaces) {
      for (final address in interface_.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
    return '127.0.0.1';
  }

  @override
  Future<void> close() {
    _connectionSub?.cancel();
    _mpcStateSub?.cancel();
    return super.close();
  }
}
