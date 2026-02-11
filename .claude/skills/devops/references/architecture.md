# CI/CD Pipeline Architecture

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
│                                                                   │
│  master ──────┬──── Push/PR ────→ CI Workflow (analyze + test)   │
│  develop ─────┘                                                   │
│                                                                   │
│  Manual Trigger ──→ Android Deploy Workflow ──→ Google Play      │
│  Manual Trigger ──→ iOS Deploy Workflow ──→ TestFlight           │
└─────────────────────────────────────────────────────────────────┘
```

## Workflow Details

### 1. CI Workflow (`ci.yml`)

**Triggers:** Push to `master`/`develop`, PRs targeting `master`/`develop`
**Runner:** `ubuntu-latest`

```
Checkout
  │
  ├── Configure SSH (private dependency)
  │
  ├── Install Flutter 3.32.4
  │
  ├── Create .env from secret
  │
  ├── flutter pub get
  │
  ├── dart run build_runner build
  │
  ├── flutter analyze --no-fatal-infos
  │
  └── flutter test --coverage
```

### 2. Android Deploy Workflow (`android-deploy.yml`)

**Trigger:** `workflow_dispatch` with track selection (internal/production)
**Runner:** `ubuntu-latest`

```
Checkout
  │
  ├── Configure SSH (private dependency)
  │
  ├── Setup Java 17 (Temurin)
  │
  ├── Install Flutter 3.32.4
  │
  ├── Create .env from secret
  │
  ├── Decode keystore → android/app/upload-keystore.jks
  │
  ├── Write android/key.properties
  │
  ├── flutter pub get + code generation
  │
  ├── Reduce Gradle heap (8GB → 4GB)
  │
  ├── flutter build appbundle --release
  │
  ├── Decode service account JSON
  │
  ├── Setup Ruby 3.2 + bundle install
  │
  ├── fastlane beta OR release (based on track)
  │
  └── Cleanup sensitive files (always)
```

### 3. iOS Deploy Workflow (`ios-deploy.yml`)

**Trigger:** `workflow_dispatch` with lane selection (beta/release)
**Runner:** `macos-15` (Xcode 16.x)

```
Checkout
  │
  ├── Configure SSH (private dependency)
  │
  ├── Install Flutter 3.32.4
  │
  ├── Create .env from secret
  │
  ├── flutter pub get + code generation
  │
  ├── pod install
  │
  ├── Setup Ruby 3.2 + bundle install
  │
  ├── Configure Match git credentials
  │
  ├── Create CI keychain (fastlane_keychain)
  │
  ├── fastlane beta OR release (based on lane)
  │
  └── Delete keychain + credentials (always)
```

## Fastlane Lanes

### Android (`android/fastlane/Fastfile`)

| Lane | Action | Google Play Track |
|------|--------|-------------------|
| `beta` | Upload AAB via `supply` | internal |
| `release` | Upload AAB via `supply` | production |

### iOS (`ios/fastlane/Fastfile`)

| Lane | Action | Destination |
|------|--------|-------------|
| `sync_certificates` | Match appstore for both bundle IDs | — |
| `beta` | Sync certs → override signing → build → upload | TestFlight |
| `release` | Calls `beta` (production promotion is manual in ASC) | TestFlight |

## Signing Strategy

### Android
- `key.properties` file references `upload-keystore.jks`
- On CI: keystore decoded from base64 secret, `key.properties` written from individual secrets

### iOS
- **Local:** Automatic signing (Xcode manages)
- **CI:** Manual signing via `update_code_signing_settings` at build time
- Certificates: Fastlane Match (appstore type) from a private git repo
- Two provisioning profiles: Runner + Share Extension
