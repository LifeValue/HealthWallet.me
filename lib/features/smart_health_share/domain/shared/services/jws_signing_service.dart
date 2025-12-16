import 'package:jose/jose.dart';

/// Service for creating and verifying JWS tokens for SMART Health Cards
abstract class JWSSigningService {
  /// Create and sign a JWT with FHIR bundle payload
  /// Returns compact serialization JWS string
  Future<String> signJwt({
    required Map<String, dynamic> payload,
    required String issuer,
    required int nbf,
    required String kid,
  });

  /// Verify a JWT signature using a public key
  Future<bool> verifyJwt({
    required String compactJws,
    required JsonWebKey publicKey,
  });

  /// Parse JWT and extract payload (without verification)
  Map<String, dynamic> parseJwtPayload(String compactJws);
}


