# DevOps Skill — HealthWallet.me CI/CD

## Overview

You are a DevOps assistant for the HealthWallet.me Flutter mobile app. You help maintain, troubleshoot, and extend the CI/CD pipeline built with **Fastlane + GitHub Actions**.

## Project Context

| Property | Value |
|----------|-------|
| Package ID (both platforms) | `com.techstackapps.healthwallet` |
| iOS Share Extension Bundle ID | `com.techstackapps.healthwallet.Share-Extension` |
| Apple Team ID | Found in `ios/fastlane/Appfile` (local only) |
| Flutter version | 3.32.4 (managed via FVM) |
| Android build system | Kotlin DSL (`build.gradle.kts`), AGP 8.7.3, Java 17 |
| iOS workspace | `Runner.xcworkspace` (includes Share Extension) |
| Main branch | `master` |
| Develop branch | `develop` |
| Private dependency | `fhir_ips_export` via SSH on `git.techstackapps.com:2822` |

## Branching Strategy (GitFlow)

- `master` — production releases
- `develop` — integration branch
- `feature/*` — new features (branch from `develop`)
- `release/*` — release candidates (branch from `develop`, merge to both `master` and `develop`)
- `hotfix/*` — urgent fixes (branch from `master`, merge to both `master` and `develop`)

## Build Stack

### Code Generation (required before every build)
```bash
dart run build_runner build --delete-conflicting-outputs
```
Generates: `*.freezed.dart`, `*.g.dart`, `*.config.dart`, `*.gr.dart` (all gitignored)

### Android
- Signing: `android/key.properties` → `upload-keystore.jks`
- Build output remapped: `android/build.gradle.kts` sets `buildDirectory` to `../../build` (relative to `android/`)
- AAB path: `build/app/outputs/bundle/release/app-release.aab`
- Gradle heap: 8GB locally, **reduced to 4GB on CI** (GitHub runners have ~7GB RAM)

### iOS
- Signing: Automatic locally, **overridden to Manual on CI** via `update_code_signing_settings`
- Certificates: Fastlane Match (appstore type) for both Runner and Share Extension
- Build: `gym` via `Runner.xcworkspace`

## CI/CD Pipeline Architecture

See `references/architecture.md` for the full pipeline diagram.

### Workflows
1. **CI** (`.github/workflows/ci.yml`) — runs on push/PR to `master`/`develop`; analyze + test
2. **Android Deploy** (`.github/workflows/android-deploy.yml`) — manual trigger; builds AAB + uploads to Google Play
3. **iOS Deploy** (`.github/workflows/ios-deploy.yml`) — manual trigger; builds IPA + uploads to TestFlight

### Secrets
See `references/secrets-inventory.md` for the full list with generation instructions.

## Troubleshooting Patterns

### Gradle OOM on CI
**Symptom:** Android build fails with `java.lang.OutOfMemoryError`
**Fix:** The workflow already reduces heap to 4GB. If still failing, consider using a `large` runner or further reducing parallel Gradle workers:
```
org.gradle.workers.max=2
```

### Match certificate issues
**Symptom:** `Could not find a matching code signing identity`
**Fix:**
1. Ensure Match certificates are not expired: `cd ios && bundle exec fastlane match nuke appstore` then re-create
2. Verify both bundle IDs are in Matchfile
3. Check that `MATCH_PASSWORD` secret is correct

### Private dependency SSH timeout
**Symptom:** `pub get` fails with SSH connection timeout
**Fix:**
1. Verify `SSH_PRIVATE_KEY` secret contains the correct key for `git.techstackapps.com:2822`
2. Check if the host key has changed — may need to update `ssh-keyscan` output
3. Fallback: hardcode the known host key instead of using `ssh-keyscan`

### Share Extension not included in archive
**Symptom:** TestFlight build missing Share Extension
**Fix:** Ensure the Xcode scheme has `buildImplicitDependencies = "YES"` and the Share Extension target is listed in Build phases.

### Code generation failures
**Symptom:** `build_runner` fails with conflicting outputs
**Fix:** Always use `--delete-conflicting-outputs` flag. If persistent, check for circular imports in freezed models.

## References

- `checklists/prerequisites.md` — First-time setup guide
- `checklists/pre-release.md` — Pre-release validation
- `references/architecture.md` — Pipeline architecture
- `references/secrets-inventory.md` — GitHub Secrets inventory
