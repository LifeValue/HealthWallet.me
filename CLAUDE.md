# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: No Credentials in Git

**NEVER commit, stage, or include any of the following in any branch, commit, or PR:**
- Private keys (`.pem`, `.p8`, `.p12`, `.key`), keystore files (`.jks`, `.keystore`)
- Service account JSON files (`service-account*.json`), `.env` files, API keys/tokens

All secrets are stored as GitHub Secrets and restored at build time via CI/CD workflows. Before every commit, verify:
```
git diff --cached --name-only | grep -iE '\.(pem|p8|p12|key|jks|keystore)$|service-account|\.env$'
```

---

## Project Overview

HealthWallet.me is a Flutter application for patient-controlled health record management. It aggregates medical data from multiple healthcare providers using FHIR R4 standards, with offline-first architecture and biometric security. The same codebase targets both **mobile** (iOS, Android) and **desktop** (macOS, Windows) via two entry points and a platform discriminator.

- **Flutter 3.47.7** (managed via FVM — see `.fvmrc`)
- **Dart SDK:** >=3.13.5 <4.0.0
- **Mobile platforms:** iOS 16.0+, Android SDK 24+
- **Android toolchain:** Gradle 9.4.1, AGP 9.2.1, Kotlin 2.4.0, compileSdk 37, NDK 28.2, JDK 17. AGP 9 runs in Flutter's compatibility mode (`android.builtInKotlin=false`, `android.newDsl=false` in `android/gradle.properties`) because most plugins still apply the Kotlin Gradle Plugin; `android/build.gradle.kts` raises plugins compiling below SDK 36
- **Desktop platforms:** macOS (production), Windows (Store-packaged). Linux is not scaffolded (`linux/` removed); `Platform.isLinux` branches in Dart code are kept for a future port
- **Package name:** `com.techstackapps.healthwallet`

### Dual Entry Points

| File | Platform | Registers |
|------|----------|-----------|
| `lib/main.dart` | Mobile (iOS / Android) | `AppPlatform.mobile`, `ShareIntentService`, `DeepLinkService`, native splash |
| `lib/main_desktop.dart` | Desktop (macOS / Windows) | `AppPlatform.desktop`, `CommunicationBloc`, `TrayBloc`, `BackupBloc`, `HandoverBloc`, `LwwSyncBloc`, `WindowLifecycleService` |

`AppPlatform` is a DI singleton (`getIt<AppPlatform>()`) checked throughout the codebase to gate platform-specific behaviour. Use `context.isDesktopWidth` (screen ≥ 1024 px) for layout breakpoints; use `AppPlatform.isDesktop` for feature gating.

---

## Common Commands

```bash
fvm flutter pub get

# Code generation — required after changing models, routes, DI, DB schemas, or env
dart run build_runner build
dart run build_runner watch

flutter test
flutter test test/widget_test.dart

flutter analyze

# Mobile builds
fvm flutter build apk --release
fvm flutter build appbundle --release
fvm flutter build ios --release --no-codesign
fvm flutter run -d <device-id>

# Desktop builds
fvm flutter build macos --release
fvm flutter build windows --release

# Mobile deployment (Fastlane — auto-increments build number)
cd ios && bundle exec fastlane beta          # iOS → TestFlight
cd android && bundle exec fastlane beta      # Android → Play Store internal
```

---

## Architecture

**Clean Architecture** with feature-based modules. Each feature has three layers:
- `presentation/` — Pages, widgets, BLoC (state management via `flutter_bloc`)
- `domain/` — Entities (Freezed), abstract repository interfaces, use cases/services
- `data/` — Repository implementations, data sources (remote via Dio, local via Drift), DTOs

**Dependency flow:** Presentation → Domain → Data. All dependencies injected via constructor.

### Key Patterns

