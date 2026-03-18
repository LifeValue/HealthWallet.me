---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish', 'step-12-complete']
status: 'complete'
completedAt: '2026-03-17'
inputDocuments: ['_bmad-output/project-context.md', 'wp_3/docs/planning/desktop-flutter-implementation.md', 'wp_3/docs/planning/healthwallet-planning.md']
workflowType: 'prd'
documentCounts:
  briefs: 0
  research: 0
  brainstorming: 0
  projectDocs: 2
  projectContext: 1
classification:
  projectType: 'mobile_app_desktop_expansion'
  domain: 'healthcare'
  complexity: 'high'
  projectContext: 'brownfield'
---

# Product Requirements Document - HealthWallet.me

**Author:** LifeValue
**Date:** 2026-03-17

## Executive Summary

HealthWallet.me is a patient-controlled health record management app that aggregates medical data from multiple healthcare providers using FHIR R4 standards. The existing mobile app (iOS/Android) provides document scanning with on-device AI extraction, offline-first storage, biometric security, and P2P proximity sharing.

This PRD defines **Desktop App v1.0** — extending HealthWallet.me to macOS, Windows, and Linux within the same Flutter codebase. The desktop app serves as the mobile app's trusted counterpart: a secure backup hub, an AI processing powerhouse leveraging desktop hardware, and a continuous LWW sync partner. Desktop is not a port — it is a capability multiplier. The phone captures, the desktop processes and stores.

HealthWallet.me never generates medical advice. It extracts, organizes, and displays what doctors wrote — treatment plans, recommendations, lab results. It is a medical data organizer, not a medical advisor.

### What Makes This Special

- **Single codebase, second entry point** — `main_desktop.dart` alongside `main.dart`. All existing widgets, BLoCs, theme, DI, and routes are immediately available. No monorepo extraction needed.
- **Processing Handover** — Mobile scans documents, desktop processes them with bigger AI models (7B+), more RAM, and always-on vision. FHIR resources are sent back to mobile. A genuinely novel workflow for patient-facing health apps.
- **Local-first sync without cloud** — Devices discover each other via mDNS + SSDP (parallel, first wins), pair once via QR, and communicate over AES-256-GCM encrypted TCP. Health data never leaves the user's local network.
- **Desktop as backup hub** — SQLite snapshots streamed directly to desktop. User controls where data lives (default: `~/Documents/HealthWallet/Backups/`). No cloud dependency.
- **Hotspot fallback** — When no shared WiFi exists, devices create a local hotspot (iPhone: desktop creates hotspot; Android: phone creates LocalOnlyHotspot) for zero-infrastructure connectivity.

### Project Classification

- **Type:** Mobile app expanding to desktop (Flutter Desktop, same codebase)
- **Domain:** Healthcare (FHIR R4, patient health records, on-device AI)
- **Complexity:** High — multi-platform P2P communication, encrypted sync, on-device LLM inference, healthcare data standards
- **Context:** Brownfield — existing production mobile app (v1.2.0), adding desktop support
- **Platforms:** macOS + Windows + Linux
- **Sync strategy:** LWW (Last-Write-Wins) for v1.0, pure Dart, no Rust. CRDT deferred to v2.0.
- **Scope constraint:** One mobile + one desktop pair. Multi-device (3+) deferred to v2.0.

## Success Criteria

### User Success

- **Backup confidence:** User feels their health data is safe on their own computer — not in someone's cloud. If the phone breaks, nothing is lost.
- **Processing quality leap:** A 10-page discharge letter that takes 2 minutes on mobile processes in 15 seconds on desktop. Desktop's bigger model extracts information the phone's smaller model missed — this is the "aha" moment.
- **Seamless pairing:** First-time QR pairing completes in under 30 seconds. Subsequent connections are automatic — user opens desktop app and devices find each other.
- **Data sovereignty:** User chooses where backups live (Documents, external drive, custom path). Health data never touches the internet.

### Business Success

- **30% desktop adoption:** 30% of active mobile users pair a desktop within 3 months of desktop launch.
- **Retention lift:** Desktop users retain at higher rates than mobile-only users (backup + sync create switching cost).
- **Competitive differentiator:** No other personal health app offers local P2P backup without cloud. This is a unique market position.
- **Platform:** Desktop extends the value of the existing mobile app — not a standalone product.

