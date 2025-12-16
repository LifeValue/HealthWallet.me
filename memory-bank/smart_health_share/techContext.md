# Tech Context - SMART Health Share Foundation

## Technologies & Dependencies

This document lists the key technologies and specifications required for implementing the SMART Health Cards/Links foundation in HealthWallet.me.

### Core Technologies

- **Flutter**: UI framework (existing)
- **Dart**: Programming language (existing)
- **Drift**: Local SQLite database (existing)
- **flutter_secure_storage**: Secure key storage (required for foundation)

### Existing Dependencies (Reused)

- **`flutter_bloc`**: State management (existing)
- **`get_it` & `injectable`**: Dependency injection (existing)
- **`auto_route`**: Navigation (existing)
- **`drift`**: Local database (existing)
- **`mobile_scanner`**: QR code scanning (existing, will extend)
- **`fhir_r4`**: FHIR resource handling (existing)
- **`freezed`**: Code generation for immutable classes (existing)
- **`json_serializable`**: JSON serialization (existing)

### Technical Constraints

#### Platform Support

- **iOS**: 13+ (same as main app)
- **Android**: 6.0+ (same as main app)
- **Keychain/Keystore**: Must support secure storage on both platforms

#### Security Constraints

1. **Private Keys**: Never leave device, stored only in `flutter_secure_storage`
2. **Key Generation**: Must use cryptographically secure random number generator
3. **Signature Verification**: Must verify all incoming data before import
4. **No Automatic Trust**: Users must explicitly trust issuers

#### Performance Constraints

1. **QR Code Size**: Limited by QR code capacity (~3KB for version 40)
2. **Bundle Size**: Large bundles may require SHLink instead of direct QR
3. **Key Operations**: ES256 operations should be fast (< 100ms)
4. **Database Queries**: Indexed queries for performance

#### Offline Support

- **Fully Offline**: All operations work without internet
- **No Backend Required**: No server needed for sharing/receiving
- **Optional JWKS**: JWKS fetching is optional enhancement (requires internet)

### Standards & Specifications

#### SMART Health Cards Specification

- **HL7 FHIR Implementation Guide**: [SMART Health Cards and Links IG](https://build.fhir.org/ig/HL7/smart-health-cards-and-links/) - Version 1.0.0 - STU 1
- **Technical Specification**: [SMART Health Cards Framework](https://spec.smarthealth.cards/)
- **Key Requirements**:
  - Algorithm: **ES256** (ECDSA P-256) - REQUIRED by specification
  - JWS (JSON Web Signature) format
  - Base64url encoding
  - DEFLATE compression (RFC 1951)
  - SHC prefix: `shc:/`
  - Verifiable Credential structure
  - JWT header must include: `alg: ES256`, `typ: JWT`, `zip: DEF`, `kid`

#### SMART Health Links Specification

- **Version**: v1.0.0 (or latest)
- **URL**: https://spec.smarthealth.cards/links/
- **Key Requirements**:
  - URL-based sharing for large datasets
  - Same JWS format as SHC
  - URL structure: `https://.../shlink/...`

#### FHIR R4 Specification

- **Version**: R4 (existing in project)
- **URL**: https://www.hl7.org/fhir/R4/
- **Key Resources Used**:
  - Bundle (for packaging resources)
  - Patient (for patient information)
  - Various resource types (Immunization, Observation, etc.)

#### JWS (JSON Web Signature) RFC 7515

- **URL**: https://tools.ietf.org/html/rfc7515
- **Key Requirements**:
  - JWT structure: header.payload.signature
  - Base64url encoding
  - Algorithm: ES256 (ECDSA P-256) - REQUIRED for SMART Health Cards
  - Header: `{"alg":"ES256","typ":"JWT","zip":"DEF","kid":"..."}`

#### ES256 Signature Algorithm (ECDSA P-256)

- **Standard**: RFC 7518 (JSON Web Algorithms)
- **Algorithm**: ECDSA using P-256 curve and SHA-256
- **Key Size**: P-256 curve (32 bytes private key, 65 bytes uncompressed public key)
- **Signature Size**: 64 bytes (r and s values, each 32 bytes)
- **Performance**: Fast signing and verification
- **Note**: This is REQUIRED by SMART Health Cards specification - EdDSA/Ed25519 is NOT supported

#### SMART Health Cards JWT Structure

**Required Header**:
```json
{
  "alg": "ES256",
  "typ": "JWT",
  "zip": "DEF",
  "kid": "base64url_encoded_SHA256_JWK_thumbprint"
}
```

**Required Payload**:
```json
{
  "iss": "https://issuer.example.com",
  "nbf": 1234567890,
  "vc": {
    "type": [
      "https://smarthealth.cards#health-card",
      "VerifiableCredential"
    ],
    "credentialSubject": {
      "fhirVersion": "4.0.1",
      "fhirBundle": {
        "resourceType": "Bundle",
        "type": "collection",
        "entry": [...]
      }
    }
  }
}
```

**Reference**: [SMART Health Cards Specification](https://spec.smarthealth.cards/#signing-health-cards)

### Storage Architecture

#### Secure Storage (flutter_secure_storage)

**Location**: Device keychain (iOS) / Keystore (Android)

**Data Stored**:
- ES256 private key (ECDSA P-256, base64 encoded)
- Key: `smart_health_share_private_key`

**Access**: Only through `KeyManagementService`

#### Local Database (Drift/SQLite)

**Tables**:
- `user_keys`: Public key storage
- `trusted_issuers`: Issuer public keys

**Existing Tables Used**:
- `fhir_resource`: FHIR resource storage
- `sources`: Source tracking

### Design Patterns

1. **Repository Pattern**: Abstract repositories in domain, implementations in data layer
2. **Service Layer Pattern**: Domain services encapsulate business logic
3. **BLoC Pattern**: State management using flutter_bloc
4. **Dependency Injection**: Using `get_it` and `injectable`
5. **Table-Driven Design**: Drift tables define data structure

### Integration Points

1. **Existing QR Scanner**: Extend `QRScannerWidget` to detect SMART Health Cards
2. **Existing Database**: Add new tables to `AppDatabase`, reuse `FhirResource` table
3. **Existing Navigation**: Add routes to `app_router.dart`
4. **Existing Records**: Use `FhirResourceDatasource` for resource selection
5. **Existing Sources**: Use `Sources` table for source tracking
