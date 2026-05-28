import 'dart:async';
import 'dart:typed_data';

import 'package:airdrop/airdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';

class MpcTransport implements CommunicationService {
  final AirdropService _airdrop = AirdropService();
  final _stateController = StreamController<CommunicationState>.broadcast();
  final _dataController = StreamController<Uint8List>.broadcast();
  CommunicationState _state = CommunicationState.disconnected;
  StreamSubscription? _connectionSub;
  StreamSubscription? _dataSub;

  MpcTransport() {
    _connectionSub = _airdrop.syncConnectionStream.listen((event) {
      final status = event['status'] as String?;
      if (status == 'connected') {
        debugPrint('[MPC] Desktop sync connected: ${event['deviceName']}');
        _updateState(CommunicationState.connected);
      } else if (status == 'disconnected') {
        debugPrint('[MPC] Desktop sync disconnected');
        _updateState(CommunicationState.disconnected);
      }
    });

    _dataSub = _airdrop.syncDataStream.listen((data) {
      _dataController.add(data);
    });
  }

  @override
  TransportType get transportType => TransportType.multipeerConnectivity;

  @override
  CommunicationState get currentState => _state;

  @override
  Stream<CommunicationState> get stateStream => _stateController.stream;

  @override
  Stream<Uint8List> get dataStream => _dataController.stream;

  @override
  Future<void> startServer({required int port}) async {
    _updateState(CommunicationState.connecting);
    try {
      await _airdrop.startDesktopAdvertising();
      debugPrint('[MPC] Desktop advertising started');
    } catch (e) {
      debugPrint('[MPC] Failed to start desktop advertising: $e');
      _updateState(CommunicationState.disconnected);
    }
  }

  @override
  Future<void> connect({required String address, required int port}) async {
    _updateState(CommunicationState.connecting);
    try {
      await _airdrop.startDesktopBrowsing();
      debugPrint('[MPC] Desktop browsing started');
    } catch (e) {
      debugPrint('[MPC] Failed to start desktop browsing: $e');
      _updateState(CommunicationState.disconnected);
    }
  }

  @override
  Future<void> send(Uint8List data) async {
    try {
      await _airdrop.sendSyncData(data);
    } catch (e) {
      debugPrint('[MPC] Send failed: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _airdrop.disconnectDesktopSync();
    } catch (_) {}
    _updateState(CommunicationState.disconnected);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _connectionSub?.cancel();
    await _dataSub?.cancel();
    await _stateController.close();
    await _dataController.close();
  }

  void _updateState(CommunicationState state) {
    if (_state == state) return;
    _state = state;
    _stateController.add(state);
  }
}