### Technical Success

- **Discovery:** < 200ms on same WiFi (mDNS + SSDP parallel), < 8s on hotspot fallback
- **Backup speed:** 50MB database backup completes in under 3 seconds over LAN
- **Processing Handover:** 5x faster than mobile on the same document
- **LWW sync latency:** Changes appear on other device within 2 seconds when connected
- **Zero cloud dependency:** No data leaves the local network. No internet required for any desktop feature.
- **Cross-platform:** Runs on macOS, Windows, and Linux from the same codebase

### Measurable Outcomes

| Metric | Target | Measurement |
|--------|--------|-------------|
| Desktop adoption | 30% of active mobile users | 3 months post-launch |
| Pairing success rate | > 95% on first attempt | QR scan → connected |
| Backup completion rate | > 99% | Started → verified checksum |
| Processing speedup | 5x vs mobile | Same document, wall-clock time |
| Sync latency | < 2 seconds | DB change → appears on other device |
| Discovery time (WiFi) | < 200ms | App open → device found |
| Discovery time (hotspot) | < 8 seconds | No WiFi → connected |

## User Journeys

**Note:** "Primary user" can be the patient themselves OR a family member managing someone else's records. The multi-patient selector (already in mobile) carries over to desktop.

### Journey 1: Maria — First Backup After Desktop Setup

**Who:** Maria, 42, manages her own health records and her mother Elena's (72, diabetic, frequent specialist visits). Maria has been using HealthWallet.me on her iPhone for 6 months — 140+ records across two patient profiles.

**Opening Scene:** Maria's coworker lost their phone last week and all their health data with it. Maria realizes her mother's entire medical history — discharge letters, lab results, medication lists — lives only on her iPhone. She downloads HealthWallet.me Desktop on her MacBook.

**Rising Action:** Desktop launches and shows a QR code. Maria opens the mobile app, taps "Pair Desktop," scans the QR. Both devices confirm pairing in under 10 seconds. The desktop shows "Connected to Maria's iPhone." She taps "Backup Now" — a progress bar fills in 2 seconds. The desktop confirms: "Backup complete — 47MB, 143 records, 2 patients. Saved to ~/Documents/HealthWallet/Backups/."

**Climax:** Maria switches to the Records tab on desktop. The patient selector bar shows both "Maria" and "Elena." She selects Elena and sees every record on a wide 4-column layout — much easier to review than on phone. She opens Elena's latest discharge letter and reads the doctor's recommendations in full detail without scrolling.

**Resolution:** Maria sets the backup folder to her external drive. She now backs up weekly. When Elena visits a new specialist, Maria can pull up the complete medical history on her MacBook during the appointment. The anxiety about losing data is gone.

**Requirements revealed:** QR pairing, backup flow, patient selector on desktop, records browsing on wider layout, backup location settings.

### Journey 2: Andrei — Processing Handover for a Complex Document

**Who:** Andrei, 35, managing his own records. Just received a 12-page discharge letter (epicriză) from a hospital stay — medication changes, lab results, imaging findings, doctor recommendations.

**Opening Scene:** Andrei photographs all 12 pages with his phone in the HealthWallet.me scan flow. The phone starts processing but he knows from experience that the phone's smaller model sometimes misses details in long documents — especially medication dosages buried in dense text.

**Rising Action:** Andrei's MacBook is paired. The mobile app shows "Process on Desktop" next to the usual "Process on Phone" button. He taps it. The desktop shows "Processing from Mobile — Andrei's discharge letter" with a progress bar. The desktop's 7B model with always-on vision tears through the pages.

**Climax:** 18 seconds later (vs ~3 minutes on phone), the desktop sends back the extracted FHIR resources. Andrei checks the results on his phone — the desktop model caught two medication changes and a doctor recommendation that the phone's smaller model had missed in previous attempts with similar documents. The "aha" moment: the extracted data is noticeably more complete.

**Resolution:** Andrei now always processes complex documents via desktop when he's home. Simple single-page lab results still process fine on phone. The desktop has become his go-to for anything longer than 2-3 pages.

**Requirements revealed:** Processing Handover protocol, "Process on Desktop" button (mobile), processing status on both devices, larger model support on desktop, FHIR resource transfer back to mobile.