- **BLoC** — Each feature has its own BLoC with Freezed events/states. BLoCs are registered in DI with `@injectable` or `@LazySingleton()`. Event handlers use `transformer:` for concurrency control (`restartable()`, `sequential()`, `droppable()`).
- **GetIt + Injectable** — DI in `core/di/injection.dart`. Entry point: `configureDependencies()`. Module registrations in `core/di/register_module.dart`.
- **AutoRoute** — Type-safe routing in `core/navigation/app_router.dart`. Dashboard is parent route with nested children. Generated file: `app_router.gr.dart`.
- **Drift** — SQLite in `core/data/local/app_database.dart`. Schema version: **11** (production 1.2.x ships **9**). v1→8 use drift `stepByStep`; v9→11 are hand-written SQL in `onUpgrade` — declare added nullable columns as `TYPE NULL` so they match drift's schema snapshots. Tables: `FhirResource`, `Sources`, `RecordNotes`, `ProcessingSessions`. Schema snapshots in `drift_schemas/`; after a schema change run `dart run drift_dev schema dump lib/core/data/local/app_database.dart drift_schemas/my_database/` and `dart run drift_dev schema generate --data-classes --companions drift_schemas/my_database/ test/drift/my_database/generated/`, then add a migration test in `test/drift/`. LWW-synced tables: `fhir_resource`, `sources`, `record_notes` (NOT `processing_sessions`).
- **Freezed** — Immutable data classes. Files: `*.freezed.dart` (generated).
- **FHIR R4** — Healthcare data models via `fhir_r4` package. IPS export via private `fhir_ips_export` package.
- **Localization** — ARB files in `core/l10n/arb/` (EN, ES, DE, RO). Access via `context.l10n.stringKey` extension. The generated Dart files (`app_localizations*.dart`) are committed and must be kept in sync with the ARB files.

### Responsive Layout

`context.screenHorizontalPadding` (from `core/utils/responsive.dart`) returns 16 px (mobile), 32 px (tablet ≥ 600 px), or 48 px (desktop ≥ 1024 px) — all based on **screen** width. When widgets are inside a constrained sub-area (e.g. the desktop right panel), use `LayoutBuilder` and the same breakpoint logic on `constraints.maxWidth` so that padding stays aligned with the surrounding header.

---

## Feature Modules

### `features/capture/` — Document Input

Groups all entry points that feed raw files into the processing pipeline.

| Sub-feature | Description | Platform |
|-------------|-------------|----------|
| `capture/scan/` | Camera capture page + `ScanBloc` | Mobile only |
| `capture/import/` | File picker (PDF, images) + `ImportBloc` | Both |
| `capture/desktop_import/` | Desktop drag-and-drop / file picker + `DesktopBloc` | Desktop only |

After capture, files are handed to `ProcessingBloc` via `DocumentImported` event.

### `features/processing/` — AI Processing Pipeline

The platform-agnostic brain. Orchestrates the full document-to-FHIR pipeline.

**Pipeline stages:**
1. **OCR** — `NativeTextRecognitionService` calls the `dev.lifevalue.healthwallet/ocr` method channel, implemented natively per runner: Apple Vision on iOS (`ios/Runner/TextRecognitionHandler.swift`) and macOS (`macos/Runner/AppDelegate.swift`), ML Kit on Android (`ocr/TextRecognitionHandler.kt`), `Windows.Media.Ocr` on Windows (`windows/runner/windows_ocr_plugin.cpp`). There is no OCR Flutter plugin, so iOS has no ML Kit pods and runs on arm64 simulators.
2. **Vision AI (Phase 1)** — `ScanNetworkDataSource.runVisionPrompt()` runs `Qwen3-VL-2B-Instruct` (Q4\_K\_M GGUF) via `llamadart`. Extracts patient demographics, encounter details, and a primary diagnostic report.
3. **Vision AI (Phase 2)** — `runVisionPrompt()` again for remaining resource types (medications, immunizations, allergies, vitals, etc.).
4. **Text fallback** — If vision fails, `runTextPrompt()` uses OCR text with the existing prompt templates.
5. **FHIR mapping** — `ProcessingRepository` maps staged resources into FHIR R4 entities and persists them via Drift.

**Key types:**

| Type | Location | Role |
|------|----------|------|
| `ProcessingBloc` | `presentation/bloc/` | Shared orchestrator; used on both mobile and desktop |
| `ProcessingHandler` | `presentation/bloc/handlers/` | Mixin handling `DocumentImported`, `SessionActivated`, `ProcessRemainingResources` |
| `SessionHandler` | `presentation/bloc/handlers/` | Mixin handling session lifecycle events |
| `AiModelDownloadService` | `data/services/` | Downloads model + mmproj files from HuggingFace; tracks progress |
| `NativeTextRecognitionService` | `data/services/` | OCR over the native `ocr` channel; PDF pages rasterised first |
| `ProcessingRepository` | `data/repository/` | Runs the full pipeline; writes FHIR rows to Drift |
| `ProcessingSession` | domain entity | Persisted in `ProcessingSessions` Drift table |
| `MappingResources` | `domain/entity/mapping_resources/` | Intermediate staged types (patient, encounter, diagnostic report, etc.) |

