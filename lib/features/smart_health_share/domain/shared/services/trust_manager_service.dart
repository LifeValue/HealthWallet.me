import 'package:jose/jose.dart';
import 'package:health_wallet/features/smart_health_share/domain/shared/repositories/trust_repository.dart';

/// Service for managing trust and verifying signatures
abstract class TrustManagerService {
  /// Add a trusted issuer
  Future<void> addTrustedIssuer({
    required String issuerId,
    required String name,
    required JsonWebKey publicKey,
    required String source,
  });

  /// Remove a trusted issuer
  Future<void> removeTrustedIssuer(String issuerId);

  /// Get all trusted issuers
  Future<List<TrustedIssuerInfo>> getTrustedIssuers();

  /// Verify a JWT signature against trusted issuers
  /// Returns the issuer ID if verified, null otherwise
  Future<String?> verifySignature({
    required String compactJws,
  });

  /// Extract issuer ID from JWT header
  String? extractIssuerId(String compactJws);
}

class TrustedIssuerInfo {
  final String issuerId;
  final String name;
  final String source;
  final DateTime addedAt;

  TrustedIssuerInfo({
    required this.issuerId,
    required this.name,
    required this.source,
    required this.addedAt,
  });
}


