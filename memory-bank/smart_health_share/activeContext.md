# Active Context - SMART Health Share Foundation

## Current Work Focus

This document tracks the current focus of development for the SMART Health Cards/Links foundation in HealthWallet.me.

### Current Status

**Status**: Planning Phase - Not Yet Implemented

The SMART Health Cards/Links foundation is fully specified and documented but has not yet been implemented. All technical specifications and architecture decisions are complete and ready for development.

### Recent Changes

- **Memory Bank Created**: Complete memory bank structure established with all core files
- **Specification Documented**: Full technical specification documented including database schema and services
- **Foundation Focus**: Documentation updated to focus exclusively on foundation (technology/specification), clearly separated from use cases

### Next Steps

When implementation begins:

1. **Core Infrastructure**: Database tables (UserKeys, TrustedIssuers) and cryptographic key management
2. **SMART Health Card Processing**: JWS signing, encoding/decoding, FHIR bundle building
3. **QR Code Integration**: QR code generation and scanning for SMART Health Cards
4. **Trust Management**: Issuer management and signature verification
5. **Share/Receive Flows**: UI and workflows for creating and importing SMART Health Cards

**Note**: Use cases (like "Kill the Clipboard") will be built on top of this foundation after it's complete.

### Active Decisions & Considerations

#### Key Technical Decisions

1. **Cryptographic Algorithm**: ES256 (ECDSA P-256)
   - **Rationale**: REQUIRED by SMART Health Cards specification for interoperability
   - **Storage**: Private keys in `flutter_secure_storage`, public keys in Drift

2. **Database Strategy**: Add 2 new Drift tables for foundation
   - **UserKeys**: Single row for wallet public key
   - **TrustedIssuers**: Store issuer public keys for verification

3. **Existing Table Reuse**: 
   - **FhirResource**: Continue using existing table (stores JSON in `resourceRaw`)
   - **Sources**: Use existing table for tracking data sources

4. **QR Code Library**: Extend existing `mobile_scanner` package
   - Already in use for FastenHealth sync
   - Add SMART Health Card detection (SHC prefix)
   - Add SHLink URL detection

5. **Architecture Pattern**: Follow existing clean architecture
   - Data layer: Drift tables, repositories
   - Domain layer: Services, repository interfaces
   - Presentation layer: BLoC, pages, widgets

#### Dependencies on Existing Features

- **QR Scanner**: `lib/features/sync/presentation/widgets/qr_scanner_widget.dart`
- **FHIR Storage**: `lib/features/sync/data/data_source/local/tables/fhir_resource_table.dart`
- **Database**: `lib/core/data/local/app_database.dart`
- **Navigation**: `lib/core/navigation/app_router.dart`
- **BLoC Pattern**: Follow existing BLoC implementations

#### Important Patterns and Preferences

1. **Service Layer**: Domain services handle business logic (crypto, encoding, verification)
2. **Repository Pattern**: Abstract repositories in domain, implementations in data layer
3. **BLoC Events/States**: Use freezed for type-safe events and states
4. **Error Handling**: Clear error messages, graceful degradation
5. **Testing**: Unit tests for crypto operations, integration tests for flows

### Learnings and Project Insights

1. **SMART Health Cards**: Use JWS (JSON Web Signature) format with compressed payloads
2. **SHLink**: For large datasets, use URLs instead of embedding in QR codes
3. **Trust Model**: Users must explicitly trust issuers - no automatic trust
4. **Key Management**: Private keys never leave device - critical for security
5. **FHIR Bundles**: Must include proper references between resources
6. **Specification Compliance**: Must follow HL7 SMART Health Cards/Links IG exactly for interoperability

### Blockers

**Current**: None - Foundation is ready for implementation

**Potential Future Considerations**:
- JWS/COSE library selection for Dart (need to verify ES256 support)
- Large bundle size limitations (may require SHLink fallback)
- Platform-specific secure storage testing (iOS/Android)

### Questions to Resolve During Implementation

1. Which JWS/COSE library to use? (Need to verify ES256 support)
2. Maximum QR code payload size? (Determine SHLink threshold)
3. Trust management UI flow? (Manual entry vs. JWKS URL fetching)

### Reference Implementations

**SMART Health Check-in Demo** (Related but Different Protocol):
- **Repository**: [github.com/jmandel/smart-health-checkin-demo](https://github.com/jmandel/smart-health-checkin-demo)
- **Live Demo**: [joshuamandel.com/smart-health-checkin-demo](https://joshuamandel.com/smart-health-checkin-demo)
- **Useful For**: Reference implementation of SMART Health Cards/SHLink handling, security patterns, protocol structures
- **Note**: This is web-based check-in protocol, different from our QR-based foundation, but shares SMART Health Cards standards
