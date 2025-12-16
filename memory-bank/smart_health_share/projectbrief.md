# Project Brief - SMART Health Share Foundation

## Core Requirements & Goals

This document outlines the foundational requirements for implementing SMART Health Cards and SMART Health Links in HealthWallet.me. This foundation enables backend-free, patient-controlled health data sharing via QR codes using SMART Health Cards and SHLink standards.

## Foundation vs. Use Case

### SMART Health Cards/Links = Technology/Standard (Foundation)

**What**: A technical specification/standard (like HTTP, JSON, or PDF)

**Purpose**: Defines how to encode, sign, and share health data securely

**Scope**: Technical protocol — format, encoding, cryptography, verification

**Key characteristics**:
- JWT/JWS format with ES256 signatures
- FHIR R4 bundle structure
- QR code encoding (`shc:/` prefix)
- Verifiable Credential structure
- Can be used for many different purposes

**What we're building now**: Implement SMART Health Cards/Links specification compliance
- Build the technical capability: generate QR codes, verify signatures, parse SHC/SHLink
- This is technology/standard compliance

**Concrete Examples - What It Actually IS:**
- A JWT token with specific header fields (`alg: ES256`, `typ: JWT`, `zip: DEF`, `kid`)
- A FHIR Bundle wrapped in a Verifiable Credential structure (`vc.type`, `credentialSubject.fhirBundle`)
- A QR code string starting with `shc:/` containing numeric-encoded health data
- Cryptographic signature verification using ES256 (ECDSA P-256) algorithm
- **It's the DATA FORMAT and PROTOCOL** - defines HOW to structure, encode, sign, and verify health data
- **Example**: A function that takes FHIR resources and returns a signed QR code string

### "Kill the Clipboard" = Use Case/Application (Built on Foundation)

**What**: A specific healthcare workflow problem being solved

**Purpose**: Eliminate paper clipboard forms at clinic visits

**Scope**: Application/workflow — how patients share data with providers during check-in

**Key characteristics**:
- Patients share health records with providers via QR code
- Eliminates repetitive form-filling
- Happens during clinic check-in
- Uses SMART Health Cards/Links as the underlying technology

**What we'll build next**: Build the workflow on top of the foundation
- Patient shares QR code at clinic check-in
- Add clinic-specific features: provider scanning, form population, etc.
- This is applying the foundation to solve a specific problem

**Concrete Examples - What It Actually IS:**
- Patient arrives at clinic → shows QR code on phone → provider scans it
- Provider's system reads health data from QR code → auto-populates patient intake forms
- Eliminates patient filling out paper forms manually at every visit
- **It's the WORKFLOW and APPLICATION** - defines WHAT PROBLEM to solve and HOW users interact
- **Example**: A clinic check-in screen that scans QR codes and fills forms automatically

**The Key Difference:**
- **Foundation**: "Here's how to encode and sign health data in a QR code" (the technical capability)
- **Use Case**: "Here's how patients use that QR code at clinic check-in to skip forms" (the user workflow)

