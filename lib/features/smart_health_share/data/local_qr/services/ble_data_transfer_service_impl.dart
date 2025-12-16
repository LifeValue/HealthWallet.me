import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/services/ble_data_transfer_service.dart';
import 'package:injectable/injectable.dart';

/// BLE Service UUID for HealthWallet.me data transfer
const String _healthWalletServiceUuid = '0000FE95-0000-1000-8000-00805F9B34FB';

/// Characteristic UUIDs
const String _dataTransferCharacteristicUuid =
    '0000FE97-0000-1000-8000-00805F9B34FB';
const String _sessionMetadataCharacteristicUuid =
    '0000FE98-0000-1000-8000-00805F9B34FB';

/// Maximum chunk size (accounting for MTU limitations, typically 20-23 bytes)
/// Using 20 bytes to be safe, with 4 bytes for chunk header (index + total)
const int _maxChunkSize = 16; // 20 - 4 bytes header

@Injectable(as: BLEDataTransferService)
class BLEDataTransferServiceImpl implements BLEDataTransferService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _dataTransferCharacteristic;
  BluetoothCharacteristic? _sessionMetadataCharacteristic;
  StreamController<double>? _progressController;
  StreamController<Uint8List>? _receiveController;
  StreamController<BluetoothConnectionState>? _connectionStateController;
  StreamSubscription? _characteristicSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  List<Uint8List> _receivedChunks = [];
  int _totalChunks = 0;
  double _currentProgress = 0.0;
  bool _isConnected = false;

  @override
  bool get isConnected => _isConnected;

  @override
  double get transferProgress => _currentProgress;

  @override
  Stream<BluetoothConnectionState> get connectionStateStream {
    _connectionStateController ??= StreamController<BluetoothConnectionState>.broadcast();
    return _connectionStateController!.stream;
  }

  @override
  Future<bool> establishConnection({
    required String deviceId,
    required String sessionId,
  }) async {
    try {
      // Find device by ID
      final devices = await FlutterBluePlus.connectedDevices;
      BluetoothDevice? device;
      try {
        device = devices.firstWhere(
          (d) => d.remoteId.str == deviceId,
        );
      } catch (e) {
        device = null;
      }

      // If not in connected devices, try scanning
      if (device == null) {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
        await for (final result in FlutterBluePlus.scanResults) {
          for (final scanResult in result) {
            if (scanResult.device.remoteId.str == deviceId) {
              device = scanResult.device;
              await FlutterBluePlus.stopScan();
              break;
            }
          }
          if (device != null) break;
        }
        await FlutterBluePlus.stopScan();
      }

      if (device == null) {
        logger.e('BLE: Device $deviceId not found');
        return false;
      }

      // Connect to device
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;
      _isConnected = true;

      // Initialize connection state controller if needed
      _connectionStateController ??= StreamController<BluetoothConnectionState>.broadcast();

      // Subscribe to connection state changes
      _connectionStateSubscription = device.connectionState.listen((state) {
        _isConnected = state == BluetoothConnectionState.connected;
        _connectionStateController?.add(state);
        
        if (state == BluetoothConnectionState.disconnected) {
          logger.d('BLE: Connection state changed to disconnected');
        }
      });

      // Discover services
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() ==
            _healthWalletServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Service not found'),
      );

      // Get characteristics
      _dataTransferCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() ==
            _dataTransferCharacteristicUuid.toLowerCase(),
        orElse: () => throw Exception('Data transfer characteristic not found'),
      );

      _sessionMetadataCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() ==
            _sessionMetadataCharacteristicUuid.toLowerCase(),
        orElse: () => throw Exception('Session metadata characteristic not found'),
      );

      // Subscribe to notifications for receiving data
      await _dataTransferCharacteristic!.setNotifyValue(true);
      _characteristicSubscription =
          _dataTransferCharacteristic!.onValueReceived.listen((value) {
        _handleReceivedChunk(Uint8List.fromList(value));
      });

      // Send session metadata
      final sessionMetadata = jsonEncode({'sessionId': sessionId});
      await _sessionMetadataCharacteristic!.write(
        Uint8List.fromList(utf8.encode(sessionMetadata)),
        withoutResponse: false,
      );

      logger.d('BLE: Connected to device $deviceId');
      return true;
    } catch (e) {
      logger.e('BLE: Connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  @override
  Stream<double> sendData({
    required Uint8List data,
    required String sessionId,
  }) async* {
    if (!_isConnected || _dataTransferCharacteristic == null) {
      throw Exception('Not connected to BLE device');
    }

    _progressController = StreamController<double>.broadcast();
    _currentProgress = 0.0;

    try {
      // Calculate chunks
      final totalChunks = (data.length / _maxChunkSize).ceil();
      logger.d('BLE: Sending ${data.length} bytes in $totalChunks chunks');

      // Send total chunks count first (via metadata characteristic)
      final metadata = jsonEncode({
        'sessionId': sessionId,
        'totalChunks': totalChunks,
        'totalSize': data.length,
      });
      await _sessionMetadataCharacteristic!.write(
        Uint8List.fromList(utf8.encode(metadata)),
        withoutResponse: false,
      );

      // Send data chunks
      for (int i = 0; i < totalChunks; i++) {
        final start = i * _maxChunkSize;
        final end = (start + _maxChunkSize < data.length)
            ? start + _maxChunkSize
            : data.length;
        final chunk = data.sublist(start, end);

        // Create packet: [chunk_index (2 bytes)][total_chunks (2 bytes)][data]
        final packet = Uint8List(4 + chunk.length);
        packet[0] = (i >> 8) & 0xFF;
        packet[1] = i & 0xFF;
        packet[2] = (totalChunks >> 8) & 0xFF;
        packet[3] = totalChunks & 0xFF;
        packet.setRange(4, 4 + chunk.length, chunk);

        await _dataTransferCharacteristic!.write(
          packet,
          withoutResponse: false,
        );

        _currentProgress = (i + 1) / totalChunks;
        _progressController!.add(_currentProgress);
        yield _currentProgress;

        // Small delay to avoid overwhelming the BLE stack
        await Future.delayed(const Duration(milliseconds: 50));
      }

      logger.d('BLE: Data transfer completed');
    } catch (e) {
      logger.e('BLE: Send error: $e');
      rethrow;
    }
  }

  @override
  Stream<Uint8List> receiveData({
    required String sessionId,
  }) async* {
    if (!_isConnected || _dataTransferCharacteristic == null) {
      throw Exception('Not connected to BLE device');
    }

    _receiveController = StreamController<Uint8List>.broadcast();
    _receivedChunks.clear();
    _totalChunks = 0;

    // Wait for session metadata to know total chunks
    await Future.delayed(const Duration(milliseconds: 500));

    // Listen for chunks
    await for (final chunk in _receiveController!.stream) {
      yield chunk;
    }
  }

  void _handleReceivedChunk(Uint8List packet) {
    try {
      if (packet.length < 4) {
        logger.w('BLE: Received invalid packet (too short)');
        return;
      }

      // Extract header: [chunk_index (2 bytes)][total_chunks (2 bytes)]
      final chunkIndex = (packet[0] << 8) | packet[1];
      final totalChunks = (packet[2] << 8) | packet[3];
      final chunkData = packet.sublist(4);

      if (_totalChunks == 0) {
        _totalChunks = totalChunks;
        _receivedChunks = List.filled(totalChunks, Uint8List(0));
      }

      // Store chunk
      if (chunkIndex < _receivedChunks.length) {
        _receivedChunks[chunkIndex] = chunkData;
      }

      // Check if all chunks received
      final receivedCount = _receivedChunks.where((c) => c.isNotEmpty).length;
      _currentProgress = receivedCount / _totalChunks;

      if (receivedCount == _totalChunks) {
        // Reconstruct full data
        final fullData = Uint8List(
          _receivedChunks.fold<int>(0, (sum, chunk) => sum + chunk.length),
        );
        int offset = 0;
        for (final chunk in _receivedChunks) {
          fullData.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }

        _receiveController?.add(fullData);
        _receiveController?.close();
        logger.d('BLE: All chunks received, reconstructed ${fullData.length} bytes');
      }
    } catch (e) {
      logger.e('BLE: Error handling chunk: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      _characteristicSubscription?.cancel();
      _characteristicSubscription = null;
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;

      if (_dataTransferCharacteristic != null) {
        await _dataTransferCharacteristic!.setNotifyValue(false);
      }

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      _progressController?.close();
      _receiveController?.close();
      _progressController = null;
      _receiveController = null;
      _connectedDevice = null;
      _dataTransferCharacteristic = null;
      _sessionMetadataCharacteristic = null;
      _isConnected = false;
      _currentProgress = 0.0;
      _receivedChunks.clear();
      _totalChunks = 0;

      logger.d('BLE: Disconnected');
    } catch (e) {
      logger.e('BLE: Disconnect error: $e');
    }
  }
}

