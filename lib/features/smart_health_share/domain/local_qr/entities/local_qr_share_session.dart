import 'package:health_wallet/features/smart_health_share/domain/local_qr/entities/local_qr_share_config.dart';

/// Active LocalQR peer-to-peer sharing session
class LocalQRShareSession {
  /// The generated QR code data (peer-to-peer format, no issuer)
  final String qrCodeData;

  /// The raw FHIR bundle data (for direct transfer)
  final Map<String, dynamic> fhirBundle;

  /// Configuration used for this session
  final LocalQRShareConfig config;

  /// When the session was created
  final DateTime createdAt;

  /// When the session expires (if time-based)
  final DateTime? expiresAt;

  /// Whether the session is currently active
  final bool isActive;

  /// Whether Bluetooth proximity is currently connected
  final bool isBluetoothConnected;

  /// Remaining time in seconds until expiration
  final int? remainingSeconds;

  /// BLE transfer progress (0.0 - 1.0)
  final double bleTransferProgress;

  /// Device ID for BLE connection
  final String? deviceId;

  /// Session ID for BLE transfer
  final String? sessionId;

  LocalQRShareSession({
    required this.qrCodeData,
    required this.fhirBundle,
    required this.config,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.isBluetoothConnected = false,
    this.remainingSeconds,
    this.bleTransferProgress = 0.0,
    this.deviceId,
    this.sessionId,
  });

  /// Check if session has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Create a copy with updated state
  LocalQRShareSession copyWith({
    String? qrCodeData,
    Map<String, dynamic>? fhirBundle,
    LocalQRShareConfig? config,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    bool? isBluetoothConnected,
    int? remainingSeconds,
    double? bleTransferProgress,
    String? deviceId,
    String? sessionId,
  }) {
    return LocalQRShareSession(
      qrCodeData: qrCodeData ?? this.qrCodeData,
      fhirBundle: fhirBundle ?? this.fhirBundle,
      config: config ?? this.config,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      isBluetoothConnected: isBluetoothConnected ?? this.isBluetoothConnected,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      bleTransferProgress: bleTransferProgress ?? this.bleTransferProgress,
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

