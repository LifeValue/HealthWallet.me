<!-- bmad:context -->
<!-- Verified 2026-10-22 against eef6c7f. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## HealthWallet.me

Patient-controlled health record app in Flutter: FHIR R4 records from providers through a self-hosted Fasten Health backend, on-device AI document scanning (llamadart), offline-first storage in Drift/SQLite. One codebase ships mobile (iOS, Android) and desktop (macOS, Windows, Linux), which pair and sync over an encrypted local link. Architecture and protocol reference: `_bmad-output/planning-artifacts/architecture.md`. Current priority and known issues: `_bmad-output/planning-artifacts/mobile-stabilization.md` (stabilize mobile; desktop is aligned later).

## Policy

- Never commit or stage secrets (`.pem`, `.p8`, `.p12`, `.key`, `.jks`, `.keystore`, `service-account*.json`, `.env`, API keys, tokens); they live in protected GitLab CI/CD variables. Before every commit run `git diff --cached --name-only | grep -iE '\.(pem|p8|p12|key|jks|keystore)$|service-account|\.env$'` and stop if it prints anything.
- Never hardcode keys or tokens; read them through envied (`lib/core/config/env/env.dart`, values from `.env`).
- Keep Clean Architecture: presentation → domain → data, dependencies by constructor. Business logic (transformations, calculations, validation) belongs in BLoCs, repositories, services or use cases, never in widgets.
- Never move or rename `docs/`: it is the live emergency.healthwallet.me page (GitHub Pages) that the QR code on every wallet pass opens. Put developer and agent docs in `_bmad-output/` (`project-knowledge/` for how the app works, `planning-artifacts/` for plans and architecture).
- Change the QR payload in `lib/features/wallet_pass/data/service/emergency_qr_encoder.dart` only together with `docs/index.html`, and keep the page decoding the old format; passes already in users' wallets keep their QR.
- Branches follow Gitflow: `master` is production, `develop` staging (betas to TestFlight and Play internal are deployed by hand from its pipeline). `feature/*` and `bugfix/*` branch from `develop` and merge back into it; `release/*` branches from `develop` and merges into `master` and `develop`; `hotfix/*` branches from `master` and merges into both. Name branches after the work, without the ticket number. Merge with `--no-ff`, never fast-forward.
- GitLab CI (`.gitlab-ci.yml`) is the only CI. Don't edit `.github/workflows/`; they are unused and the GitHub repo is left untouched. Deploys run only from `develop`, `release/*`, `hotfix/*` and `master`, always started by hand, after every check passes.

## Where things are

- Entry points: `lib/main.dart` (mobile) and `lib/main_desktop.dart` (desktop: communication, tray, backup, handover and LWW sync BLoCs).
- DI `lib/core/di/` (`configureDependencies()`), routes `lib/core/navigation/app_router.dart`, database `lib/core/data/local/app_database.dart`, UI kit `lib/core/widgets/` and `lib/core/theme/`.
- Before changing `lib/features/processing/`, `lib/features/capture/` or `lib/features/desktop/`, read the matching section of `_bmad-output/planning-artifacts/architecture.md` (pipeline stages, wire protocol, message types, LWW rules).

## Running and verifying

