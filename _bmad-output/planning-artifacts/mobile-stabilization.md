# Mobile stabilization backlog

The problems found while reading the code (October 2026), sorted for the next period: **stabilize the mobile app (iOS, Android) first; the desktop app stays as it is and is aligned later.** Each item is meant to become one HM ticket and one branch.

Items marked _(likely)_ were inferred from the code and need to be confirmed on a device first.

## Rules for this period

1. **A fix starts with a test that fails.** Write the test that shows the bug, then fix it. A bug fixed without a test can come back unnoticed.
2. **A skipped `BUG:` test is a ticket.** The suite has 24 skipped tests, each describing a known bug (section 6). Fixing the bug means removing the `skip:` so the test runs and passes.
3. **Code you touch leaves with tests.** A BLoC, repository or service you change gets tests for the behaviour you changed, even if it had none before.
4. **Don't break the desktop contract.** The desktop isn't being worked on, but phones already pair with it. A mobile change to `fhir_resource`, `sources` or `record_notes`, or to the messages sent to the desktop, must keep working on the desktop side. The LWW sync, wire protocol and handover tests protect this; keep them green.
5. **No silent failures in new code.** Never write an empty `catch`; log the error and show the user what happened.

## 1. Security (first)

| #   | Problem                                                                                                                                                                                                                                                     | Where                                                                    |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| S1  | **Signing keys ship inside the app.** `assets/certs/` and `assets/certs/android/` are app assets, so the Apple pass private key and the Google Wallet service-account key are in every IPA and APK. Move signing to a server, or rotate the keys and keep them out of the build. _Not done: needs a signing server; in `deferred-work.md`._ | `pubspec.yaml` (assets)                                                  |
| S2  | **The biometric lock can be bypassed.** A failed check sends the user to onboarding, and **Get Started** opens the dashboard without checking again. The lock also doesn't come back when the app returns from the background. _Done on `feature/mobile-stabilization` (mobile and desktop): one lock screen covers every route, a failed check stays on it, it locks again after 30 s away, links open behind it, turning it off needs authentication; see `_bmad-output/implementation-artifacts/spec-security-hardening.md`._ | `splash_page.dart`, `onboarding_navigation.dart`                         |
| S3  | **The share debug log ships in release builds.** A terminal icon on the share screens opens it, and it writes to `Documents/share_debug.log` with no size limit. _Done on `feature/mobile-stabilization`, with the same fix for `scan_debug.log`: both logs, their icons and `debugPrint` exist only outside release builds, and release builds delete the old files._ | `share_log_buffer.dart`, `transfer_views.dart`                           |
| S4  | **A failed share leaves the health-record JSON in plain text** in the temp directory (pinned by a skipped test). _Done on `feature/mobile-stabilization`: the share JSON, received sessions, IPS PDFs and the wallet pass are deleted after use, and a start-up sweep removes leftovers._ | `share_records/data/service/`                                            |
| S5  | **Shared records have no encryption of their own;** they rely on the transport. MultipeerConnectivity encrypts; whether the hotspot and Wi-Fi Direct TCP paths do is not verified. _Not done: the hotspot and Wi-Fi Direct paths send plain JSON and the BLE hotspot credentials are unencrypted; needs `airdrop` changes, in `deferred-work.md`._ | `share_records/`, `airdrop` package                                      |
| S6  | The Fasten token (JWT) is read without checking its signature. Acceptable for a client; note only. _Left out of scope by decision._ | `sync/`                                                                  |

## 2. Data correctness

| #   | Problem                                                                                                                                                                                                         | Where                                         |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| D1  | **Records deleted in Fasten stay in the app.** `markResourcesAsDeleted` is an empty stub.                                                                                                                       | `sync_local_data_source.dart:182`             |
| D2  | **Every Fasten sync downloads everything;** nothing is incremental. The sync has no timeouts, and **Cancel** only hides the spinner while the request continues.                                               | `sync/`                                       |
| D3  | **A duplicate patient after the first Fasten sync** _(likely)_. The default "Health Wallet Holder" is created before the sync with different identifiers, so the two never merge.                              | `default_patient_service.dart`                |
| D4  | **Notes from a received share are written to the real `record_notes` table** and deleted when the session ends. If the app is killed during the session, they stay. Because `record_notes` syncs, they can also reach the desktop. | `share_records/`                              |
| D5  | **Attaching two files with the same name overwrites the first,** because files are copied under their original name. _Done on `bugfix/record-values-errors-and-deletes`: each file is stored under a unique name and the title keeps the original._                                                                                           | `records/` attachments                        |
| D6  | **Wallet passes include resolved conditions and inactive allergies** (no status filter) and list only `MedicationStatement` medications. _Done on `bugfix/record-values-errors-and-deletes`: resolved, inactive, refuted and entered-in-error items are dropped, active `MedicationRequest`s are added and names are de-duplicated._                                                                         | `wallet_pass/`                                |
| D7  | **One bad entry in a received share throws away the whole share,** and a document whose encounter reference is a list is silently dropped (pinned by skipped tests).                                           | `share_records/data/mapper/`                  |

