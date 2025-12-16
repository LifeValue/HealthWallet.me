/// Service for managing Bluetooth proximity detection for LocalQR Code
/// Peer-to-peer exchange between HealthWallet.me apps
abstract class LocalQRProximityService {
  /// Start advertising Bluetooth Low Energy (BLE) service
  /// Advertises HealthWallet.me app identifier for peer detection
  /// Returns a stream that emits connection state changes
  Stream<bool> startAdvertising({
    required String deviceName,
    required Function() onDisconnected,
  });

  /// Stop advertising
  void stopAdvertising();

  /// Start scanning for HealthWallet.me peer devices
  /// Responds to ping with pong to verify proximity
  Stream<bool> startProximityDetection({
    required int timeoutSeconds,
    required Function() onTimeout,
  });

  /// Stop proximity detection
  void stopProximityDetection();

  /// Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable();

  /// Request Bluetooth permissions if needed
  Future<bool> requestBluetoothPermissions();

  /// Verify if discovered device is a HealthWallet.me app
  /// Checks for HealthWallet.me service UUID or app identifier
  Future<bool> verifyHealthWalletPeer(String deviceIdentifier);

  /// Get the HealthWallet.me BLE service UUID for peer detection
  String getHealthWalletServiceUuid();
}

