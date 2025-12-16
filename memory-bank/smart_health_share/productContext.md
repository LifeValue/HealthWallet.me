App must support 16 KB memory page sizes
Status
You won't be able to release app updates
Enforced
Nov 1, 2025
To ensure your app works correctly on the latest versions of Android, Google Play requires all apps targeting Android 15+ to support 16 KB memory page sizes.
From Nov 1, 2025, if your app updates do not support 16 KB memory page sizes, you won't be able to release these updates.

Your latest production release does not support 16 KB memory page sizes.


How to fix
Create a new release that supports 16 KB memory page sizes and publish it to production.
To build your app bundles with 16 KB support, follow our instructions for supporting 16 KB devices.

You can check the latest releases and app bundles to see if a newly uploaded bundle supports 16 KB.

For more information:

Prepare your Play app for devices with 16 KB page sizes
Test your app in a 16 KB environment
Transition to using 16 KB page sizes for Android apps and games using Android Studio
Read the technical requirement announcement

Is this helpful?
Need more time?
If you need more time to update your app, you can request an extension to this deadline. If you request more time, you'll have until May 31, 2026 to update your app.# Product Context - SMART Health Share Foundation

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

## Why This Foundation Exists

SMART Health Cards/Links address critical gaps in patient-controlled health data sharing, enabling secure, interoperable health information exchange without backend dependencies.

### Problem Space

1. **Fragmented Health Records**: Patients have health data scattered across multiple providers, making it difficult to share complete health histories when needed.

2. **Backend Dependency**: Most health data sharing solutions require backend servers, creating privacy concerns and single points of failure.

3. **Lack of Interoperability**: Different health systems use incompatible formats, making data sharing cumbersome.

4. **Trust and Verification**: There's no standard way to verify the authenticity of shared health data.

5. **Emergency Situations**: In emergencies, patients need quick access to share critical health information without internet connectivity.

**The Solution**: SMART Health Cards/Links provide a standardized, cryptographically secure way to encode and share health data via QR codes, enabling offline verification and interoperability across systems.

### Foundation Capabilities

The SMART Health Cards/Links foundation provides:

- **Encoding**: Convert FHIR resources into SMART Health Card format (JWT with Verifiable Credential structure)
- **Signing**: Cryptographically sign health data using ES256 (ECDSA P-256) algorithm
- **QR Code Generation**: Create QR codes containing signed health data
- **Verification**: Verify cryptographic signatures to ensure data authenticity
- **Parsing**: Decode SMART Health Cards and SMART Health Links from QR codes or URLs
- **Trust Management**: Manage trusted issuers for signature verification

### Current Focus: Foundation & Interoperability

**What We're Building Now**:
- Foundation for SMART Health Cards and SMART Health Links
- Patient-side wallet functionality (receiving, storing, displaying, sharing)
- QR code generation and scanning for SMART Health Cards
- Support for SMART Health Links (client-side parsing and access)
- Standard-compliant implementation ensuring interoperability

**What We're NOT Building Now**:
- Clinic-side scanning systems (we're building the wallet, not the verifier infrastructure)
- Backend servers for SHLink hosting
- Clinic check-in workflows (that's a use case built on the foundation)

**Critical Requirements**:
- **Interoperability**: Must comply with official SMART Health Cards/Links specifications to work with any compliant system
- **Standard Compliance**: Foundation must be built correctly to enable future use cases
- **Scalability**: Architecture must support future enhancements

### SMART Health Cards vs SMART Health Links

Both are part of the SMART Health Cards specification but serve different purposes:

#### SMART Health Cards (SHC)

**What They Are**:
- Self-contained digital credentials with health data embedded directly in a QR code
- Data is encoded, compressed, and signed within the QR code itself
- Format: `shc:/` prefix followed by numeric-encoded JWT

**Characteristics**:
- **Self-Contained**: All data is in the QR code - no external data needed
- **Offline Capable**: Can be verified without internet connection
- **Size Limited**: QR codes have capacity limits (~3KB for version 40)
- **Static Data**: Best for information that doesn't change frequently
- **Use Cases**: Vaccination records, test results, insurance cards

**Example**: A QR code containing a COVID-19 vaccination record that can be scanned and verified offline.

#### SMART Health Links (SHLink)

**What They Are**:
- Secure URLs that point to encrypted health information stored remotely
- The link itself is small (can fit in QR code), but data is accessed via URL
- Format: `https://.../shlink/...` or `shlink:/` scheme

**Characteristics**:
- **Cloud-Based**: Data is stored remotely and accessed via URL
- **Online Required**: Requires internet connectivity to retrieve data
- **Larger Datasets**: Can handle much larger bundles than QR codes
- **Dynamic Data**: Can point to data that updates over time
- **Additional Security**: Often protected by passcodes, expiration dates
- **Use Cases**: Complete immunization histories, comprehensive lab results, large medical records

**Example**: A QR code containing a URL that, when accessed, retrieves a complete immunization history from a secure server.

#### Key Differences Summary

| Aspect | SMART Health Cards (SHC) | SMART Health Links (SHLink) |
|--------|-------------------------|----------------------------|
| **Data Location** | Embedded in QR code | Stored remotely, accessed via URL |
| **Internet Required** | No (offline capable) | Yes (to retrieve data) |
| **Data Size** | Limited (~3KB max) | Unlimited (can be very large) |
| **Use Case** | Static, concise records | Dynamic, comprehensive records |
| **Verification** | Offline verification | Online verification |
| **Format** | `shc:/` numeric encoding | `https://.../shlink/...` URL |

**When to Use Which**:
- **SMART Health Cards**: Small, static records (single vaccination, test result)
- **SMART Health Links**: Large datasets, frequently updated records, comprehensive histories

### Integration Points

- **Existing QR Scanner**: Extends `lib/features/sync/presentation/widgets/qr_scanner_widget.dart` for SMART Health Card detection
- **FHIR Resources**: Uses existing `FhirResource` table in Drift database
- **Records Feature**: Integrates with records display for preview and selection
- **Navigation**: Adds new routes for share/receive/trust management pages

### References

- [HL7 FHIR Implementation Guide - SMART Health Cards and Links](https://build.fhir.org/ig/HL7/smart-health-cards-and-links/) - Official HL7 standard (Version 1.0.0 - STU 1)
- [SMART Health Cards Specification](https://spec.smarthealth.cards/) - Technical protocol specification
- [CMS "Kill the Clipboard" Initiative](https://www.cms.gov/health-tech-ecosystem/early-adopters/kill-the-clipboard) - CMS Health Technology Ecosystem initiative (use case enabled by foundation)