**Models** (`core/config/constants/ai_model_config.dart`):
- **Qwen3-VL-2B** (~1.11 GB model + ~445 MB mmproj) — primary vision model
- **MedGemma** (~3.3 GB) — advanced medical model (optional, skips device check)

Model files are downloaded on-demand and stored in the app's document directory. `ProcessingBloc` is initialised in `main.dart` via `ProcessingBloc.add(ProcessingInitialised())`.

### `features/desktop/` — Desktop-Specific Features

Only active when `AppPlatform.desktop`. All sub-features are initialised in `main_desktop.dart`.

#### `communication/` — Mobile ↔ Desktop Connectivity

See the full protocol description in the **Mobile ↔ Desktop Communication** section below.

#### `handover/` — AI Offload

Mobile captures images → sends them to desktop → desktop runs full AI pipeline → LWW sync returns FHIR records to mobile. Used when mobile device lacks memory or CPU for inference.

Flow: `handover.offer` → `handover.accept` → `handover.file[]` → desktop runs `ProcessingBloc` → `handover.result` → mobile triggers `LwwSyncBloc.SyncTriggered`.

`HandoverService` is the desktop receiver; `HandoverSenderService` is the mobile sender.

#### `lww_sync/` — Bidirectional Database Sync

Last-Write-Wins sync of `fhir_resource`, `sources`, and `record_notes` tables between mobile and desktop SQLite databases. See details in **Mobile ↔ Desktop Communication**.

#### `backup/` — Desktop Snapshot

Desktop creates point-in-time SQLite snapshots via `VACUUM INTO`. Mobile can remotely trigger a backup; desktop streams the `.db` file back in 64 KB chunks with SHA-256 checksum verification. Default path: `~/Documents/HealthWallet/Backups/`.

#### `tray/` — System Tray

`TrayService` manages the macOS/Windows system tray icon and menu. `WindowLifecycleService` handles minimize-to-tray and restore. `TrayBloc` reacts to connection and sync status changes from `CommunicationBloc` and `LwwSyncBloc`.

### `features/sync/` — FastenHealth FHIR Backend Sync