### Journey 3: Cristina — Phone Lost, Restore from Desktop Backup

**Who:** Cristina, 58, manages her own records. Has been using HealthWallet.me for a year — 200+ records including years of cardiology follow-ups, lab trends, and medication history. Her desktop has been doing weekly backups.

**Opening Scene:** Cristina drops her phone in water. It's dead. She buys a new phone, installs HealthWallet.me, and opens it to an empty app. A year of carefully organized health records — gone? She remembers the desktop backup.

**Rising Action:** She opens HealthWallet.me Desktop. The backup tab shows her backup history — timestamps, sizes, record counts. She selects last Tuesday's backup (198MB with attachments). She pairs the new phone via QR. The desktop shows "Restore to Cristina's iPhone?" She confirms.

**Climax:** The backup streams to her new phone. The app closes its database, replaces it, reopens. 8 seconds later: 207 records, all patient data, all notes — everything is back. Her cardiology follow-up is tomorrow and she has the complete history.

**Resolution:** Cristina realizes the desktop backup saved her from a genuine crisis. She starts backing up twice a week. The restore experience reinforces the core promise: your health data is safe on YOUR computer.

**Requirements revealed:** Restore flow, backup history UI, schema version check on restore, DB replacement on mobile, attachment restore, QR re-pairing on new device.

### Journey 4: Radu — Hotspot Fallback at a Hospital

**Who:** Radu, 29, managing records for his father Gheorghe (68). Gheorghe just had a consultation at a hospital with no shared WiFi. Radu brought his laptop to organize the new documents.

**Opening Scene:** Radu photographs Gheorghe's consultation notes on the phone. He wants to process them on his laptop for better extraction, but the hospital's guest WiFi blocks device discovery (corporate firewall). mDNS and SSDP both fail.

**Rising Action:** After 3 seconds of no discovery, the app automatically tries the hotspot fallback. Radu's Android phone creates a LocalOnlyHotspot. The desktop shows "Join hotspot: HealthWallet-a3f2, password: xxxxxx." Radu connects his Windows laptop to the hotspot.

**Climax:** SSDP discovers the phone on the hotspot network within 2 seconds. TCP connection establishes. Radu sends the consultation images for processing. The laptop processes them and sends back the extracted resources — all over a direct phone-to-laptop connection with no internet involved.

**Resolution:** Radu switches to the Records tab, selects "Gheorghe" from the patient selector, and reviews the newly extracted consultation notes. He can now show the organized records to the next specialist. The zero-internet-required design proved its value in exactly the scenario it was built for.

**Requirements revealed:** Hotspot fallback (Android creates, desktop joins), SSDP on hotspot network, firewall resilience, zero-internet operation, cross-platform discovery (Windows + Android).

### Journey 5: Elena's Son — Desktop Independent Import & Processing

**Who:** Maria (from Journey 1), at home with her MacBook. Her mother Elena just gave her a paper folder with 6 months of lab results — 15 pages of blood work from her endocrinologist.

**Opening Scene:** Maria could photograph each page on her phone, but she has a flatbed scanner. She scans all 15 pages to PDF on her MacBook.

**Rising Action:** Maria opens HealthWallet.me Desktop, switches to the Import tab, and drags the PDF onto the window. The desktop's 7B AI model begins processing — extracting glucose levels, HbA1c trends, thyroid function, lipid panels. Progress bar shows each page being analyzed.

**Climax:** 25 seconds later, the desktop has extracted 47 individual lab observations across 15 pages. Maria selects "Elena" from the patient selector and reviews the results — all organized by date and category. The desktop model caught every value, including reference ranges and doctor annotations in the margins.

**Resolution:** LWW sync pushes all 47 new records to Maria's phone within 2 seconds. When Elena's endocrinologist asks about trends at the next appointment, Maria pulls up the phone and shows 6 months of glucose and HbA1c values — all extracted from the desktop, synced automatically.

**Requirements revealed:** Desktop Import tab with drag & drop, desktop-local AI processing pipeline (same llamadart, bigger model), patient selector for attribution, LWW sync pushes desktop-created records to mobile.

### Journey Requirements Summary

