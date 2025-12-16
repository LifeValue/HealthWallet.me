import 'package:health_wallet/features/smart_health_share/domain/local_qr/entities/local_qr_share_config.dart';
import 'package:health_wallet/features/smart_health_share/domain/local_qr/entities/local_qr_share_session.dart';

/// Repository for LocalQR Code peer-to-peer sharing
/// No issuer required - direct HealthWallet.me app-to-app exchange via Bluetooth/proximity
abstract class LocalQRShareRepository {
  /// Generate a LocalQR Code for peer-to-peer sharing
  /// QR code contains FHIR bundle data without issuer verification
  Future<LocalQRShareSession> generateLocalQRCode({
    required List<String> resourceIds,
    required LocalQRShareConfig config,
    String? sourceId,
  });

  /// Stop an active LocalQR sharing session
  Future<void> stopSession(LocalQRShareSession session);

  /// Get active session (if any)
  LocalQRShareSession? getActiveSession();

  /// Verify if the peer device is a HealthWallet.me app
  /// Used for Bluetooth/proximity exchange validation
  Future<bool> verifyPeerDevice(String deviceIdentifier);

  /// Get FHIR bundle for BLE transfer by session ID
  /// Returns null if session not found or not in BLE mode
  Map<String, dynamic>? getBleDataForSession(String sessionId);
}

