# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Health Wallet is a Flutter mobile app for patient-controlled health record management. It aggregates medical data from multiple healthcare providers using FHIR R4 standards, with offline-first architecture and biometric security.

- **Flutter 3.32.4** (managed via FVM)
- **Platforms:** iOS (16.0+), Android (SDK 24+)
- **Package name:** `com.techstackapps.healthwallet`

## Common Commands

```bash
# Install dependencies
fvm flutter pub get

# Code generation (Freezed, JSON, routes, DI, l10n) — required after model/route/DI changes
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test
flutter test test/widget_test.dart          # Single test file

# Static analysis
flutter analyze

# Build
flutter build apk --release                 # Android APK
flutter build appbundle --release            # Android App Bundle
flutter build ios --release --no-codesign    # iOS

# Deployment (via Fastlane)
cd ios && bundle exec fastlane beta          # iOS → TestFlight
cd android && bundle exec fastlane beta      # Android → Play Store internal
```

## Architecture

**Clean Architecture** with feature-based modules, each containing three layers:

```
lib/
├── app/              # App entry point, MaterialApp config
├── core/             # Shared code across features
│   ├── config/       # Environment (Envied), constants, exceptions
│   ├── di/           # GetIt + Injectable dependency injection
│   ├── navigation/   # AutoRoute router and observers
│   ├── l10n/arb/     # Localization files (EN, ES, DE)
│   ├── services/     # Network (Dio + interceptors), local DB, biometric, PDF, deep links
│   ├── theme/        # Colors, text styles, theme config
│   ├── utils/        # Formatters, helpers, performance monitor
│   └── widgets/      # Shared reusable UI components
├── features/         # Feature modules
│   ├── home/         # Dashboard with reorderable grid
│   ├── records/      # Health records (FHIR resources)
│   ├── sync/         # Data sync, QR pairing, source management
│   ├── scan/         # Document scanning, OCR (ML Kit)
│   ├── user/         # Profile, preferences, patient deduplication
│   ├── dashboard/    # Main container/navigation
│   ├── notifications/
│   └── onboarding/
└── gen/              # Auto-generated code (assets, routes)
```

**Each feature follows this structure:**
- `presentation/` — Pages, widgets, BLoC (state management via `flutter_bloc`)
- `domain/` — Entities (Freezed immutable classes), abstract repository interfaces, use cases/services
- `data/` — Repository implementations, data sources (remote via Dio, local via Drift/SQLite), DTOs

**Key patterns:**
- **BLoC** for state management — each feature has its own BLoC with events/states
- **GetIt + Injectable** for DI — auto-registered via build_runner, configured in `core/di/`
- **AutoRoute** for navigation — type-safe routing with deep link support
- **Drift** for local SQLite database — schema files in `drift_schemas/`
- **Freezed** for immutable data classes with value equality
- **FHIR R4** data models via `fhir_r4` package for healthcare interoperability

## Code Generation

Generated files are excluded from analysis (see `analysis_options.yaml`):
- `*.freezed.dart` — Freezed immutable classes
- `*.g.dart` — JSON serialization, Drift, Injectable
- `*.config.dart` — Injectable DI config
- `*.gr.dart` — AutoRoute generated routes

Always run `dart run build_runner build --delete-conflicting-outputs` after changing models, routes, DI registrations, or database schemas.

## Testing

- **flutter_test** for widget/unit tests
- **mockito** for mocking, **bloc_test** for BLoC testing
- Tests use fake repository implementations (see `test/widget_test.dart` for pattern)
- Database tests in `test/drift/`

## Git Branch Strategy

- `master` — Production (auto-deploys to stores)
- `develop` — Staging (auto-deploys to internal tracks)
- `feature/*`, `fix/*` — Development branches (CI runs analyze + tests on PR)
- `release/*` — Release staging
- `hotfix/*` — Urgent production fixes

## Private Dependencies

`fhir_ips_export` is a private git dependency requiring SSH key access. In CI, this is handled via `SSH_PRIVATE_KEY` secret.

## Environment Configuration

Environment variables are managed via the `envied` package in `lib/core/config/env/env.dart`. A `.env` file is required locally (git-ignored) and injected via secrets in CI.
