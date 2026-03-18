# Epics & Stories — Desktop App v1.0

**Source:** PRD (`prd.md`), YouTrack Epic HM-2
**Sprint:** Desk App v1.0.0

---

## Epic 1: Desktop App v1.0 — Backup, Processing Handover & LWW Sync

**YouTrack:** HM-2
**Goal:** Extend HealthWallet.me to macOS, Windows, and Linux within the same Flutter codebase. Desktop serves as backup hub, AI processing powerhouse, and LWW sync partner.
**Approach:** B — Single codebase, second entry point (`main_desktop.dart`). No monorepo extraction.

### Story 1.1: Validate Desktop Builds

**YouTrack:** HM-187
**Phase:** 0 — Build Validation (starting point)

**As a** developer, **I want to** verify the existing codebase compiles and runs on macOS, Windows, and Linux **so that** I can identify dependency compatibility issues before starting desktop-specific work.

**Acceptance Criteria:**

- Given the existing HealthWallet.me codebase, when I enable macOS/Windows/Linux platform runners, then `flutter build` completes without errors on all 3 platforms
- Given the app is built for desktop, when I launch it, then the existing mobile UI renders (even if mobile-sized)
- Given Drift + sqlite3_flutter_libs are dependencies, when the app launches on desktop, then the database initializes successfully
- Given llamadart is a dependency, when the app builds for desktop, then native libs compile without errors
- Given any packages fail on specific platforms, when I document the blockers, then a workaround list is produced

**Technical Notes:**
- Enable platforms: `flutter create --platforms=macos .`, `--platforms=windows .`, `--platforms=linux .`
- Linux build deps: `libgtk-3-dev cmake ninja-build`
- This is validation only — no new code, no entry point changes

### Story 1.2: Desktop Shell — Enable Platforms & Entry Point

**YouTrack:** HM-158
**Phase:** 1 — Desktop Shell

**As a** user, **I want to** launch HealthWallet.me as a desktop application **so that** I can access my health records on a bigger screen with a desktop-optimized layout.

**Acceptance Criteria:**

- Given the desktop app is launched, when the user sees the main screen, then 4 tabs are visible: Home, Records, Import, Backup
- Given `main_desktop.dart` exists, when it runs, then `AppPlatform.desktop` is injected through DI and accessible to all widgets/blocs
- Given the desktop window opens, when the user resizes it, then minimum size is 900x600 and last size/position is remembered
- Given the user is on desktop, when they view Records, then a 4-column layout with wider cards is displayed
- Given the user is on desktop, when Scan-related UI would normally appear, then it is hidden (no camera on desktop)
- Given macOS entitlements are configured, when the app launches, then network, file access, and keychain permissions work

**Technical Notes:**
- `lib/main_desktop.dart` — second entry point
- `lib/core/config/app_platform.dart` — `AppPlatform` enum with `isDesktop`/`isMobile`
- `DashboardPage` swaps tabs based on platform
- `lib/features/backup/` — new feature folder (empty scaffold initially)

### Story 1.3: Schema Migration v8 → v9

**YouTrack:** HM-186
**Phase:** 1 — Desktop Shell

**As a** developer, **I need** the database schema updated to support multi-device sync **so that** every record tracks its origin device and supports soft delete for LWW sync.

**Acceptance Criteria:**

- Given the migration runs, when schema v9 is applied, then all tables have `updated_at`, `deleted_at`, and `device_id` columns
- Given existing mobile data, when migration v8→v9 runs, then all records are preserved without data loss
- Given primary keys, when checked after migration, then all are UUIDs (not auto-increment)
- Given a mobile app with v9 schema, when no desktop is paired, then the mobile app works independently (backward compatible)
- Given the migration test suite, when `SchemaVerifier` runs, then v8→v9 migration passes data integrity checks
- Given `drift_schemas/` export, when updated, then it reflects schema v9

**Technical Notes:**
- Step-by-step migration in `app_database.dart`
- Bump schema version to 9
- Add migration test in `/test/drift/my_database/`
- `updated_at` auto-set on every write (triggers for LWW)

### Story 1.4: Communication — QR Pairing, Discovery & Encrypted TCP

**YouTrack:** HM-159
**Phase:** 2 — Communication

**As a** user, **I want to** pair my phone with my desktop via QR code and have them find each other automatically **so that** I can transfer health data securely without internet or cloud.

**Acceptance Criteria:**

- Given the desktop app, when first launched or pairing requested, then a QR code is displayed containing device ID, IP, port, and pairing key
- Given the mobile app, when the user scans the desktop QR code, then both devices confirm pairing within 30 seconds
- Given paired devices on the same WiFi, when the app opens, then discovery completes in < 200ms via mDNS + SSDP parallel
- Given no shared WiFi, when hotspot fallback activates, then devices connect within 8 seconds
- Given a paired device with saved IP, when reconnecting, then saved IP is tried first (< 1 second)
- Given the TCP connection, when data flows, then all communication is encrypted with AES-256-GCM
- Given connection loss, when network recovers, then devices auto-reconnect without user intervention
- Given both devices, when connected, then connection status indicator shows on both (connected / connecting / offline)

**Technical Notes:**
- New deps: `qr_flutter`, `bonsoir`, `pointycastle`
- Desktop = TCP server (port 49152), Mobile = TCP client
- Pairing keys in platform secure storage (Keychain / Credential Manager / Secret Service)
- Protocol: HELLO→ACK, PING→PONG, DATA→ACK, KILL→ACK
- Discovery orchestrator: 1) saved IP, 2) mDNS+SSDP parallel, 3) hotspot, 4) manual QR
- Hotspot: macOS/Windows create (platform channels), Android creates LocalOnlyHotspot

