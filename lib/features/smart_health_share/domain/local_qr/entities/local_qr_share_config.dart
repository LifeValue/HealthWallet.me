/// Configuration for LocalQR Code peer-to-peer sharing
/// No issuer required - direct HealthWallet.me app-to-app exchange
class LocalQRShareConfig {
  /// Whether time-based expiration is enabled
  final bool timeBasedExpiration;

  /// Whether Bluetooth proximity is enabled
  final bool bluetoothProximity;

  /// Expiration duration in minutes (default: 15 minutes)
  final int expirationMinutes;

  /// Bluetooth proximity timeout in seconds (how long to wait for ping response)
  final int proximityTimeoutSeconds;

  const LocalQRShareConfig({
    this.timeBasedExpiration = true,
    this.bluetoothProximity = false,
    this.expirationMinutes = 15,
    this.proximityTimeoutSeconds = 5,
  });

  /// Default time-based only configuration (15-minute timer)
  static const LocalQRShareConfig defaultTimeBased = LocalQRShareConfig(
    timeBasedExpiration: true,
    bluetoothProximity: false,
    expirationMinutes: 15,
  );

  /// Default time and location-based configuration (15-minute timer + Bluetooth)
  static const LocalQRShareConfig defaultTimeAndLocation = LocalQRShareConfig(
    timeBasedExpiration: true,
    bluetoothProximity: true,
    expirationMinutes: 15,
    proximityTimeoutSeconds: 5,
  );

  /// Create a time-based only configuration (15-minute timer)
  factory LocalQRShareConfig.timeBasedOnly() {
    return defaultTimeBased;
  }

  /// Create a time and location-based configuration (15-minute timer + Bluetooth)
  factory LocalQRShareConfig.timeAndLocationBased() {
    return defaultTimeAndLocation;
  }
}