## 3. Behaviour and silent failures

| #   | Problem                                                                                                                                                                                                                                                                                         | Where                                                         |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| B1  | **IPS export and wallet pass fail without telling the user.** IPS export has `catch (_) {}`; nothing listens to the wallet pass BLoC, whose "added" state is emitted whatever the result. _Partly done on `feature/mobile-stabilization`: the IPS export error is now logged but still not shown; the Google pass "added" state is pinned by a skipped `BUG:` test in `wallet_pass_bloc_test.dart`. Done on `bugfix/record-values-errors-and-deletes`: both show a translated message (Google Wallet only reports a failure to open), as do sync, scan and import errors, without exception text._ | `records_bloc.dart` (IPS export), `wallet_pass_bloc.dart`              |
| B2  | **115 empty `catch (_) {}` blocks in 47 files** (80 outside the desktop feature). Each one hides a failure. Go through them by feature: log with `logger`, show an error where the user is waiting, or comment why ignoring it is safe. _Done outside `desktop/` and `share_records/` on `bugfix/record-values-errors-and-deletes`._                                                         | whole `lib/`                                                  |
| B3  | **Home counts and vitals are capped at 20 records per category** (`getResources` defaults to `limit = 20`). "Recent Records" shows the newest records of the first non-empty category, not the newest overall. Categories overlap, so some records are counted twice.                           | `home/`, `records_repository.dart`                            |
| B4  | **Records filters:** choosing a specialty clears the type filter; specialty and date filters run after paging, so a page can be empty while more matches exist; search ignores the active filters; the Attachments view ignores the date filter; the page reloads on every Home state change. | `records/presentation/`                                       |
| B5  | **AI models and scanning:** cancelling a model download may not stop the transfer _(likely)_; turning Deep Scan on or off applies only after a restart; the default token limit differs between screens (4,096 in Processing, 500 in Preferences); PDF pages are rendered at 72 dpi for OCR and AI, which hurts accuracy on small text. | `processing/`, `capture/`                                     |
| B6  | **Notifications:** the route isn't saved, so old notifications lead nowhere after a restart. Handover banners have an empty route _(likely broken when tapped)_.                                                                                                                                | `notifications/`                                              |
| B7  | **About 40 hardcoded English strings** (among them "Show All", "Patient:", "Attachments / Records" and the notification texts). `untranslated_messages.json` lists 11 German and 7 Spanish and Romanian keys. _Done on `feature/mobile-stabilization`, including the desktop screens: see `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`._                                                                                  | `lib/core/l10n/arb/`                                          |
| B8  | **Every profile update waits one extra second:** `MockUserRemoteDataSource` adds a 1-second delay to theme, name and Share Proximity changes.                                                                                                                                                  | `user_remote_data_source.dart`                                |

## 4. Record display bugs pinned by skipped tests

These change what the user reads on a record, so they belong to stabilization. _All but the two share mapper bugs ("Observation" title, shallow copy) are done on `bugfix/record-values-errors-and-deletes`; the `_history` fix went into `fhir_reference_utils.dart` and the records repository, while the share mapper copy and its skipped test stay with the share feature._ Each one is a skipped test in `test/features/records/domain/utils/extractors/` or `test/features/share_records/data/mapper/`:

- A quantity without a unit shows "7.20 null" (also UCUM quantities with `code` but no `unit`).
- An open range shows "null - 5.00"; an open range onset shows "null - 50".
- A quantity without a value shows "null mmHg".
- Values are rounded to 2 decimals, so a troponin of 0.004 ng/mL shows as "0.00 ng/mL".
- Partial FHIR dates ("2024-03") are formatted as null.
- Only the first coding is read; a later coding with a display is ignored.
- Blood type: without `value.text` it shows the observation's own name ("ABO and Rh group"), and standard SNOMED displays are rejected.
- A shared record whose coding has no display is titled "Observation" instead of using `code.text`.
- "Patient/pat-7/\_history/3" yields the version id "3" instead of the patient id.
- Embedding an attachment in a share changes the original record in memory (shallow copy).