QR-based pairing with a self-hosted [Fasten Health OnPrem](https://github.com/fastenhealth/fasten-onprem) backend.

Flow: parse QR → create wallet source → create default patient → clear demo data → authenticate (bearer token) → sync FHIR resources from backend sequentially.

Sub-structure:
- `sync/ehrs/fasten/` — Fasten-specific FHIR sync logic, remote data sources, repository
- `sync/data/` — shared FHIR data layer (mappers, DTOs, services)
- `sync/domain/` — shared entities and services

### Other Feature Modules

| Feature | Description |
|---------|-------------|
| `home/` | Dashboard with reorderable grid of health category cards |
| `records/` | FHIR resource browsing (25+ types), attachment viewer, IPS PDF export |
| `share_records/` | P2P proximity sharing via `airdrop` package, ephemeral sessions |
| `wallet_pass/` | Apple Wallet / Google Wallet emergency card generation |
| `user/` | Profile, preferences, patient deduplication |
| `onboarding/` | First-launch flow |
| `notifications/` | In-app notifications |
| `dashboard/` | Main container with tab navigation (`PageView`) |

---

## Mobile ↔ Desktop Communication

```
┌──────────┐      MessageRouter      ┌──────────┐
│  Mobile  │ ◄─── AES-256-GCM ────► │  Desktop │
│ (client) │      TCP / MPC          │ (server) │
└──────────┘                         └──────────┘
```

### Pairing (one-time)

Desktop shows a QR code containing a `DevicePairing` JSON object:
- `deviceId` — UUID v4
- `deviceName` — desktop hostname
- `pairingKey` — 32 random bytes (base64url) used as AES-256 key
- `lastIp`, `lastPort` (default 49152), `os`, `pairedAt`

Mobile scans the QR, saves `DevicePairing` via `PairingStorageService`, and immediately connects.

### Discovery (how mobile finds desktop after pairing)

Three strategies tried in order:

1. **MPC (MultipeerConnectivity)** — Apple platforms only (iOS ↔ macOS). Zero-config, instant. Backed by the private `airdrop` package.
2. **Saved IP** — Uses `lastIp:lastPort` from the last successful connection. 5-second `Socket.connect()` timeout.
3. **mDNS + SSDP in parallel** — `MdnsService` and `SsdpService` run concurrently with 3-second timeouts. First result wins; updates saved IP for next time.

If all three fail: `CommunicationConnectionFailed`. Mobile retries with exponential back-off (3 s base, doubling, max 5 attempts), then clears pairing and prompts re-scan.

**Platform matrix:**

| Mobile \ Desktop | macOS | Windows |
|-----------------|-------|---------|
| iOS | MPC + TCP | TCP only |
| Android | TCP only | TCP only |

### Wire Protocol

All frames are **AES-256-GCM** encrypted. Key = first 32 bytes of the base64url-decoded `pairingKey`. Each message: `[12-byte random nonce][ciphertext+tag]`.

TCP framing: `[4-byte uint32 length][encrypted payload]`. MPC: no length prefix (transport handles framing).

Decrypted payload starts with a 1-byte `MessageType`:

| Code | Type | Description |
|------|------|-------------|
| 0x01 | `hello` | Handshake. JSON `{pairing_key_hash, device_name}`. Receiver validates key hash. Replies with `ack`. |
| 0x02 | `ack` | Acknowledgement. |
| 0x03 | `ping` | Keep-alive every 10 s. |
| 0x04 | `pong` | Response to ping. |
| 0x05 | `data` | Application message. JSON `{type: string, payload: {…}}`. Routed by `MessageRouter`. |
| 0xFF | `kill` | Graceful disconnect. Receiver replies `ack` then closes. |

### Application-Level Message Types

**LWW Sync:**

| Type | Direction | Meaning |
|------|-----------|---------|
| `sync.delta` | both | Changed rows for one table since a timestamp. Payload: `SyncDelta` (table name, rows, deviceId, timestamp). Attachment binary data is embedded inline (base64) and stripped on receipt. |
| `sync.ack` | both | Acknowledges a delta. |
| `sync.status` | both | Row counts per table. Triggers reconciliation if counts differ. |
| `sync.verify` | both | Post-reconciliation counts for validation. |
| `sync.file_request` | receiver → sender | List of missing attachment file paths. |
| `sync.file_data` | sender → receiver | Map of `path → base64_bytes` for missing files. |

**Conflict resolution:** Later `updated_at` wins. Tie-break: lexicographically larger `device_id`. If a `DocumentReference` has a broken local attachment, the incoming row is preferred.

**Soft deletes:** Rows set `deleted_at` and bump `updated_at`; the delta query picks them up via `WHERE updated_at >= ?`. Tombstones older than 30 days are hard-deleted on `LwwSyncInitialised`.

**Offline queue:** `OfflineQueueService` stores pending deltas in `SharedPreferences` (`lww_offline_queue`) and flushes on reconnect. Note: `main.dart` clears this key on mobile startup — pending offline changes are dropped on mobile app restart.

**Backup:**

| Type | Direction | Meaning |
|------|-----------|---------|
| `backup.request` | mobile → desktop | Trigger a backup snapshot. |
| `backup.status` | desktop → mobile | Readiness info. |
| `backup_start` | desktop → mobile | Start of chunked transfer: size, checksum, chunk count. |
| `backup_chunk` | desktop → mobile | 64 KB chunk (base64). |
| `backup_complete` | desktop → mobile | Transfer done; mobile verifies SHA-256 checksum. |

**Handover:**

| Type | Direction | Meaning |
|------|-----------|---------|
| `handover.offer` | mobile → desktop | Initiate AI offload: session_id, file_count, optional phase1_data. |
| `handover.accept` | desktop → mobile | Desktop accepts. |
| `handover.file` | mobile → desktop | One image file (base64). |
| `handover.progress` | desktop → mobile | Progress updates during inference. |
| `handover.step1_complete` | desktop → mobile | Patient extraction done (if phase1_data was absent). |
| `handover.result` | desktop → mobile | Full FHIR resource list. LWW sync then propagates to mobile. |

---

## Code Generation

Generated files excluded from analysis (`analysis_options.yaml`): `*.freezed.dart`, `*.g.dart`, `*.config.dart`, `*.gr.dart`.

Run `dart run build_runner build` after changing:
- Freezed models
- AutoRoute routes
- Injectable DI registrations
- Drift database schemas
- Envied environment variables

---

## Environment Configuration

Managed via `envied` in `lib/core/config/env/env.dart`. All values obfuscated. Required `.env` variables:
- `HUGGING_FACE_TOKEN` — AI model downloads
- `GOOGLE_WALLET_ISSUER_ID` — Google Wallet integration
- `APPLE_PASS_TYPE_ID`, `APPLE_TEAM_ID` — Apple Wallet integration

---

## App Initialization

### Mobile (`main.dart`)
1. Native splash preserved
2. `configureDependencies()` — GetIt/Injectable DI setup
3. `ShareIntentService`, `DeepLinkService` initialized
4. `ProcessingBloc.add(ProcessingInitialised())` — checks model state, restores any in-progress session
5. Splash removed, `App` widget launched

### Desktop (`main_desktop.dart`)
1. `configureDependencies()`
2. `CommunicationBloc`, `TrayBloc`, `BackupBloc`, `HandoverBloc`, `LwwSyncBloc` registered and initialised
3. `CommunicationBloc` stream → `TrayBloc` (connection status updates)
4. `LwwSyncBloc` stream → `TrayBloc` (sync status updates)
5. `ProcessingBloc.add(ProcessingInitialised())`
6. `App` widget launched (no native splash)

`App` widget provides all BLoCs via `MultiBlocProvider`, implements `WidgetsBindingObserver` for lifecycle (starts/stops P2P discovery on resume/pause).

---

## Testing

- **flutter_test** + **mockito** for widget/unit tests, **bloc_test** for BLoC testing
- Tests use fake repository implementations (see `test/widget_test.dart`)
- Database migration tests in `test/drift/`

---

## CI/CD

GitLab CI (`.gitlab-ci.yml`) on `git.techstackapps.com/mobile/health-wallet/app`. GitLab is the source of truth; the public GitHub repo (`LifeValue/HealthWallet.me`) is left untouched and its `.github/workflows/` are not used.

- **checks** — every branch push, on the Linux instance runners (`ghcr.io/cirruslabs/flutter`): `pub get`, `build_runner`, `flutter analyze` (errors fatal, warnings not yet), `flutter test`. Needs no secrets.
- **ios:testflight / macos:testflight / android:play-internal** — manual jobs on every branch pipeline (the branch must be protected to receive the protected CI/CD variables), on the shared `shell-macmini` runner via Fastlane (`beta` lanes). Automatic signing (no fastlane match): certificates are in the runner's login keychain, profiles are fetched with the App Store Connect API key via `-allowProvisioningUpdates`. The Android jobs run Gradle on a pinned Temurin JDK 17 (`ANDROID_JDK_*` variables, cached per runner, set through `org.gradle.java.home`), because the JDK Flutter would pick on the Mac mini (Android Studio's JBR 17.0.9) crashes the Gradle daemon.
- **shorebird:patch-android / shorebird:patch-ios** — manual on `master`.
- **windows:release** — manual on every branch: `master` → `v<version>`, other branches → pre-release `v<version>-dev.<iid>`; uploads zip + msix to the generic package registry and creates a GitLab Release. Needs a runner tagged `windows` (none registered yet).
- Secrets are protected CI/CD variables (names listed at the top of `.gitlab-ci.yml`); private pub dependencies are fetched with `CI_JOB_TOKEN`.

