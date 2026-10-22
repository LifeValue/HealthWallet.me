<!-- bmad:context -->
<!-- Verified 2026-10-22 against eef6c7f. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## HealthWallet.me

Patient-controlled health record app in Flutter: FHIR R4 records from providers through a self-hosted Fasten Health backend, on-device AI document scanning (llamadart), offline-first storage in Drift/SQLite. One codebase ships mobile (iOS, Android) and desktop (macOS, Windows), which pair and sync over an encrypted local link. Architecture and protocol reference: `doc/architecture.md`. BMad planning output: `_bmad-output/`.

## Policy

- Never commit or stage secrets (`.pem`, `.p8`, `.p12`, `.key`, `.jks`, `.keystore`, `service-account*.json`, `.env`, API keys, tokens); they live in protected GitLab CI/CD variables. Before every commit run `git diff --cached --name-only | grep -iE '\.(pem|p8|p12|key|jks|keystore)$|service-account|\.env$'` and stop if it prints anything.
- Never hardcode keys or tokens; read them through envied (`lib/core/config/env/env.dart`, values from `.env`).
- Keep Clean Architecture: presentation → domain → data, dependencies by constructor. Business logic (transformations, calculations, validation) belongs in BLoCs, repositories, services or use cases, never in widgets.
- Never move or rename `docs/`: it is the live emergency.healthwallet.me page (GitHub Pages) that the QR code on every wallet pass opens. Put developer and agent docs in `doc/`.
- Change the QR payload in `lib/features/wallet_pass/data/service/emergency_qr_encoder.dart` only together with `docs/index.html`, and keep the page decoding the old format; passes already in users' wallets keep their QR.
- Branches: `master` is production, `develop` staging (every push uploads betas to TestFlight and Play internal), work happens on `dev/*`, `feature/*`, `fix/*`, `release/*`, `hotfix/*`. Merge with `--no-ff`, never fast-forward.
- GitLab CI (`.gitlab-ci.yml`) is the only CI. Don't edit `.github/workflows/`; they are unused and the GitHub repo is left untouched.

## Where things are

- Entry points: `lib/main.dart` (mobile) and `lib/main_desktop.dart` (desktop: communication, tray, backup, handover and LWW sync BLoCs).
- DI `lib/core/di/` (`configureDependencies()`), routes `lib/core/navigation/app_router.dart`, database `lib/core/data/local/app_database.dart`, UI kit `lib/core/widgets/` and `lib/core/theme/`.
- Before changing `lib/features/processing/`, `lib/features/capture/` or `lib/features/desktop/`, read the matching section of `doc/architecture.md` (pipeline stages, wire protocol, message types, LWW rules).

## Running and verifying

- Run Flutter and Dart through FVM (`fvm flutter …`, `fvm dart …`); the pinned version is in `.fvmrc`.
- After changing Freezed models, routes, injectable registrations, Drift tables or envied variables, run `fvm dart run build_runner build`. Its outputs are gitignored, so never commit them.
- Desktop builds and runs need the desktop entry point (`fvm flutter build macos --release --target lib/main_desktop.dart`, same for `windows`, and `fvm flutter run -d macos -t lib/main_desktop.dart`); without it you build the mobile app.
- Run `fvm flutter analyze` and `fvm flutter test` before committing; the CI `checks` job fails only on analyzer errors, so warnings you add are not caught.
- `pub get` needs SSH access to `git.techstackapps.com` for `fhir_ips_export` and `airdrop`; if it fails, tell the user rather than removing or stubbing the dependency.

## Conventions that differ from defaults

- Models, events and states are Freezed; BLoC handlers set `transformer:` (`restartable()`, `sequential()`, `droppable()`).
- Use constructor injection in `domain/` and `data/`; `getIt<T>()` is acceptable only in `presentation/`.
- Gate features with `getIt<AppPlatform>().isDesktop`; switch layouts with `context.isDesktopWidth` (≥ 1024 px). Use `context.screenHorizontalPadding`, and inside a constrained sub-area (e.g. the desktop right panel) apply the same breakpoints to `LayoutBuilder` `constraints.maxWidth` so padding lines up with the header.
- Use `context.l10n`, `context.theme` and `context.isDarkMode` (`lib/core/l10n/l10n.dart`, `lib/core/utils/build_context_extension.dart`), not `AppLocalizations.of` or `Theme.of`.
- New UI uses `AppButton`, `AppSimpleDialog`, `AppColors`, `AppTextStyle` and `Insets` from `lib/core/widgets/` and `lib/core/theme/`, not raw Material buttons, `AlertDialog`, color literals, `TextStyle(` or numeric `EdgeInsets`.
- Add every new string to all four ARB files in `lib/core/l10n/arb/` (en, es, de, ro) and run `fvm flutter gen-l10n`. The generated `app_localizations*.dart` files are committed: commit them with the ARB change and never edit them by hand. `untranslated_messages.json` must not list any key you added.
- OCR goes through the native `dev.lifevalue.healthwallet/ocr` channel on every platform. Never add an OCR Flutter plugin; its ML Kit pods stop iOS running on arm64 simulators.
- Drift schema change: bump `schemaVersion` and add the step to `onUpgrade` as hand-written SQL (v1→8 stay on `stepByStep`), declaring added nullable columns as `TYPE NULL` so they match drift's snapshots. Then run `fvm dart run drift_dev schema dump lib/core/data/local/app_database.dart drift_schemas/my_database/` and `fvm dart run drift_dev schema generate --data-classes --companions drift_schemas/my_database/ test/drift/my_database/generated/`, and add a test to `test/drift/my_database/migration_test.dart`.
- Only `fhir_resource`, `sources` and `record_notes` sync between mobile and desktop (last write wins on `updated_at`, kept current by triggers); `processing_sessions` stays local. A change to a synced table's columns or row shape must work on both ends.
- Tests use fake repositories (see `test/widget_test.dart`), not mocks, for the repository layer.
- Commit messages are conventional commits, `type(scope): subject`, with a feature (`desktop`, `records`, `db`) or a ticket (`HM-181`) as scope.
- Keep the `Platform.isLinux` branches for a future port, and don't scaffold `linux/`.
- Keep `android.builtInKotlin=false` and `android.newDsl=false` in `android/gradle.properties`; AGP 9 runs in compatibility mode because most plugins still apply the Kotlin Gradle plugin.

## Known pitfalls

- `lib/main.dart` clears `lww_offline_queue` on every mobile start; never rely on queued LWW changes surviving an app restart.
- In `.gitlab-ci.yml`, keep the Android jobs on the pinned Temurin JDK (`ANDROID_JDK_*`, set through `org.gradle.java.home`); the JDK Flutter picks on the Mac mini (Android Studio's JBR 17.0.9) crashes the Gradle daemon. Keep one `resource_group` per upload job so overlapping pipelines don't take the same build number.

<!-- /bmad:context -->