| Capability Area | Revealed By |
|----------------|-------------|
| QR pairing + onboarding | Journey 1, 3, 4 |
| Backup (mobile → desktop) | Journey 1 |
| Restore (desktop → mobile) | Journey 3 |
| Backup history + location settings | Journey 1, 3 |
| Processing Handover | Journey 2, 4 |
| "Process on Desktop" UI (mobile) | Journey 2 |
| Processing status (both devices) | Journey 2, 4 |
| Patient selector on desktop | Journey 1, 4 |
| Desktop records browsing (wide layout) | Journey 1, 4 |
| mDNS + SSDP discovery | Journey 1, 2 |
| Hotspot fallback | Journey 4 |
| Desktop Import tab with drag & drop | Journey 5 |
| Desktop-local AI processing pipeline | Journey 5 |
| LWW sync (continuous) | Implied by all — changes on either device appear on the other |
| Connection status indicator | All journeys |
| Schema version check on restore | Journey 3 |
| Attachment backup/restore | Journey 3 |

## Domain-Specific Requirements

### Compliance & Regulatory

- **Not a medical device** — HealthWallet.me does not diagnose, recommend treatment, or generate medical advice. It organizes what doctors wrote. No FDA or medical device classification applies.
- **Not HIPAA-covered** — Patient managing their own records on their own devices. No covered entity or business associate relationship.
- **GDPR (EU/Romania)** — Users are EU citizens. However, all data stays on-device (no cloud, no server) — user is both data controller and processor. Most GDPR obligations (consent for sharing, right to deletion from servers, breach notification) do not apply. Relevant obligation: when user deletes data, it must actually be deleted — handled by soft-delete + 30-day tombstone cleanup.
- **FHIR R4 compliance** — Healthcare interoperability standard for data structure. Matters for import/export accuracy and Processing Handover (FHIR JSON resources transferred between devices).
- **No desktop store health app requirements** — Unlike iOS App Store, desktop platforms (macOS, Windows, Linux) have no specific medical app guidelines. macOS distribution via DMG (App Store optional).

### Technical Constraints

- **Encryption in transit** — All device-to-device communication over AES-256-GCM encrypted TCP. Pairing key derived at QR pairing time.
- **Secure key storage** — Pairing keys stored in platform secure storage: Keychain (macOS), Credential Manager (Windows), Secret Service API (Linux).
- **Encryption at rest** — OS-level disk encryption assumed (FileVault, BitLocker, LUKS). App does not implement additional at-rest encryption for v1.0.
- **Zero external network calls** — Desktop features make no calls to external services. No analytics, no telemetry, no cloud sync. AI model downloads are the only internet-facing operation (user-initiated, from Hugging Face).
- **Patient data isolation** — Multi-patient data must not leak across patient profiles. Patient selector enforces data boundaries at the query level (existing Drift DB pattern).

### Security Risk Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Backup file accessed by unauthorized person | Health data exposure | Backup files are raw SQLite — OS-level disk encryption is the protection. v2.0 may add encrypted backup format. |
| Pairing key compromised | Attacker could impersonate device | Keys stored in platform secure storage. Re-pairing generates new key. Connection requires physical QR scan. |
| LWW sync loses concurrent edit | One edit silently overwritten | Acceptable for v1.0 — health data is predominantly write-once (lab results, prescriptions). Concurrent editing is rare for a single user. CRDT in v2.0 eliminates this. |
| Desktop left unlocked with health data visible | Unauthorized viewing | Not app-level concern — OS screen lock is the mitigation. Desktop app does not implement separate biometric lock for v1.0. |
| Corrupted backup restored to mobile | Data loss or corruption | SHA-256 checksum verification before restore. Schema version check prevents incompatible restores. |

## Innovation & Novel Patterns

### Detected Innovation Areas

**1. Processing Handover (Phone → Desktop AI)**
No personal health app offloads on-device AI processing from mobile to desktop over local P2P encrypted TCP. This is a new pattern: the phone is the capture device (camera + scanning), the desktop is the processing device (bigger model, more RAM, faster inference). They work as a pair — neither is complete alone, but together they exceed what either could do.

**2. Cloud-Free Health Data Backup**
The market trend is cloud-first. Every competitor (Apple Health, Google Health, Samsung Health) stores data on cloud servers. HealthWallet.me inverts this: health data never leaves user-owned devices. Backup is direct device-to-device over LAN. This is a deliberate architectural choice, not a limitation — it eliminates an entire category of privacy concerns.

