import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/models/device_pairing.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/services/discovery_service.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/services/tcp_service.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/services/transport/communication_service.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/services/transport/mpc_transport.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/services/transport/transport_selector.dart';

part 'backup_event.dart';
part 'backup_state.dart';
part 'backup_bloc.freezed.dart';

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final AppPlatform _platform;
  final PairingStorageService _pairingStorage;
  final TcpService _tcpService;
  final DiscoveryService _discoveryService;

  StreamSubscription? _connectionSub;
  StreamSubscription? _mpcStateSub;
  MpcTransport? _mpcTransport;

  BackupBloc(
    this._platform,
    this._pairingStorage,
    this._tcpService,
    this._discoveryService,
  ) : super(BackupState.initial()) {
    on<BackupInitialised>(_onInitialised);
    on<BackupPairingRequested>(_onPairingRequested);
    on<BackupPairingCompleted>(_onPairingCompleted);
    on<BackupConnectionRequested>(_onConnectionRequested);
    on<BackupConnected>(_onConnected);
    on<BackupDisconnected>(_onDisconnected);
    on<BackupConnectionFailed>(_onConnectionFailed);

    _connectionSub = _tcpService.connectionState.listen((tcpState) {
      switch (tcpState) {
        case ConnectionState.connected:
          add(const BackupConnected(ip: '', port: 0));
          break;
        case ConnectionState.disconnected:
          add(const BackupDisconnected());
          break;
        case ConnectionState.connecting:
          break;
      }
    });

    if (TransportSelector.isMpcAvailable()) {
      _mpcTransport = MpcTransport();
      _mpcStateSub = _mpcTransport!.stateStream.listen((mpcState) {
        if (mpcState == CommunicationState.connected) {
          add(const BackupConnected(ip: 'mpc', port: 0));
        } else if (mpcState == CommunicationState.disconnected) {
          if (state.connectionTransport == ConnectionTransport.multipeerConnectivity) {
            add(const BackupDisconnected());
          }
        }
      });
    }
  }

  Future<void> _onInitialised(
    BackupInitialised event,
    Emitter<BackupState> emit,
  ) async {
    final pairing = _pairingStorage.loadPairing();
    if (pairing != null) {
      emit(state.copyWith(pairedDevice: pairing));

      if (_platform.isDesktop) {
        await _startDesktopServer(emit, pairing);
      } else {
        add(const BackupConnectionRequested());
      }
    }
  }

  Future<void> _onPairingRequested(
    BackupPairingRequested event,
    Emitter<BackupState> emit,
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
    Emitter<BackupState> emit,
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
      debugPrint('[BackupBloc] MPC advertising started alongside TCP');
    }
  }

  Future<void> _onPairingCompleted(
    BackupPairingCompleted event,
    Emitter<BackupState> emit,
  ) async {
    await _pairingStorage.savePairing(event.pairing);
    emit(state.copyWith(pairedDevice: event.pairing));

    if (!_platform.isDesktop) {
      add(const BackupConnectionRequested());
    }
  }

  Future<void> _onConnectionRequested(
    BackupConnectionRequested event,
    Emitter<BackupState> emit,
  ) async {
    if (_platform.isDesktop) return;

    emit(state.copyWith(
      connectionStatus: BackupConnectionStatus.discovering,
      error: null,
    ));

    if (_mpcTransport != null) {
      debugPrint('[BackupBloc] Step 1: MPC (Apple direct, no network needed)');
      _mpcTransport!.connect(address: '', port: 0);

      for (var i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (_mpcTransport!.currentState == CommunicationState.connected) {
          debugPrint('[BackupBloc] MPC connected after ${i + 1}s');
          return;
        }
      }
      debugPrint('[BackupBloc] MPC not connected after 10s, trying TCP');
    }

    final pairing = _pairingStorage.loadPairing();
    if (pairing == null) {
      emit(state.copyWith(
        connectionStatus: BackupConnectionStatus.disconnected,
        error: 'Not paired',
      ));
      return;
    }

    debugPrint('[BackupBloc] Step 2: TCP saved IP ${pairing.lastIp}:${pairing.lastPort}');
    try {
      await _tcpService.connectToServer(
        ip: pairing.lastIp,
        port: pairing.lastPort,
        pairingKey: pairing.pairingKey,
      );
      add(BackupConnected(ip: pairing.lastIp, port: pairing.lastPort));
      return;
    } catch (e) {
      debugPrint('[BackupBloc] Saved IP failed: $e');
    }

    debugPrint('[BackupBloc] Step 3: Network discovery (mDNS + SSDP)');
    final result = await _discoveryService.discoverViaNetwork();
    if (result != null) {
      try {
        await _tcpService.connectToServer(
          ip: result.ip,
          port: result.port,
          pairingKey: pairing.pairingKey,
        );
        add(BackupConnected(ip: result.ip, port: result.port));
        return;
      } catch (e) {
        debugPrint('[BackupBloc] Network discovery connect failed: $e');
      }
    }

    debugPrint('[BackupBloc] All connection methods failed');
    add(const BackupConnectionFailed(error: 'Desktop not found. Try scanning QR again.'));
  }

  void _onConnected(
    BackupConnected event,
    Emitter<BackupState> emit,
  ) {
    final transport = event.ip == 'mpc'
        ? ConnectionTransport.multipeerConnectivity
        : ConnectionTransport.tcp;

    emit(state.copyWith(
      connectionStatus: BackupConnectionStatus.connected,
      connectionTransport: transport,
      connectedIp: event.ip == 'mpc' ? null : event.ip,
      connectedPort: event.port == 0 ? null : event.port,
      error: null,
    ));
  }

  void _onDisconnected(
    BackupDisconnected event,
    Emitter<BackupState> emit,
  ) {
    final wasConnected = state.connectionStatus == BackupConnectionStatus.connected;
    emit(state.copyWith(
      connectionStatus: BackupConnectionStatus.disconnected,
      connectionTransport: ConnectionTransport.unknown,
      connectedIp: null,
      connectedPort: null,
    ));

    if (wasConnected && state.pairedDevice != null) {
      debugPrint('[BackupBloc] Connection lost, auto-reconnecting in 3s...');
      Future.delayed(const Duration(seconds: 3), () {
        if (!isClosed && state.connectionStatus == BackupConnectionStatus.disconnected) {
          add(const BackupConnectionRequested());
        }
      });
    }
  }

  void _onConnectionFailed(
    BackupConnectionFailed event,
    Emitter<BackupState> emit,
  ) {
    emit(state.copyWith(
      connectionStatus: BackupConnectionStatus.disconnected,
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