- Run Flutter and Dart through FVM (`fvm flutter …`, `fvm dart …`); the pinned version is in `.fvmrc`.
- After changing Freezed models, routes, injectable registrations, Drift tables or envied variables, run `fvm dart run build_runner build`. Its outputs are gitignored, so never commit them.
- Desktop builds and runs need the desktop entry point (`fvm flutter build macos --release --target lib/main_desktop.dart`, same for `windows` and `linux`, and `fvm flutter run -d macos -t lib/main_desktop.dart`); without it you build the mobile app. `scripts/build_windows.ps1 [-Msix]` builds and packages Windows; `scripts/package_linux.sh` packages a Linux build as a .deb and a tarball.
- Linux builds only on Ubuntu 24.04, Debian 13 or newer (llamadart's libraries need glibc 2.38), with Flutter's Linux toolchain plus `libsecret-1-dev libayatana-appindicator3-dev libtesseract-dev libleptonica-dev`. From a Mac, build in an `ubuntu:24.04` container; `linux:snap` in `.gitlab-ci.yml` builds in Canonical's snapcraft image, which is Ubuntu 24.04.
- Every file is formatted before it is committed. `npm install` installs the hooks from `.pre-commit-config.yaml` (it needs `pre-commit` on the machine, `brew install pre-commit`), and they run only on the staged files: `dart format` for Dart; Prettier for YAML, JSON, ARB, Markdown, HTML, CSS, JavaScript and XML; swift-format for Swift; ktlint for Kotlin and Gradle scripts; clang-format for C/C++; gersemi for CMake; RuboCop (layout only) for Fastlane, Podfile and Gemfile; shfmt and shellcheck for shell scripts; whitespace and end-of-file fixes for everything else. A hook that reformats a file fails the commit: review the change, `git add` it and commit again.
- Generated and tool-managed files are never reformatted: `app_localizations*.dart`, `*.gen.dart`, `test/drift/my_database/generated/`, `windows/flutter/`, `linux/flutter/`, Xcode project files (`.pbxproj`, `.plist`, storyboards, `.xcassets`) and `assets/`. The exclusions are listed in `.pre-commit-config.yaml` and `.prettierignore`.
- Run `scripts/check.sh` before pushing: it runs the formatters on the files the branch changed since `develop`, then `fvm flutter analyze` and `fvm flutter test`, and must pass with no issues, infos included. Run `pre-commit run --all-files` only after changing a formatter's configuration. CI enforces the same and more: `checks` (dart format, analyze, test, coverage floors), `lint` (formatters and commitlint on the changed files), `scan:dependencies` (osv-scanner on every lockfile) and `scan:secrets` (gitleaks over the commits the branch adds) run in parallel, and any failure fails the pipeline. `test:integration` runs `integration_test/app_l10n_test.dart` on an iOS simulator on the Mac mini: automatically on `develop`, `release/*` and `master`, and automatically and required on every push to `feature/*`, `bugfix/*` and `hotfix/*`, so it must pass before the merge; by hand on other branches. A dependency with a known vulnerability is updated, not ignored. Only when no fixed version can be installed (e.g. a transitive one its parent caps), ignore that one advisory in an `osv-scanner.toml` next to the lockfile, with the reason and an `ignoreUntil` date.
- `scripts/coverage.sh` prints test coverage for the whole app, each feature and the critical areas listed in `tool/coverage_report.dart` (`--files <dir>` for per-file numbers). Each critical area has a floor in `tool/coverage_floors.json`, and CI's `checks` fails when an area drops below it (`scripts/coverage.sh --check` locally). The floors only go up: after adding tests, run `scripts/coverage.sh --ratchet` and commit the file. A new critical area needs a floor too.
- Fix lints rather than silencing them; when a rule is wrong for one line, use `// ignore: <rule>` with a comment saying why. Never write an empty `catch`: log the error with `logger` or comment why it is safe to ignore.
- `pub get` needs SSH access to `git.lifevalue.com` (port 2822) for `fhir_ips_export` and `airdrop`; if it fails, tell the user rather than removing or stubbing the dependency.

## Conventions that differ from defaults

- Models, events and states are Freezed; BLoC handlers set `transformer:` (`restartable()`, `sequential()`, `droppable()`).
- Use constructor injection in `domain/` and `data/`; `getIt<T>()` is acceptable only in `presentation/`.
- Gate features with `getIt<AppPlatform>().isDesktop`; switch layouts with `context.isDesktopWidth` (≥ 1024 px). Use `context.screenHorizontalPadding`, and inside a constrained sub-area (e.g. the desktop right panel) apply the same breakpoints to `LayoutBuilder` `constraints.maxWidth` so padding lines up with the header.
- Use `context.l10n`, `context.theme` and `context.isDarkMode` (`lib/core/l10n/l10n.dart`, `lib/core/utils/build_context_extension.dart`), not `AppLocalizations.of` or `Theme.of`.
- New UI uses `AppButton`, `AppSimpleDialog`, `AppColors`, `AppTextStyle` and `Insets` from `lib/core/widgets/` and `lib/core/theme/`, not raw Material buttons, `AlertDialog`, color literals, `TextStyle(` or numeric `EdgeInsets`.
- Add every new string to all four ARB files in `lib/core/l10n/arb/` (en, es, de, ro) and run `fvm flutter gen-l10n`. The generated `app_localizations*.dart` files are committed: commit them with the ARB change and never edit them by hand. `untranslated_messages.json` must not list any key you added. After adding a string or changing an English one (and its translations), run `fvm dart run tool/update_translation_baseline.dart`: `arb_parity_test.dart` fails while an English text differs from the one its translations were made from, or a translated plural lacks a form its language needs.
- OCR goes through the native `dev.lifevalue.healthwallet/ocr` channel on every platform (Tesseract in the Linux runner). Never add an OCR Flutter plugin; its ML Kit pods stop iOS running on arm64 simulators.
- Drift schema change: bump `schemaVersion` and add the step to `onUpgrade` as hand-written SQL (v1→8 stay on `stepByStep`), declaring added nullable columns as `TYPE NULL` so they match drift's snapshots. Then run `fvm dart run drift_dev schema dump lib/core/data/local/app_database.dart drift_schemas/my_database/` and `fvm dart run drift_dev schema generate --data-classes --companions drift_schemas/my_database/ test/drift/my_database/generated/`, and add a test to `test/drift/my_database/migration_test.dart`.
- Only `fhir_resource`, `sources` and `record_notes` sync between mobile and desktop (last write wins on `updated_at`, kept current by triggers); `processing_sessions` stays local. A change to a synced table's columns or row shape must work on both ends.
- Tests use fake repositories (see `test/widget_test.dart`), not mocks, for the repository layer.
- Commits follow Conventional Commits, enforced by commitlint in the `commit-msg` hook: `type(scope): subject`, one short sentence, no body or footers (no `Co-Authored-By`). The scope is the area of code (`desktop`, `records`, `db`, `deps`), never a ticket number; leave it out for cross-cutting changes. Keep each commit to one logical change.
- pdfx has no Linux implementation: draw or check PDF pages through `PdfPages` (`lib/core/utils/pdf_pages.dart`), which uses printing's rasteriser on Linux, and show them on the desktop with `DesktopPdfView`. Tests set `PdfPages.usePdfx` so they don't depend on the host (CI runs on Linux).
- Keep `android.builtInKotlin=false` and `android.newDsl=false` in `android/gradle.properties`; AGP 9 runs in compatibility mode because most plugins still apply the Kotlin Gradle plugin.

## Known pitfalls

- Unsent LWW changes live in the `sync_outbox` table, filled by triggers; `lib/main.dart` only removes the `lww_offline_queue` preference older versions left. A write that must not be sent back to the peer goes through `LwwSyncService`'s `_withoutOutbox`.
- In `.gitlab-ci.yml`, keep the Android jobs on the pinned Temurin JDK (`ANDROID_JDK_*`, set through `org.gradle.java.home`); the JDK Flutter picks on the Mac mini (Android Studio's JBR 17.0.9) crashes the Gradle daemon. Keep one `resource_group` per upload job so overlapping pipelines don't take the same build number.

<!-- /bmad:context -->