**3. Resilient Zero-Infrastructure Discovery**
The mDNS + SSDP + hotspot fallback stack ensures devices can find each other in any scenario — home WiFi, corporate firewall, hospital with no shared network, or completely offline. No other personal health app has this level of connectivity resilience for P2P features.

### Market Context & Competitive Landscape

- **Apple Health / Google Health** — Cloud-synced, platform-locked, no desktop app, no local backup
- **Samsung Health** — Cloud-synced to Samsung account, no desktop, no P2P
- **MyChart / patient portals** — Provider-controlled, web-based, no offline, no patient-owned data
- **HealthWallet.me Desktop** — Patient-controlled, local-first, P2P sync, multi-platform desktop, AI processing handover. No direct competitor offers this combination.

### Validation Approach

- **Processing Handover:** Measure extraction accuracy (desktop 7B model vs mobile 2B model) on the same set of 50 documents. Target: desktop catches 20%+ more data points.
- **Backup adoption:** Track % of desktop users who complete at least one backup within first week. Target: >80%.
- **Discovery reliability:** Test all 6 device combinations (3 desktop OS × 2 mobile OS) across WiFi, firewall, and hotspot scenarios. Target: 100% success rate within 8 seconds.

## Mobile App (Desktop Expansion) Specific Requirements

### Project-Type Overview

HealthWallet.me Desktop is a Flutter Desktop expansion of an existing Flutter mobile app. Same codebase, same `pubspec.yaml`, second entry point (`main_desktop.dart`). The desktop app is not a standalone product — it extends the mobile app's capabilities with backup, processing handover, and sync.

### Platform Requirements

| Platform | Framework | Runner | Distribution | Build Command |
|----------|-----------|--------|-------------|---------------|
| macOS | Flutter Desktop (Cocoa) | `macos/` (exists) | DMG (direct), App Store optional | `flutter build macos -t lib/main_desktop.dart` |
| Windows | Flutter Desktop (Win32) | `windows/` (new) | MSIX / installer | `flutter build windows -t lib/main_desktop.dart` |
| Linux | Flutter Desktop (GTK 3) | `linux/` (new) | .deb, AppImage | `flutter build linux -t lib/main_desktop.dart` |
| iOS | Existing | `ios/` | App Store (TestFlight) | Unchanged |
| Android | Existing | `android/` | Play Store (internal) | Unchanged |

**Platform-specific configuration:**
- macOS: Entitlements for network (TCP server, mDNS, SSDP), file access (backup location), keychain (pairing keys)
- Windows: Manifest for firewall exception (TCP server port 49152), file access, Credential Manager
- Linux: No special configuration. Secret Service API for pairing keys. Build deps: `libgtk-3-dev cmake ninja-build`

### Device Permissions & Features

| Feature | Mobile | Desktop | Notes |
|---------|--------|---------|-------|
| Camera | Yes (document scanning) | No | Scan is mobile-only |
| File system | App sandbox | Full access | Backup save location, drag & drop import |
| Network (TCP) | Client | Server (port 49152) | Desktop hosts, mobile connects |
| Network (mDNS) | Browse | Advertise | `bonsoir` package |
| Network (SSDP) | M-SEARCH | NOTIFY | `dart:io` RawDatagramSocket |
| Hotspot | iPhone: join / Android: create | Create (macOS/Win) or join (Android hotspot) | Platform channels |
| Secure storage | Keychain / Android Keystore | Keychain / Credential Manager / Secret Service | Pairing keys |
| Biometric auth | Yes (local_auth) | No (OS screen lock) | Desktop skips biometric |
| QR code | Scan (mobile_scanner) | Display (qr_flutter) | One-time pairing |
| Window management | N/A | Min 900x600, remember size/position | Desktop-only |

### Offline Mode

- **Desktop is fully offline by design.** No internet required for any feature except AI model download (user-initiated, one-time).
- Backup, restore, processing handover, LWW sync — all operate over local network only.
- Drift (SQLite) database works identically on mobile and desktop.
- When devices are disconnected, changes queue locally and sync on reconnect.

### Push Strategy

- Not applicable for desktop v1.0. No push notifications.
- Connection status indicator (synced / syncing / offline) replaces notification-based alerts.
- Desktop shows in-app status for: backup progress, processing handover progress, sync status.

### Store Compliance

