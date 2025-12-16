import 'package:jose/jose.dart';

/// Service for managing ES256 cryptographic keys for SMART Health Cards
abstract class KeyManagementService {
  /// Get or generate the wallet's key pair
  /// Returns the public key in JWK format
  Future<JsonWebKey> getOrGenerateKeyPair();

  /// Get the public key (if exists)
  Future<JsonWebKey?> getPublicKey();

  /// Get the private key for signing operations
  Future<JsonWebKey?> getPrivateKey();

  /// Generate JWK thumbprint for kid header
  Future<String> generateKid(JsonWebKey publicKey);
}