## 5. Cleanup

Dead code that misleads readers. Remove it once the code around it has tests:

- `PdfStorageService`, `ClearDemoData`, `PatientDataUpdatedFromSync` (a no-op), `deleteResourceWithRelated`.
- The old model download methods and `CaptureMode.pdf`.
- `canEditSource`, which returns true in both branches.
- The `healthwallet://add-document` Android intent filter, which nothing handles.
- `build.yaml` excludes `lib/features/backup/data/services/transport/**`, a path that no longer exists.

## 6. Tests: closing the gaps

### Where we are (2026-10-27, `develop` at `ccb49b06`)

1,109 tests pass, 24 are skipped (each a known bug). Line coverage is **13.4%** (5,068 of 37,916 lines; 160 of 459 files are run by any test). The tests that exist are concentrated in the data layer and the desktop link; the mobile app's screens and BLoCs are almost untested.

| Mobile area                     | Coverage | Note                                                     |
| ------------------------------- | -------- | -------------------------------------------------------- |
| `features/home`                 | 0.4%     | Dashboard counts, vitals, edit mode                      |
| `features/dashboard`            | 0.3%     |                                                          |
| `features/capture`              | 1.0%     | Scan and import                                          |
| `features/onboarding`           | 4.3%     | Includes the biometric routing (S2)                      |
| `features/processing`           | 5.4%     | AI pipeline and review form                              |
| `features/notifications`        | 5.7%     |                                                          |
| `features/user`                 | 6.0%     | Profile, patients, preferences                           |
| `core`                          | 12.6%    |                                                          |
| `features/share_records`        | 13.2%    | Data layer 74%, screens untested                         |
| `features/records`              | 15.2%    | Extractors 99%, BLoCs and screens untested               |
| `features/sync`                 | 20.6%    | Data layer 88%                                           |
| `features/wallet_pass`          | 51.3%    | QR and pass building 99.6%                               |
| Critical: Scan → FHIR mapping   | 26.8%    | Turns AI output into records                             |
| Critical: Patient services      | 16.4%    | Patient creation and merging (D3)                        |
| Critical: Database + migrations | 61.3%    | `app_database.steps.dart` 55%                            |

_Update 2026-10-28 (`feature/mobile-stabilization`): 1,695 tests pass and 23 are skipped. User, Records (IPS export), Share Records (transfer) and Wallet Pass now have BLoC tests, plus the new App Lock. Three new `BUG:` pins: the user name save (`user_bloc_test.dart`), a percent-encoded attachment URL not repointed after sync (`lww_sync_service_test.dart`) and the Google pass "added" state (`wallet_pass_bloc_test.dart`). The numbers above and below are the 2026-10-27 baseline._

**None of the 17 mobile BLoCs has a test** (Home, Records, Processing, Sync, User, Patient, Onboarding, Share Records, Wallet Pass, Notifications, Load Model, Attach to Encounter, Record Notes, Record Attachments, Attachment Browse, Focus Mode, Preview). There are no widget tests beyond `test/widget_test.dart` and no integration tests.

### What to add, in order

1. **Tests for every fix in sections 1–4**, written first (rule 1).
2. **BLoC tests for the flows users depend on most:** Records (filters, paging, search, IPS export errors), Home (counts, recent records), Sync (cancel, timeout, error states), Processing (pipeline steps, cancel, review and save), Onboarding (biometric routing, first launch), Wallet Pass (success and failure). Use `bloc_test` with fake repositories, as the rest of the suite does.
3. **The remaining critical areas:** Scan → FHIR mapping and Patient services to the level of the extractors; every migration step in `app_database.steps.dart` covered by `migration_test.dart`.
4. **Widget tests for the screens with logic:** the review form after a scan, the Records filters, the Preferences toggles, the wallet pass and IPS export buttons (error shown to the user).
5. **An integration test on a simulator** for the main path: onboarding → demo data → Records → open a record → add a note and an attachment → IPS export. Then the scan path with a small fixed document.