- **macOS:** App Store optional. Primary distribution via DMG (notarized). No health-app-specific App Store guidelines for macOS.
- **Windows:** MSIX or traditional installer. No store health-app requirements.
- **Linux:** .deb and/or AppImage. No store.
- **Mobile (unchanged):** iOS App Store and Google Play Store guidelines continue to apply for the mobile app. Desktop features do not affect mobile store compliance.

### Implementation Considerations

- **Entry point separation:** `main.dart` (mobile) and `main_desktop.dart` (desktop) share all code via `AppPlatform` enum injected through DI
- **Platform checks:** `AppPlatform.isDesktop` / `AppPlatform.isMobile` for conditional UI (tab swapping, widget visibility)
- **New dependencies for desktop:** `qr_flutter` (QR display), `bonsoir` (mDNS), `pointycastle` (AES-256-GCM encryption)
- **Existing dependencies verified for desktop:** `drift` + `sqlite3_flutter_libs`, `llamadart`, `flutter_secure_storage`
- **CI/CD expansion:** GitHub Actions matrix adds `macos-latest`, `windows-latest`, `ubuntu-latest` runners for desktop builds

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Problem-solving MVP — deliver the complete desktop companion experience in v1.0. The communication layer (TCP + discovery) is the hard infrastructure work; backup, processing handover, and sync are message types on the same pipe. Shipping communication without all three features wastes the investment.

**Resource Requirements:** Solo developer (existing team), Flutter expertise, macOS primary development machine. Windows and Linux testing via CI or secondary machines.

### MVP Feature Set (Phase 1 — v1.0)

**All 5 user journeys supported in v1.0:**
1. First backup after desktop setup (Maria)
2. Processing handover from mobile (Andrei)
3. Restore after phone loss (Cristina)
4. Hotspot fallback at hospital (Radu)
5. Desktop independent import + processing (Maria/Elena)

**Must-Have Capabilities:**

| Capability | Rationale |
|-----------|-----------|
| Desktop shell (macOS + Windows + Linux) | Foundation — app must run on desktop |
| Desktop entry point + platform detection | `main_desktop.dart` + `AppPlatform` enum |
| Desktop navigation (Home, Records, Import, Backup) | Desktop-specific tab layout |
| QR pairing | First-time device connection |
| mDNS + SSDP discovery (parallel) | Auto-reconnect after pairing |
| Hotspot fallback | Works when no shared WiFi |
| Encrypted TCP (AES-256-GCM) | All communication runs on this |
| Backup (mobile → desktop) | Core value: data safety |
| Restore (desktop → mobile) | Recovery from phone loss |
| Processing Handover (mobile → desktop → mobile) | Differentiator: better AI on desktop |
| Desktop independent import + processing | Desktop as standalone processing station with drag & drop |
| LWW Sync (bidirectional, continuous) | Devices stay in sync |
| Schema migration v8 → v9 | Soft delete, device tracking, updated_at |
| Patient selector on desktop | Multi-patient support (family management) |
| Desktop UI (4-column, wider cards, keyboard shortcuts) | Desktop-appropriate layout |
| Light/dark theme on desktop | Reuse mobile theme tokens |
| First-launch onboarding (pair with mobile) | Desktop onboarding flow |

### Implementation Phases (All Ship in v1.0)

**Phase 0: Build Validation (starting point)**
- Verify existing app compiles and launches on macOS, Windows, and Linux
- Surface dependency compatibility issues early (Drift, llamadart, sqlite3_flutter_libs)
- Document any platform-specific workarounds needed

**Phase 1: Desktop Shell**
- Enable macOS/Windows/Linux platforms
- `main_desktop.dart` + `AppPlatform` enum through DI
- Desktop navigation (4 tabs)
- Schema migration v8 → v9
- Window sizing, 4-column layout

**Phase 2: Communication**
- QR pairing
- mDNS + SSDP parallel discovery
- Encrypted TCP (server on desktop, client on mobile)
- Hotspot fallback
- Connection monitoring + auto-reconnect

**Phase 3: Features (all built on Phase 2 TCP)**
- 3a: Backup + Restore (SQLite snapshot transfer, checksum, history)
- 3b: Processing Handover (mobile → desktop → mobile FHIR results) + Desktop independent import/processing
- 3c: LWW Sync (bidirectional, delta-based, offline queue)
- 3d: Desktop UI polish (keyboard shortcuts, drag & drop, onboarding)

