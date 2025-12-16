# Progress - SMART Health Share Foundation

## Current Status

**Status**: Not Started - Planning Complete

The SMART Health Cards/Links foundation is fully specified, documented, and ready for implementation. All technical specifications and architecture decisions are complete.

## What Works

- **Specification**: Complete technical specification documented
- **Architecture**: Foundation architecture design with database schema
- **Memory Bank**: Complete memory bank structure with all core files

## What Needs to Be Built

The foundation implementation requires:

### Core Infrastructure
- Database tables (UserKeys, TrustedIssuers)
- Cryptographic key management (ES256 key generation and storage)
- Secure storage integration (flutter_secure_storage)

### SMART Health Card Processing
- JWS signing service (ES256 algorithm)
- SMART Health Card encoder (JWT structure, DEFLATE compression, SHC prefix)
- SMART Health Card decoder (parsing, decompression, validation)
- FHIR bundle builder service

### QR Code Integration
- QR code generation for SMART Health Cards
- QR code scanning and parsing
- SHLink URL parsing and access

### Trust Management
- Trust repository and service
- Issuer management (add/remove trusted issuers)
- Signature verification

### Share/Receive Flows
- Share flow UI and logic (create bundles, sign, generate QR)
- Receive flow UI and logic (scan, parse, verify, import)
- Trust management UI

## Foundation Requirements

### Specification Compliance

The foundation must comply with:
- **HL7 FHIR Implementation Guide**: SMART Health Cards and Links IG (Version 1.0.0 - STU 1)
- **SMART Health Cards Framework**: Technical protocol specification
- **ES256 Algorithm**: REQUIRED (ECDSA P-256) - EdDSA/Ed25519 is NOT supported
- **JWT Structure**: Required header fields (`alg: ES256`, `typ: JWT`, `zip: DEF`, `kid`)
- **Verifiable Credential Structure**: Required payload structure with `vc.type` and `fhirBundle`

### Key Technical Requirements

1. **Cryptographic Operations**:
   - ES256 (ECDSA P-256) key generation
   - JWS signing and verification
   - Secure key storage (device keychain/keystore)

2. **Data Encoding**:
   - Base64url encoding (RFC 4648)
   - DEFLATE compression (RFC 1951)
   - SHC prefix handling (`shc:/`)
   - Numeric encoding for QR codes

3. **FHIR Bundle Structure**:
   - Bundle type: collection
   - Proper resource references
   - Patient resource inclusion
   - FHIR version 4.0.1

4. **Trust Model**:
   - Three-party model (Issuer → Holder → Verifier)
   - Explicit trust management (no automatic trust)
   - Signature verification against trusted issuers

## Implementation Focus

**Current Focus**: Foundation implementation only
- Build the technical capability to create and verify SMART Health Cards/Links
- Ensure specification compliance for interoperability
- Enable future use cases (like "Kill the Clipboard") to be built on top

**Future Work**: Use cases will be built on top of this foundation
- "Kill the Clipboard" workflow
- Other applications using SMART Health Cards/Links

## Known Considerations

1. **JWS Library**: Need to verify ES256 support in available Dart packages
2. **QR Code Size Limits**: Large bundles may require SHLink fallback
3. **Platform Testing**: Secure storage needs testing on both iOS and Android
4. **Specification Compliance**: Must follow HL7 IG exactly for interoperability

## Next Steps When Implementation Begins

1. Review memory bank documentation completely
2. Set up development environment with required dependencies
3. Start with core infrastructure (database and crypto)
4. Implement SMART Health Card processing
5. Add QR code integration
6. Implement trust management
7. Build share/receive flows
8. Test specification compliance