### Story 1.5: Backup & Restore

**YouTrack:** HM-160
**Phase:** 3a — Features

**As a** user, **I want to** backup my health data to my desktop and restore it to a new phone **so that** my records are safe even if my phone is lost or damaged.

**Acceptance Criteria:**

- Given the user taps "Backup Now", when backup runs, then a SQLite snapshot is created via `VACUUM INTO` with SHA-256 checksum
- Given a 50MB database, when backup transfers over LAN, then it completes in under 3 seconds
- Given the desktop receives a backup, when checksum is verified, then the file is saved to the user-chosen location
- Given the Backup tab on desktop, when viewed, then backup history shows (timestamp, size, record count)
- Given the user wants to restore, when they select a backup and confirm, then the backup streams to mobile, DB is replaced, and all records reappear
- Given a schema version mismatch, when restore is attempted, then it is rejected with user notification
- Given backup location settings, when the user changes the folder, then future backups save to the new location
- Given attachments (PDFs, images), when backup runs, then they are included alongside the database

**Technical Notes:**
- Stream SQLite in 64KB chunks over TCP with progress on both sides
- Mobile restore: verify checksum → close Drift DB → replace .db file → reopen
- Default backup location: `~/Documents/HealthWallet/Backups/`

### Story 1.6: Processing Handover — Mobile Offloads to Desktop

**YouTrack:** HM-43
**Phase:** 3b — Features

**As a** user, **I want to** send scanned documents from my phone to my desktop for AI processing **so that** I get faster and more accurate extraction using the desktop's bigger model.

**Acceptance Criteria:**

- Given a connected desktop, when the mobile user views a scan session, then a "Process on Desktop" button is visible
- Given the user taps "Process on Desktop", when processing starts, then desktop receives files and begins AI extraction
- Given desktop processing, when running, then both devices show progress and status updates
- Given a 10-page document, when processed on desktop vs mobile, then desktop is at least 5x faster
- Given processing completes, when FHIR resources are returned, then they appear on mobile immediately
- Given GPU is available, when desktop processes, then it uses Metal (macOS) or CUDA/Vulkan (Windows/Linux)

**Technical Notes:**
- Protocol: `PROCESS_REQUEST { session_id, files[], patient_id, category }` → `PROCESS_STATUS { progress, stage }` → `PROCESS_RESULT { resources[] }`
- Same `llamadart` code, bigger model (7B+), always-on vision
- Reuse existing `ScanRepository` pipeline on desktop

### Story 1.7: Desktop Independent Import & Processing

**YouTrack:** HM-185
**Phase:** 3b — Features

**As a** user, **I want to** drag and drop PDF or image files onto the desktop Import tab **so that** I can process documents directly on my computer without needing my phone.

**Acceptance Criteria:**

- Given the desktop Import tab, when a PDF or image is dragged onto it, then the file is accepted and queued for processing
- Given an imported file, when processing starts, then the desktop AI pipeline extracts FHIR resources locally
- Given the patient selector, when the user selects a patient, then extracted records are attributed to that patient
- Given processing completes, when records are created, then they appear in the Records tab immediately
- Given LWW sync is active, when desktop creates records, then they sync to mobile within 2 seconds

**Technical Notes:**
- Desktop Import tab with drag & drop (Flutter desktop file drop support)
- Same `llamadart` pipeline as processing handover, but initiated locally
- Records include `device_id` identifying desktop as origin

### Story 1.8: LWW Sync — Bidirectional Delta Sync

**YouTrack:** HM-161
**Phase:** 3c — Features

**As a** user, **I want** changes on one device to appear on the other automatically **so that** both devices always have the latest records.

**Acceptance Criteria:**

- Given a record is created/modified on one device, when the other device is connected, then the change appears within 2 seconds
- Given delta computation, when sync runs, then only rows modified since `last_sync_timestamp` are sent
- Given a record is deleted on one device, when sync runs, then it is soft-deleted on the other device
- Given devices are disconnected, when they reconnect, then all queued changes sync automatically
- Given the app is closed and reopened, when reconnection happens, then the offline queue is preserved and sent
- Given 30 days have passed since soft delete, when tombstone cleanup runs, then deleted records are permanently removed
- Given both devices, when sync is active, then sync status indicator shows (synced / syncing / offline)

**Technical Notes:**
- LWW merge: compare `updated_at` timestamps, latest wins
- Delta serialized as JSON (table, id, action: upsert/delete, data) over TCP
- Watch local DB changes via Drift streams → compute delta → send
- Depends on schema v9 (`updated_at`, `deleted_at`, `device_id`)

### Story 1.9: Desktop UI Polish

**YouTrack:** HM-162
**Phase:** 3d — Features

**As a** user, **I want** the desktop app to feel native and comfortable **so that** I can efficiently browse and manage health records on a bigger screen.

**Acceptance Criteria:**

- Given the desktop Records tab, when viewing records, then they display in a 4-column layout with wider cards
- Given keyboard shortcuts, when Cmd/Ctrl+F is pressed, then search activates; arrow keys navigate; Enter opens; Esc closes
- Given theme preferences, when the user switches theme, then light/dark mode applies (reusing mobile theme tokens)
- Given first launch, when the desktop opens for the first time, then an onboarding flow guides pairing with mobile
- Given the patient selector bar, when on desktop, then it shows all patient profiles (same as mobile)
- Given the desktop Records detail view, when opened, then it uses the same layout as mobile but wider

**Technical Notes:**
- Reuse mobile theme tokens and "Matter" font family
- Patient selector bar carried over from mobile (multi-patient already exists)
- Keyboard shortcuts via `FocusNode` and `RawKeyboardListener` or `Shortcuts` widget