3a and 3b can run in parallel. 3c depends on schema migration. 3d runs last.

### Post-MVP Features

**v1.1 (Growth):**
- Auto-updates (Sparkle macOS, winget Windows, AppImage Linux)
- Batch processing (drag & drop folder of documents)
- Backup scheduling (automatic daily/weekly)
- Attachment backup (PDFs, images alongside DB)
- Desktop-side record editing / correction workflow

**v2.0 (Vision):**
- CRDT sync (Automerge) replacing LWW
- Multi-device support (3+ devices)
- Tauri rewrite for smaller bundle, native Rust performance
- Incremental backup (deltas only)
- Cloud-optional sync relay (user-hosted or encrypted)

### Risk Mitigation Strategy

**Technical Risks:**
- `llamadart` on desktop — if it doesn't compile on a platform, that platform ships without processing (backup + sync still work). Mobile processing remains fully functional.
- Hotspot creation via platform channels — if a platform's hotspot API is inaccessible, SSDP + mDNS still cover same-WiFi scenarios. Manual QR re-pair as fallback.
- Drift on desktop — well-tested library, low risk. SQLite works identically across all platforms.

**Market Risks:**
- Desktop adoption depends on mobile user base. If mobile users don't see the value, desktop won't be adopted. Mitigation: in-app prompt on mobile suggesting desktop pairing after user accumulates 50+ records.
- Users may expect cloud sync. Mitigation: frame local backup as a feature ("your data, your computer") not a limitation. Cloud-optional relay in v2.0 for users who want remote access.

**Resource Risks:**
- Solo developer building for 5 platforms (iOS, Android, macOS, Windows, Linux). Mitigation: same codebase, platform-specific code limited to entitlements/manifests and hotspot platform channels. CI matrix handles builds.
- If timeline slips, processing handover and LWW sync can be deferred to v1.1 — backup alone delivers the core safety promise. Communication layer ships regardless.

## Functional Requirements

### Desktop Platform & Shell

- FR1: User can launch HealthWallet.me as a desktop application on macOS, Windows, and Linux
- FR2: User can navigate between four tabs: Home, Records, Import, and Backup
- FR3: User can resize the desktop window with a minimum size of 900x600, and the app remembers window size and position
- FR4: User can view health records in a 4-column desktop-optimized layout with wider cards
- FR5: User can switch between light and dark theme on desktop
- FR6: User can navigate using keyboard shortcuts (Cmd/Ctrl+F for search, arrow keys, Enter, Esc)

### Device Pairing & Discovery

- FR7: Desktop can display a QR code containing pairing information (device ID, IP, port, pairing key)
- FR8: Mobile user can scan the desktop's QR code to establish a device pair
- FR9: Paired devices can automatically discover each other on the same WiFi network via mDNS and SSDP (parallel, first response wins)
- FR10: Paired devices can reconnect using the last known IP address without re-discovery
- FR11: Paired devices can discover each other via hotspot fallback when no shared WiFi exists
- FR12: User can see connection status (connected / connecting / offline) on both devices
- FR13: Devices can automatically reconnect after connection loss, IP change, or app restart

### Backup & Restore

- FR14: User can initiate a backup from mobile to desktop (SQLite snapshot)
- FR15: Desktop can verify backup integrity via SHA-256 checksum after transfer
- FR16: User can choose where backups are saved on desktop (default: ~/Documents/HealthWallet/Backups/)
- FR17: User can view backup history on desktop (timestamp, size, record count per backup)
- FR18: User can initiate a restore from desktop to mobile (select a backup, stream to phone)
- FR19: Mobile can verify and apply a restored backup, including schema version compatibility check
- FR20: User can backup attachments (PDFs, images) alongside the database

### Processing Handover

- FR21: Mobile user can send scanned document images to a connected desktop for AI processing
- FR22: Desktop can process received documents using a larger AI model (llamadart) and return extracted FHIR resources to mobile
- FR23: Both devices can display processing progress and status during handover
- FR24: Mobile user can see a "Process on Desktop" option when a desktop is connected
- FR25: Desktop can run the AI processing pipeline on locally imported documents independently (no mobile involvement)

### Desktop Import & Processing

