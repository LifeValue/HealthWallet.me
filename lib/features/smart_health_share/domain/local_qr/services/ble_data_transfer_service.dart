import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Service for transferring data over Bluetooth Low Energy (BLE)
/// Used when QR code size exceeds limits
abstract class BLEDataTransferService {
  /// Send data in chunks over BLE
  /// Returns a stream that emits transfer progress (0.0 - 1.0)
  Stream<double> sendData({
    required Uint8List data,
    required String sessionId,
  });

  /// Receive data chunks over BLE
  /// Returns a stream that emits received data chunks
  Stream<Uint8List> receiveData({
    required String sessionId,
  });

  /// Establish BLE connection to a specific device
  Future<bool> establishConnection({
    required String deviceId,
    required String sessionId,
  });

  /// Disconnect from current BLE connection
  Future<void> disconnect();

  /// Check if currently connected
  bool get isConnected;

  /// Get current transfer progress (0.0 - 1.0)
  double get transferProgress;

  /// Stream of BLE connection state changes
  Stream<BluetoothConnectionState> get connectionStateStream;
}


