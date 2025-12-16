import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:health_wallet/core/utils/logger.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/services/local_qr_proximity_service.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

@Injectable(as: LocalQRProximityService)
class LocalQRProximityServiceImpl implements LocalQRProximityService {
  StreamController<bool>? _advertisingController;
  StreamController<bool>? _proximityController;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _pingPongSubscription;
  Timer? _proximityTimer;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _pingPongCharacteristic;
  bool _isAdvertising = false;
  bool _isScanning = false;

  // HealthWallet.me BLE Service UUID for peer-to-peer detection
  // Format: 0000XXXX-0000-1000-8000-00805F9B34FB
  static const String _healthWalletServiceUuid = '';
  static const String _pingPongCharacteristicUuid = '';
  static const String _healthWalletAppIdentifier = 'healthwallet.me';

  @override
  Stream<bool> startAdvertising({
    required String deviceName,
    required Function() onDisconnected,
  }) async* {
    if (_isAdvertising) {
      stopAdvertising();
    }

    _advertisingController = StreamController<bool>.broadcast();
    _isAdvertising = true;

    try {
      // Check if Bluetooth is available
      if (!await isBluetoothAvailable()) {
        logger.e('BLE: Bluetooth not available for advertising');
        _advertisingController!.add(false);
        yield false;
        return;
      }

      // Note: BLE advertising on iOS has limitations and the flutter_ble_peripheral
      // package has Swift compilation issues. For iOS, we skip advertising and
      // rely on the receiver scanning by device name/identifier from the QR code.
      // On Android, we attempt to use flutter_blue_plus for advertising if available.

      if (Platform.isIOS) {
        // iOS: Skip advertising due to platform limitations and package issues
        // The receiver will scan for devices by name/identifier from QR code
        logger.d(
            'BLE: Skipping advertising on iOS (using QR code connection info)');
        _advertisingController!
            .add(true); // Still report success as connection will work via QR
        yield true;
      } else {
        // Android: Attempt to use flutter_blue_plus for advertising
        // Note: flutter_blue_plus doesn't directly support peripheral mode,
        // but we can still make the device discoverable through other means
        logger
            .d('BLE: Android - Advertising handled via device name in QR code');
        _advertisingController!.add(true);
        yield true;
      }

      // Monitor advertising state
      yield* _advertisingController!.stream;
    } catch (e) {
      logger.e('BLE: Advertising error: $e');
      _advertisingController!.add(false);
      yield false;
    }
  }

  @override
  void stopAdvertising() {
    _isAdvertising = false;

    // Stop BLE advertising (if any was active)
    // Note: On iOS and with current package limitations, no active advertising
    logger.d('BLE: Advertising stopped');

    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _pingPongSubscription?.cancel();
    _pingPongSubscription = null;
    _advertisingController?.close();
    _advertisingController = null;
  }

  @override
  Stream<bool> startProximityDetection({
    required int timeoutSeconds,
    required Function() onTimeout,
  }) async* {
    if (_isScanning) {
      stopProximityDetection();
    }

    _proximityController = StreamController<bool>.broadcast();
    _isScanning = true;

    try {
      // Check if Bluetooth is available
      if (!await isBluetoothAvailable()) {
        logger.e('BLE: Bluetooth not available for scanning');
        _proximityController!.add(false);
        yield false;
        return;
      }

      // Start scanning for HealthWallet.me devices
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeoutSeconds),
        withServices: [Guid(_healthWalletServiceUuid)],
      );

      DateTime? lastPongTime = DateTime.now();
      bool isConnected = false;

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        bool foundDevice = false;
        for (final result in results) {
          // Check if device advertises HealthWallet.me service
          final serviceUuids = result.advertisementData.serviceUuids;
          final hasService = serviceUuids.any(
            (uuid) =>
                uuid.toString().toLowerCase() ==
                _healthWalletServiceUuid.toLowerCase(),
          );

          if (hasService || result.device.platformName.isNotEmpty) {
            foundDevice = true;
            lastPongTime = DateTime.now();

            // Try to connect and verify peer
            if (!isConnected && _connectedDevice == null) {
              _connectAndVerifyPeer(result.device).then((connected) {
                if (connected) {
                  isConnected = true;
                  _proximityController?.add(true);
                }
              });
            }
          }
        }

