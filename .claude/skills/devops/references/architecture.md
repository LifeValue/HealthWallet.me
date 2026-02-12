# CI/CD Pipeline Architecture

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
│                                                                   │
│  master ──────┬──── Push/PR ────→ CI Workflow (analyze + test)   │
│  develop ─────┘                   (ubuntu-latest)                │
│                                                                   │
│  Manual Trigger ──→ Android Deploy Workflow ──→ Google Play      │
│                     (ubuntu-latest)                               │
│                                                                   │
│  Manual Trigger ──→ iOS Deploy Workflow ──→ TestFlight           │
│                     (self-hosted Mac Mini)                        │
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
  ├── Install Flutter 3.32.4 (subosito/flutter-action)
  │
  ├── Create .env from secret
  │
  ├── flutter pub get
  │
  ├── dart run build_runner build
  │
  ├── flutter analyze --no-fatal-infos --no-fatal-warnings
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
  ├── Install Flutter 3.32.4 (subosito/flutter-action)
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
**Runner:** `[self-hosted, macOS]` — Mac Mini with FVM, Ruby, CocoaPods pre-installed

```
Checkout
  │
  ├── Configure SSH (webfactory/ssh-agent)
  │     └── Loads SSH_PRIVATE_KEY for both git.techstackapps.com and github.com
  │
  ├── Add hosts to known_hosts
  │     └── git.techstackapps.com:2822 + github.com
  │
  ├── Restore API key from secret
  │     └── Writes raw ASC_KEY_CONTENT → ios/fastlane/private_keys/AuthKey.p8
  │
  ├── fvm flutter pub get
  │
  ├── fvm dart run build_runner build
  │
  ├── cd ios && rm -rf Podfile.lock Pods && pod install --repo-update
  │
  ├── cd ios && bundle install
  │
  ├── Setup CI keychain
  │     └── Creates ci_build.keychain-db with password "ci"
  │     └── Sets as default keychain
  │
  ├── Deploy to TestFlight
  │     └── Env vars: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH,
  │         MATCH_GIT_URL (SSH), MATCH_PASSWORD,
  │         MATCH_KEYCHAIN_NAME, MATCH_KEYCHAIN_PASSWORD
  │     └── cd ios && bundle exec fastlane <lane>
  │
  └── Cleanup (always)
        └── Delete ci_build.keychain-db
        └── Restore login.keychain-db as default
        └── rm -rf ios/fastlane/private_keys
```

## Self-Hosted Runner (Mac Mini)

The iOS deploy workflow runs on a self-hosted macOS runner.

| Property | Value |
|----------|-------|
| Location | Mac Mini (`ciagent` user) |
| Runner directory | `/Users/ciagent/actions-runner/` |
| Service name | `actions.runner.LifeValue-HealthWallet.me.mac-mini` |
| Work directory | `/Users/ciagent/actions-runner/_work/HealthWallet.me/` |
| Pre-installed tools | FVM (Flutter 3.32.4), Ruby 3.0.0 (rbenv), CocoaPods 1.16.2, Xcode |

The runner's `.env` file at `/Users/ciagent/actions-runner/.env` configures PATH to include FVM, rbenv, Homebrew, and other tools.

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
| `beta` | Sync certs → flutter build (via Bundler.with_unbundled_env) → override signing → build → upload | TestFlight |
| `release` | Calls `beta` (production promotion is manual in ASC) | TestFlight |

**Key implementation details:**
- Uses `fvm flutter` (not bare `flutter`) for builds
- Wraps flutter build in `Bundler.with_unbundled_env` so CocoaPods is visible to Flutter
- Auto-increments build number from `latest_testflight_build_number + 1`
- ASC API key loaded from file (`ASC_KEY_PATH`) or base64 env var (`ASC_KEY_CONTENT`)

## Build Version Strategy

Both platforms use **automatic build number incrementing** — no manual version bumps needed for build numbers.

### Version Name (e.g., `1.1.1`)
- Read from `pubspec.yaml` (`version: X.Y.Z+N` → extracts `X.Y.Z`)
- Bump manually in `pubspec.yaml` when releasing a new version
- The `+N` part in pubspec is ignored by Fastlane (build number is auto-managed)

### Build Number (auto-incremented)

| Platform | Source | Method |
|----------|--------|--------|
| **iOS** | TestFlight | `latest_testflight_build_number(version: version_name) + 1` |
| **Android** | Google Play | `google_play_track_version_codes(track: "internal")[0] + 1` |

This means:
- You only bump the **version name** in `pubspec.yaml` (e.g., `1.1.1` → `1.2.0`)
- Build numbers are **never set manually** — they auto-increment from the store
- Each deploy gets the next sequential build number for that version
- If TestFlight/Play Store has no builds for the version, it starts at 1

### How it flows
```
pubspec.yaml: version: 1.2.0+22  (the +22 is ignored by Fastlane)
                          │
              ┌───────────┴───────────┐
              │                       │
         iOS Fastlane           Android Fastlane
              │                       │
  TestFlight latest: 7     Play Store latest: 45
              │                       │
  Build: 1.2.0 (8)        Build: 1.2.0 (46)
```

## Signing Strategy

### Android
- `key.properties` file references `upload-keystore.jks`
- On CI: keystore decoded from base64 secret, `key.properties` written from individual secrets

### iOS
- **Local:** Automatic signing (Xcode manages), `.env` file provides Match credentials
- **CI:** Manual signing via `update_code_signing_settings` at build time
- Certificates: Fastlane Match (appstore type) from a private git repo (cloned via SSH)
- Two provisioning profiles: Runner + Share Extension
- CI keychain: Temporary `ci_build.keychain-db` created per build, deleted after
