import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health_wallet/features/sync/desktop/communication/data/services/transport/communication_service.dart';

class MpcTransport implements CommunicationService {
  static const _channel = MethodChannel('dev.lifevalue.healthwallet/mpc');

  final _stateController = StreamController<CommunicationState>.broadcast();
  final _dataController = StreamController<Uint8List>.broadcast();
  CommunicationState _state = CommunicationState.disconnected;

  MpcTransport() {
    _channel.setMethodCallHandler(_handleNativeCall);
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
      await _channel.invokeMethod('startAdvertising', {
        'serviceType': '_healthwallet._tcp',
      });
      debugPrint('[MPC] Advertising started');
    } catch (e) {
      debugPrint('[MPC] Failed to start advertising: $e');
      _updateState(CommunicationState.disconnected);
    }
  }

  @override
  Future<void> connect({required String address, required int port}) async {
    _updateState(CommunicationState.connecting);
    try {
      await _channel.invokeMethod('startBrowsing', {
        'serviceType': '_healthwallet._tcp',
      });
      debugPrint('[MPC] Browsing started');
    } catch (e) {
      debugPrint('[MPC] Failed to start browsing: $e');
      _updateState(CommunicationState.disconnected);
    }
  }

  @override
  Future<void> send(Uint8List data) async {
    try {
      await _channel.invokeMethod('sendData', {
        'data': data,
      });
    } catch (e) {
      debugPrint('[MPC] Send failed: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (_) {}
    _updateState(CommunicationState.disconnected);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _dataController.close();
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPeerConnected':
        debugPrint('[MPC] Peer connected');
        _updateState(CommunicationState.connected);
        break;
      case 'onPeerDisconnected':
        debugPrint('[MPC] Peer disconnected');
        _updateState(CommunicationState.disconnected);
        break;
      case 'onDataReceived':
        final data = call.arguments as Uint8List;
        _dataController.add(data);
        break;
    }
  }

  void _updateState(CommunicationState state) {
    if (_state == state) return;
    _state = state;
    _stateController.add(state);
  }
}