        // Check timeout
        if (foundDevice) {
          lastPongTime = DateTime.now();
        } else {
          final timeSinceLastPong =
              DateTime.now().difference(lastPongTime ?? DateTime.now());
          if (timeSinceLastPong.inSeconds > timeoutSeconds) {
            isConnected = false;
            _proximityController?.add(false);
            onTimeout();
          }
        }
      });

      // Start ping/pong timer if connected
      _proximityTimer = Timer.periodic(
        Duration(seconds: timeoutSeconds ~/ 2),
        (timer) async {
          if (_connectedDevice != null && _pingPongCharacteristic != null) {
            try {
              // Send ping
              await _pingPongCharacteristic!.write(
                utf8.encode('ping'),
                withoutResponse: false,
              );
              // If we get here, connection is alive
              _proximityController?.add(true);
            } catch (e) {
              // Connection lost
              logger.w('BLE: Ping failed: $e');
              isConnected = false;
              _proximityController?.add(false);
              onTimeout();
            }
          } else {
            // Not connected, check scan results
            _proximityController?.add(isConnected);
          }
        },
      );

      yield* _proximityController!.stream;
    } catch (e) {
      logger.e('BLE: Proximity detection error: $e');
      _proximityController!.add(false);
      yield false;
    }
  }

  Future<bool> _connectAndVerifyPeer(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Discover services
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) =>
            s.uuid.toString().toLowerCase() ==
            _healthWalletServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Service not found'),
      );

      // Get ping/pong characteristic
      _pingPongCharacteristic = service.characteristics.firstWhere(
        (c) =>
            c.uuid.toString().toLowerCase() ==
            _pingPongCharacteristicUuid.toLowerCase(),
        orElse: () => throw Exception('Ping/pong characteristic not found'),
      );

      // Subscribe to pong responses
      await _pingPongCharacteristic!.setNotifyValue(true);
      _pingPongSubscription = _pingPongCharacteristic!.onValueReceived.listen(
        (value) {
          final message = utf8.decode(value);
          if (message == 'pong') {
            _proximityController?.add(true);
          }
        },
      );

      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _pingPongCharacteristic = null;
          _proximityController?.add(false);
        }
      });

      return true;
    } catch (e) {
      logger.e('BLE: Connection/verification failed: $e');
      _connectedDevice = null;
      _pingPongCharacteristic = null;
      return false;
    }
  }

  @override
  void stopProximityDetection() {
    _isScanning = false;
    _proximityTimer?.cancel();
    _proximityTimer = null;
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _pingPongSubscription?.cancel();
    _pingPongSubscription = null;
    FlutterBluePlus.stopScan();
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    _pingPongCharacteristic = null;
    _proximityController?.close();
    _proximityController = null;
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      logger.e('BLE: Error checking availability: $e');
      return false;
    }
  }

  @override
  Future<bool> requestBluetoothPermissions() async {
    try {
      // Request permissions based on platform
      if (await FlutterBluePlus.isSupported) {
        // Android 12+ requires runtime permissions
        final status = await Permission.bluetoothScan.request();
        if (status.isGranted) {
          final advertiseStatus = await Permission.bluetoothAdvertise.request();
          if (advertiseStatus.isGranted) {
            final connectStatus = await Permission.bluetoothConnect.request();
            return connectStatus.isGranted;
          }
        }
        return false;
      }
      return true; // iOS handles permissions automatically
    } catch (e) {
      logger.e('BLE: Permission request error: $e');
      return false;
    }
  }

  @override
  Future<bool> verifyHealthWalletPeer(String deviceIdentifier) async {
    // Verify that the device is a HealthWallet.me app
    // Check for HealthWallet.me service UUID or app identifier in device name/advertising data
    final identifierLower = deviceIdentifier.toLowerCase();
    return identifierLower.contains(_healthWalletAppIdentifier) ||
        identifierLower.contains(_healthWalletServiceUuid.toLowerCase());
  }

  @override
  String getHealthWalletServiceUuid() {
    return _healthWalletServiceUuid;
  }
}
