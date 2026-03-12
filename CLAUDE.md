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

Health Wallet is a Flutter mobile app for patient-controlled health record management. It aggregates medical data from multiple healthcare providers using FHIR R4 standards, with offline-first architecture and biometric security.

- **Flutter 3.38.7** (managed via FVM — see `.fvmrc`)
- **Dart SDK:** >=3.10.7 <4.0.0
- **Platforms:** iOS (16.0+), Android (SDK 24+)
- **Package name:** `com.techstackapps.healthwallet`

## Common Commands

```bash
# Use `fvm flutter` for consistency with CI, or plain `flutter` if FVM is configured
fvm flutter pub get

# Code generation — required after changing models, routes, DI, database schemas, or env
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # Watch mode

# Run tests
flutter test
flutter test test/widget_test.dart          # Single test file

# Static analysis
flutter analyze

# Build
fvm flutter build apk --release
fvm flutter build appbundle --release
fvm flutter build ios --release --no-codesign

# Run on connected iOS device (requires code signing — cannot use --no-codesign)
# Use `fvm flutter devices` to find the device ID, then:
fvm flutter run -d <device-id>

# Deployment (via Fastlane — auto-increments build number from store)
cd ios && bundle exec fastlane beta          # iOS → TestFlight
cd android && bundle exec fastlane beta      # Android → Play Store internal
```

## Architecture

**Clean Architecture** with feature-based modules. Each feature has three layers:
- `presentation/` — Pages, widgets, BLoC (state management via `flutter_bloc`)
- `domain/` — Entities (Freezed), abstract repository interfaces, use cases/services
- `data/` — Repository implementations, data sources (remote via Dio, local via Drift), DTOs

**Dependency flow:** Presentation → Domain → Data. All dependencies injected via constructor.

### Key Patterns

- **BLoC** — Each feature has its own BLoC with Freezed events/states. BLoCs are registered in DI with `@injectable` or `@LazySingleton()`. Event handlers use `transformer:` parameter for concurrency control (`restartable()`, `sequential()`, `droppable()`).
- **GetIt + Injectable** — DI configured in `core/di/injection.dart`. Entry point: `configureDependencies()` called in `main.dart`. Module registrations in `core/di/register_module.dart`.
- **AutoRoute** — Type-safe routing in `core/navigation/app_router.dart`. Dashboard is parent route with nested children (Home, Records, Scan, Import). Generated file: `app_router.gr.dart`.
- **Drift** — SQLite database in `core/data/local/app_database.dart`. Current schema version: **8**. Step-by-step migrations. Tables: FhirResource, Sources, RecordNotes, ProcessingSessions. Schema files in `drift_schemas/`.
- **Freezed** — Immutable data classes. Files: `*.freezed.dart` (generated).
- **FHIR R4** — Healthcare data models via `fhir_r4` package. IPS export via private `fhir_ips_export` package.
- **Localization** — ARB files in `core/l10n/arb/` (EN, ES, DE). Access via `context.l10n.stringKey` extension.

### Feature Modules

| Feature | Description |
|---------|-------------|
| `home/` | Dashboard with reorderable grid |
| `records/` | Health records (FHIR resources), IPS PDF export |
| `sync/` | QR-based pairing with self-hosted backend (FastenHealth), FHIR data sync |
| `scan/` | Document scanning with on-device AI (llama.cpp via `llamadart`), OCR (ML Kit) |
| `share_records/` | P2P proximity sharing via Airdrop, ephemeral sessions |
| `wallet_pass/` | Apple Wallet / Google Wallet emergency card generation |
| `user/` | Profile, preferences, patient deduplication |
| `onboarding/` | First-launch flow |
| `notifications/` | In-app notifications |
| `dashboard/` | Main container with tab navigation |

### Scan Feature — AI Model Integration

Two downloadable models configured in `core/config/constants/ai_model_config.dart`:
- **MedGemma** (~3.3 GB) — Advanced medical vision model, skips device check
- **Qwen** (~1.5 GB) — Standard vision model, checks device memory

Models download on-demand via `AiModelDownloadService`. Device memory estimation differs per platform (iOS: device model lookup, Android: `/proc/meminfo`). Processing sessions stored in Drift `ProcessingSessions` table.

### Sync Flow

QR code contains: bearer token, server base URLs (tried sequentially), sync endpoint. Flow: parse QR → create wallet source → create default patient → clear demo data → authenticate → sync FHIR resources from backend.

## Code Generation

Generated files excluded from analysis (see `analysis_options.yaml`):
- `*.freezed.dart`, `*.g.dart`, `*.config.dart`, `*.gr.dart`

Run `dart run build_runner build --delete-conflicting-outputs` after changing: models (Freezed), routes (AutoRoute), DI registrations (@injectable), database schemas (Drift), environment variables (Envied).

## Environment Configuration

Managed via `envied` package in `lib/core/config/env/env.dart`. All values obfuscated. Required `.env` variables:
- `HUGGING_FACE_TOKEN` — AI model downloads
- `GOOGLE_WALLET_ISSUER_ID` — Google Wallet integration
- `APPLE_PASS_TYPE_ID`, `APPLE_TEAM_ID` — Apple Wallet integration

## App Initialization (`main.dart`)

1. Preserve native splash screen
2. `configureDependencies()` — GetIt/Injectable DI setup
3. Initialize ShareIntentService, DeepLinkService
4. Initialize ScanBloc (checks model state)
5. Remove splash, run App

`App` widget provides all BLoCs via `MultiBlocProvider`, implements `WidgetsBindingObserver` for lifecycle (starts/stops P2P discovery on resume/pause).

## Testing

- **flutter_test** + **mockito** for widget/unit tests, **bloc_test** for BLoC testing
- Tests use fake repository implementations (see `test/widget_test.dart`)
- Database migration tests in `test/drift/`

## CI/CD

- **ci.yml** — PR to `master`: analyze + test with coverage
- **master-deploy.yml** — Push to `master`: parallel iOS (Fastlane beta → TestFlight) + Android (Fastlane beta → Play Store internal)
- **develop-deploy.yml** — Push to `develop`: same as master deploy
- CI restores `.env`, SSH keys, certificates, keystores from GitHub Secrets

## Git Branch Strategy

- `master` — Production (auto-deploys to stores)
- `develop` — Staging (auto-deploys to internal tracks)
- `dev/*`, `feature/*`, `fix/*` — Development branches (CI runs analyze + tests on PR)
- `release/*` — Release staging
- `hotfix/*` — Urgent production fixes

## Private Dependencies

- `fhir_ips_export` — Private git dependency (SSH key access required, `SSH_PRIVATE_KEY` secret in CI)
- `airdrop` — Private Flutter package for P2P file transfer (same SSH access)
