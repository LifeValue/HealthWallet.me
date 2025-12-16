import 'package:health_wallet/features/smart_health_share/domain/shared/entities/shc_share_result.dart';

/// Repository for sharing SMART Health Cards
abstract class ShareRepository {
  /// Generate a SMART Health Card QR code from selected resources
  Future<SHCShareResult> generateHealthCard({
    required List<String> resourceIds,
    required String issuerUrl,
    String? sourceId,
  });
}