---

## Git Branch Strategy

- `master` — Production (store uploads are manual pipeline jobs)
- `develop` — Staging (internal-track uploads are manual pipeline jobs)
- `dev/*`, `feature/*`, `fix/*` — Development branches (CI runs analyze + tests on MRs)
- Merges always use a merge commit (`--no-ff`), never fast-forward
- `release/*` — Release staging
- `hotfix/*` — Urgent production fixes

---

## Private Dependencies

- `fhir_ips_export` — Private git dependency on `git.techstackapps.com` (SSH locally; `CI_JOB_TOKEN` in CI — the project must be on its job-token allowlist)
- `airdrop` — Private Flutter package for P2P file transfer and MultipeerConnectivity transport (same access). Build fails if it can't be fetched.

---

## Known Architectural Notes

- **Offline queue dropped on mobile restart.** `main.dart` clears `lww_offline_queue` from `SharedPreferences` on every start. Pending LWW changes that were not yet synced to desktop will be silently lost if the mobile app is restarted while offline.
- **`ProcessingSessions` is NOT LWW-synced.** Only `fhir_resource`, `sources`, and `record_notes` participate in delta sync. Processing session state is local to each device.
- **Android ↔ Desktop is TCP-only.** MPC (MultipeerConnectivity) requires both devices to be Apple platforms. Android paired with macOS or Windows uses mDNS/SSDP discovery only.
- **One desktop client at a time.** `TcpService` supports a single connected mobile client. A second connection attempt triggers a "pending client" dialog on the desktop requiring explicit accept/reject.
- **Windows desktop binds to its current local IP at server start.** If the machine's IP changes (network switch), the saved IP becomes stale and the mobile may fail the first reconnect attempt before mDNS/SSDP discovery succeeds.