- FR26: User can drag and drop PDF or image files onto the desktop Import tab
- FR27: Desktop can run the AI extraction pipeline locally on imported documents
- FR28: User can select which patient profile to attribute imported records to via patient selector
- FR29: Desktop-processed records are available in the Records tab immediately after processing

### LWW Sync

- FR30: Changes made on either device can propagate to the connected device bidirectionally
- FR31: System can track changes via `updated_at` timestamp, `deleted_at` soft delete, and `device_id` per row
- FR32: System can compute and send only delta changes (rows modified since last sync)
- FR33: System can queue changes made while disconnected and send all queued changes on reconnect
- FR34: User can see sync status (synced / syncing / offline) on both devices
- FR35: Deleted records can propagate as soft deletes with 30-day tombstone cleanup

### Patient Management (Desktop)

- FR36: User can switch between patient profiles on desktop via the patient selector bar
- FR37: Desktop can display records, vitals, and categories scoped to the selected patient
- FR38: Records created or imported on desktop can be attributed to a specific patient

### Communication & Security

- FR39: All device-to-device communication can be encrypted with AES-256-GCM using the pairing key
- FR40: Pairing keys can be stored in platform-native secure storage (Keychain, Credential Manager, Secret Service)
- FR41: Desktop can operate as a TCP server and mobile as a TCP client over the encrypted channel
- FR42: System can transfer files in chunks with progress reporting on both devices

### Desktop Onboarding

- FR43: First-launch desktop experience can guide the user through pairing with their mobile device
- FR44: Desktop can display instructions for downloading the mobile app if not already installed

### Schema & Data

- FR45: System can migrate the database schema from v8 to v9 (adding updated_at, deleted_at, device_id to all tables)
- FR46: System can ensure all primary keys are UUIDs for cross-device compatibility
- FR47: User's data can remain entirely on-device — no external network calls for any desktop feature except user-initiated AI model download

## Non-Functional Requirements

### Performance

- NFR1: Device discovery completes in < 200ms on same WiFi network (mDNS + SSDP parallel)
- NFR2: Device discovery via hotspot fallback completes in < 8 seconds
- NFR3: Reconnection via saved IP completes in < 1 second
- NFR4: Backup of 50MB SQLite database transfers in < 3 seconds over LAN
- NFR5: Processing Handover delivers 5x speedup vs mobile on the same document
- NFR6: LWW sync propagates changes to connected device within 2 seconds
- NFR7: Desktop AI model inference uses GPU acceleration when available (Metal on macOS, CUDA/Vulkan on Windows/Linux)
- NFR8: Desktop app launches and is usable within 3 seconds on a modern machine

### Security

- NFR9: All device-to-device communication is encrypted with AES-256-GCM
- NFR10: Pairing keys are stored in platform-native secure storage (Keychain, Credential Manager, Secret Service) — never in plaintext
- NFR11: Pairing requires physical QR code scan — no remote pairing possible
- NFR12: No data is transmitted to any external server, API, or cloud service
- NFR13: Backup files are stored as standard SQLite — protected by OS-level disk encryption (FileVault, BitLocker, LUKS)
- NFR14: Deleted data is permanently removed after 30-day tombstone cleanup period (GDPR right to deletion)

### Reliability

- NFR15: Backup integrity is verified via SHA-256 checksum — corrupted backups are rejected before restore
- NFR16: Schema version mismatch between backup and target device is detected and rejected with user notification
- NFR17: Connection loss during file transfer does not corrupt data — partial transfers are discarded, retry from start
- NFR18: LWW sync queue persists across app restarts — queued changes are not lost if app is closed before reconnection
- NFR19: Database migration v8 → v9 preserves all existing mobile data without loss
- NFR20: Desktop app handles all 6 device combinations (3 desktop OS × 2 mobile OS) with identical behavior

### Compatibility

- NFR21: Desktop app runs on macOS 12+ (Monterey), Windows 10+, Ubuntu 22.04+ / equivalent Linux with GTK 3
- NFR22: Desktop app is built from the same codebase and pubspec.yaml as the mobile app — no separate project
- NFR23: Desktop features do not break existing mobile functionality — mobile app works identically with or without a paired desktop
- NFR24: Schema migration v9 is backward-compatible — mobile app with v9 schema works independently if no desktop is paired