**Note**: This foundation enables the ["Kill the Clipboard" initiative](https://www.cms.gov/health-tech-ecosystem/early-adopters/kill-the-clipboard) and other future use cases, but those are separate implementations that will be built on top of this foundation.

### What Are SMART Health Cards?

SMART Health Cards are digital credentials that enable individuals to receive, store, and share their health information in a tamper-proof and verifiable digital form. They provide a standardized way to represent clinical information (like vaccination records, lab results) that can be easily shared using QR codes.

#### Background & Context

**Problem They Solve**:
- Paper medical records are easily lost or damaged
- Difficult to authenticate paper records
- Records often not available when needed
- Fragmented health data across multiple providers
- Lack of interoperability between health systems

**Solution**:
SMART Health Cards provide a digital version of clinical information that:
- Can be kept readily available (on phone, printed, or in wallet app)
- Can be easily shared when needed (via QR code scan)
- Is cryptographically signed to prevent tampering
- Is verifiable without contacting the original issuer
- Works across organizational and jurisdictional boundaries

**Who Uses Them**:
- **Issuers**: Healthcare providers, labs, pharmacies, public health departments
- **Holders**: Patients, individuals storing their health records
- **Verifiers**: Clinics, employers, schools, travel authorities, other healthcare providers

#### Official Standards

SMART Health Cards are defined by two official specifications:

1. **HL7 FHIR Implementation Guide**: [SMART Health Cards and Links IG](https://build.fhir.org/ig/HL7/smart-health-cards-and-links/)
   - Published by HL7 International / FHIR Infrastructure
   - Version: 1.0.0 - STU 1
   - Official FHIR-based standard

2. **SMART Health Cards Framework**: [spec.smarthealth.cards](https://spec.smarthealth.cards/)
   - Technical protocol specification
   - Current version: 1.4.0
   - Defines JWT structure, encoding, and verification

#### Technical Foundation

SMART Health Cards are built on international open standards:

- **FHIR R4**: Health data format (HL7 standard)
- **JWT/JWS**: JSON Web Token/Signature (IETF RFC 7519/7515)
- **Verifiable Credentials**: W3C standard for digital credentials
- **Cryptographic Signatures**: ES256 (ECDSA P-256) algorithm - REQUIRED

#### JWT Structure

SMART Health Cards are encoded as Compact Serialization JSON Web Signatures (JWS) - essentially a JWT with three parts: `[Header].[Payload].[Signature]`

**Required JWT Header**:
```json
{
  "alg": "ES256",
  "typ": "JWT",
  "zip": "DEF",
  "kid": "base64url_encoded_SHA256_JWK_thumbprint"
}
```

**Required JWT Payload**:
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

**Encoding as QR Code**:
When encoded as a QR code, the JWT is:
1. Compressed using DEFLATE (RFC 1951)
2. Encoded using numeric encoding (pairs of digits)
3. Prefixed with `shc:/`

Example QR Code String: `shc:/567629095109506...`

#### Key Concepts

**Trust Model**: Three-party model (Issuer → Holder → Verifier)
- **Issuer**: Creates and signs the card (clinic, lab, pharmacy)
- **Holder**: Stores the card (patient, wallet app)
- **Verifier**: Checks the card (clinic, employer, travel authority)

**Privacy & Security**:
- Data minimization: Only include necessary information
- Granular sharing: Share specific records, not entire history
- No backend required: Cards work offline
- User control: Holder decides what to share
- Cryptographic signatures: Tamper-proof (ES256 algorithm)
- Verifiable: Can verify without contacting issuer

### Key Goals

1. **SMART Health Card Compliance**: Support the SMART Health Cards specification for encoding FHIR resources in QR codes with cryptographic signatures.

2. **SHLink Support**: Support SMART Health Links (SHLink) for sharing larger datasets via URLs when QR codes are insufficient.

3. **Cryptographic Security**: Implement ES256 (ECDSA P-256) based signing and verification to ensure data integrity and authenticity.

4. **Trust Management**: Allow users to manage trusted issuers and verify incoming health data signatures.

5. **Backend-Free Sharing**: Implement a fully offline, patient-controlled sharing mechanism that doesn't require a central server.

6. **Seamless Integration**: Integrate with existing HealthWallet.me features (scan, records, sync) while maintaining clean architecture patterns.

### Scope

**Current Phase - Foundation (In Scope):**
- **Building**: SMART Health Cards and SMART Health Links foundation (the technology)
- QR code generation for SMART Health Cards
- QR code scanning and parsing
- SMART Health Links client-side support (parsing and access)
- FHIR bundle creation from selected resources
- Cryptographic signing with ES256 (ECDSA P-256)
- Signature verification for incoming data
- Trusted issuer management
- Integration with existing Drift database
- UI for share/receive flows
- **Critical**: Standard-compliant, interoperable foundation that enables future use cases

**Out of Scope (Future Enhancements):**
- Chunked QR code support for very large bundles (can be added later)
- Automatic JWKS endpoint fetching for trust management
- SHLink server implementation (only client-side support)
- Cross-device sync of keys (keys remain device-local)
- Clinic-side scanning/verification systems (we're building wallet, not verifier infrastructure)

**Future Use Cases (Post-Foundation):**
The foundation being built now will enable various use cases, including:
- "Kill the Clipboard" - Patients share records via QR codes at clinic visits
- Family-based sharing
- Peer-to-peer sharing
- Other applications built on SMART Health Cards/Links standards

**Architecture Principle**: Build for scalability and interoperability. The foundation must be standard-compliant and extensible to support future enhancements without requiring architectural changes.

### Success Criteria

1. Users can generate QR codes containing their health data (SMART Health Cards compliant)
2. Users can scan QR codes and import health data with signature verification
3. All cryptographic operations work securely with keys stored in device keychain
4. Trust management allows users to verify data sources
5. Feature integrates seamlessly with existing app architecture
6. Implementation follows SMART Health Cards specification exactly

### References

- [HL7 FHIR Implementation Guide - SMART Health Cards and Links](https://build.fhir.org/ig/HL7/smart-health-cards-and-links/) - Official HL7 standard (Version 1.0.0 - STU 1)
- [SMART Health Cards Specification](https://spec.smarthealth.cards/) - Technical protocol specification
- [SMART Health Links Specification](https://spec.smarthealth.cards/links/)
- [FHIR R4 Specification](https://www.hl7.org/fhir/R4/)
- [JWS (JSON Web Signature) RFC 7515](https://tools.ietf.org/html/rfc7515)