### Keeping it from slipping back

- Add the new critical areas to `tool/coverage_report.dart` as they get tests: at least the mobile BLoCs (`records/presentation/bloc/`, `processing/presentation/bloc/`, `sync/presentation/bloc/`) and the onboarding/biometric routing.
- Once a critical area has reached its level, make CI fail if its coverage drops (a ratchet per area, not a single global number). Coverage is not a CI gate today.
- A merge request that fixes a bug and adds no test is sent back.

## 7. Process and documentation

- **Release path:** `master` and `release/1.3.0` are 247 and 245 commits behind `develop` and have no `.gitlab-ci.yml`, so nothing can deploy from `master` on GitLab. The first mobile release of this period should merge into `master` and fix that.
- **Fastlane:** the Flutter version is hardcoded (`--flutter-version=3.47.7`), so a `.fvmrc` bump must update the Fastfiles too. If `shorebird release` fails, the lane quietly builds a normal binary that Shorebird can't patch; it should fail instead.
- **Not defined yet:** an MR template and approval rules, linking HM tickets to MRs, who bumps the version, a release checklist, a root `.env.example`, how to regenerate `lib/gen/`.
- **Branch prefixes:** `chore/*` and `fix/*` are used in practice, but the Gitflow rules list only `feature/`, `bugfix/`, `release/` and `hotfix/`. Pick one set.
- **`README.md` is out of date:** version badge 1.2.0, links to `CONTRIBUTING.md` and `changelog.md` that don't exist, a GitHub fork-and-PR flow, only iOS and Android and three languages, an old folder structure, `flutter` instead of `fvm flutter`.
- **`architecture.md` is out of date:** it names `ScanBloc`, `ImportBloc`, `DesktopBloc` and `capture/desktop_import/`, which don't exist; it describes the scan pipeline as "vision, then text fallback" when step 1 runs text first; it shows the pairing QR in the wrong shape; it claims an Immunization extraction from scans that doesn't exist; its CI section is stale. It is to be replaced by a new `bmad-architecture` run.
- **Packages:** pin `fhir_ips_export` and `airdrop` to tags instead of a default branch and `dev/desktop`; add a LICENSE to `airdrop`; decide whether `airdrop` stays a separate repo (then move `DesktopSyncManager` out of it) or moves into this repo as `packages/airdrop`.

## 8. Product decisions to make

Features users may expect that don't exist. Not bugs, so they need a product decision before any work: deleting the account or all data on mobile, exporting data other than IPS, removing demo data, disconnecting Fasten, adding or deleting patients, removing a wallet pass, automatic backups, Immunization extraction from scans.

## 9. Deferred: desktop alignment

Kept here so nothing is lost; not part of this period unless a mobile change touches it.

- **Deletes don't sync between phone and desktop.** Records are hard-deleted, so a deleted record comes back from the other device on the next reconciliation. The `deleted_at` tombstones and the 30-day cleanup exist, but nothing sets `deleted_at`. _Done on `bugfix/record-values-errors-and-deletes`: user deletes write millisecond tombstones that sync, and reads hide them; contract in `architecture.md` (LWW section), details in `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`._
- **The LWW offline queue is cleared on every mobile start,** so changes made while disconnected are lost if the app restarts before the next sync.
- ~~**Restore is not wrapped in a transaction**~~ _(fixed on `feature/mobile-stabilization`: one transaction, only the app's own tables)_, and **backups don't include attachment files.**
- **Handover:** a result clears every pending session on the phone, not only the one sent; the desktop tracks one handover at a time; skipped tests pin file ordering, duplicate files and file-name clashes.
- **TCP server:** a skipped test pins `stopServer` killing the isolate too early. _The replaced client socket and the receive buffer never reset in server mode are fixed on `feature/mobile-stabilization`._
- **Desktop UI:** the empty-state Import and Scan buttons jump to the wrong tabs _(likely)_; the record details side panel can't collapse; a second phone gets no accept/reject dialog because it lives on the unreachable `DesktopPage`; hardcoded strings in the From Phone tab and the tray menu _(translated on `feature/mobile-stabilization`)_.
- **Dead code:** `DesktopPage` and its cards, the unused tab child routes including `SyncRoute`, and the `backup_start`, `backup_chunk` and `backup_complete` messages nothing listens for.
- **Windows:** no runner is registered for `windows:release`, and the Microsoft Store submission is not documented.
