import 'package:health_wallet/features/records/domain/entity/i_fhir_resource.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/entities/shc_receive_result.dart';

/// Repository for receiving/importing SMART Health Cards
abstract class ReceiveRepository {
  /// Import a SMART Health Card from QR code data
  Future<SHCReceiveResult> importHealthCard(String qrData);

  /// Import LocalQR peer-to-peer health card and return resources without storing
  /// Returns resources list and expiration information
  Future<LocalQRReceiveResult> importHealthCardForLocalQR(String qrData);

  /// Import LocalQR peer-to-peer health card from bundle directly (for BLE transfer)
  /// Returns resources list and expiration information
  Future<LocalQRReceiveResult> importBundleForLocalQR({
    required Map<String, dynamic> bundle,
    required DateTime expiresAt,
  });
}

/// Result of importing LocalQR peer-to-peer health card
class LocalQRReceiveResult {
  final List<IFhirResource> resources;
  final DateTime expiresAt;
  final bool success;
  final String? errorMessage;

  LocalQRReceiveResult({
    required this.resources,
    required this.expiresAt,
    required this.success,
    this.errorMessage,
  });

  factory LocalQRReceiveResult.success({
    required List<IFhirResource> resources,
    required DateTime expiresAt,
  }) {
    return LocalQRReceiveResult(
      resources: resources,
      expiresAt: expiresAt,
      success: true,
    );
  }

  factory LocalQRReceiveResult.failure(String errorMessage) {
    return LocalQRReceiveResult(
      resources: [],
      expiresAt: DateTime.now(),
      success: false,
      errorMessage: errorMessage,
    );
  }
}

