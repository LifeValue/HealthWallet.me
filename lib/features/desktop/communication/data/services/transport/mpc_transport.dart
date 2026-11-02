import 'dart:async';

import 'package:airdrop/airdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/desktop/communication/data/services/transport/communication_service.dart';

/// MultipeerConnectivity between an iPhone and a Mac, through `airdrop`. The
/// Mac advertises the pairing's discovery token and accepts only invitations
/// carrying it; the iPhone invites only a Mac advertising it.
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
        debugPrint('[MPC] Desktop sync connected');
        _updateState(CommunicationState.connected);
      } else if (status == 'disconnected') {
        debugPrint('[MPC] Desktop sync disconnected');
        _updateState(CommunicationState.disconnected);
      } else if (status == 'error') {
        logger.w('[MPC] ${event['message']}');
        _updateState(CommunicationState.disconnected);
      }
    });

    _dataSub = _airdrop.syncDataStream.listen(_dataController.add);
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
  Future<void> startServer({required int port, String? token}) async {
    if (token == null) return;
    _updateState(CommunicationState.connecting);
    try {
      await _airdrop.startDesktopAdvertising(token: token);
    } catch (e) {
      logger.w('[MPC] advertising failed', e);
      _updateState(CommunicationState.disconnected);
    }
  }

  @override
  Future<void> connect({
    required String address,
    required int port,
    String? token,
  }) async {
    if (token == null) return;
    _updateState(CommunicationState.connecting);
    try {
      await _airdrop.startDesktopBrowsing(token: token);
    } catch (e) {
      logger.w('[MPC] browsing failed', e);
      _updateState(CommunicationState.disconnected);
    }
  }

  /// Throws when the native side couldn't send, so the caller keeps the
  /// data instead of believing it went out.
  @override
  Future<void> send(Uint8List data) => _airdrop.sendSyncData(data);

  @override
  Future<void> disconnect() async {
    try {
      await _airdrop.disconnectDesktopSync();
    } catch (e) {
      logger.w('[MPC] disconnect failed', e);
    }
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
