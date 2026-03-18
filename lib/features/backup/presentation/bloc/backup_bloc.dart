import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:health_wallet/core/config/app_platform.dart';
import 'package:health_wallet/features/backup/data/models/device_pairing.dart';
import 'package:health_wallet/features/backup/data/services/discovery_service.dart';
import 'package:health_wallet/features/backup/data/services/pairing_storage_service.dart';
import 'package:health_wallet/features/backup/data/services/tcp_service.dart';

part 'backup_event.dart';
part 'backup_state.dart';
part 'backup_bloc.freezed.dart';

// Not @injectable -- AppPlatform is registered manually in main.dart/main_desktop.dart
// BackupBloc is provided manually in desktop DI setup
class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final AppPlatform _platform;
  final PairingStorageService _pairingStorage;
  final TcpService _tcpService;
  final DiscoveryService _discoveryService;

  StreamSubscription? _connectionSub;

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
          break;
        case ConnectionState.disconnected:
          add(const BackupDisconnected());
          break;
        case ConnectionState.connecting:
          break;
      }
    });
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
    final ip = await _tcpService.startServer(
      pairingKey: pairing.pairingKey,
      port: pairing.lastPort,
    );
    await _discoveryService.startDesktopAdvertising(
      ip: ip,
      port: pairing.lastPort,
      deviceId: pairing.deviceId,
    );
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

    final result = await _discoveryService.discover();
    if (result == null) {
      emit(state.copyWith(
        connectionStatus: BackupConnectionStatus.disconnected,
        error: 'Desktop not found',
      ));
      return;
    }

    try {
      final pairing = _pairingStorage.loadPairing();
      if (pairing == null) return;

      await _tcpService.connectToServer(
        ip: result.ip,
        port: result.port,
        pairingKey: pairing.pairingKey,
      );

      add(BackupConnected(ip: result.ip, port: result.port));
    } catch (e) {
      add(BackupConnectionFailed(error: e.toString()));
    }
  }

  void _onConnected(
    BackupConnected event,
    Emitter<BackupState> emit,
  ) {
    emit(state.copyWith(
      connectionStatus: BackupConnectionStatus.connected,
      connectedIp: event.ip,
      connectedPort: event.port,
      error: null,
    ));
  }

  void _onDisconnected(
    BackupDisconnected event,
    Emitter<BackupState> emit,
  ) {
    emit(state.copyWith(
      connectionStatus: BackupConnectionStatus.disconnected,
      connectedIp: null,
      connectedPort: null,
    ));
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
    _discoveryService.stopDesktopAdvertising();
    _tcpService.stopServer();
    return super.close();
  }
}
