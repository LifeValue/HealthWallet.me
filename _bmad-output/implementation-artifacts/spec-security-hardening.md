---
title: 'Security hardening: app lock, debug logs, temp files, untrusted input'
type: 'bugfix'
created: '2026-10-28'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '9d39795e05c58540cbd4847d97d860accdf91bf8'
context:
  - '{project-root}/_bmad-output/planning-artifacts/mobile-stabilization.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The biometric lock can be bypassed in several ways (S2). Debug logs holding patient data ship in release builds (S3). Health-record files are left in temp (S4). Input from share peers, deep links, the desktop link and backup files reaches file paths and SQL unchecked. All of this applies to mobile and desktop.

**Approach:** One app-wide lock overlay replaces the splash-time check. Debug logs exist only in debug and profile builds. Every health-data temp file is deleted when it is no longer needed, plus a startup sweep. Untrusted input is validated where it enters the app.

## Boundaries & Constraints

**Always:**
- Decisions taken with the user (2026-10-28):
  - **Lock screen:** a failed or cancelled check shows a lock screen with Retry, never onboarding. Biometrics or the device passcode unlock it. It re-locks after more than 30 s in the background. Mobile and desktop share the same lock. Turning the lock off requires a successful authentication.
  - **Debug logs:** the share and scan debug logs, their terminal icons and `debugPrint` output exist only when `!kReleaseMode`. Release builds delete the old `share_debug.log` and `scan_debug.log` on start.
  - **Desktop link:** a client that doesn't send a hello within 15 s (raised from 5 s at the user's request on 2026-10-28) that decrypts with the pairing key and matches its hash is closed. Backup restore is all-or-nothing and only restores the app's own tables.
- Each fix starts with a failing test. Every `BUG:` test the fix covers is un-skipped.
- The wire protocol, QR payloads and synced table shapes stay unchanged, so phones already paired keep working.
- Every new string goes into all four ARBs.

**Never:**
- Secure storage, Android backup rules, DB encryption, transport crypto, `airdrop` changes, S1 signing, S6 (JWT signature).
- Blocking screenshots outside the ephemeral viewer.
- Rejecting http Fasten URLs (self-hosted Fasten must keep working).
- Deleting a whole temp directory. On Windows it is the user's shared `%TEMP%`.
- Deleting the OCR page cache (`pdf_page_*`) or `resized_*`, which processing sessions may still use.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected |
|---|---|---|
| Lock fails | Lock on, auth cancelled | Lock screen stays up. Retry prompts again. No route reachable. |
| Passcode-only device | Lock on, no biometrics, passcode set | Lock shown, passcode unlocks |
| Device no longer secure | Lock on, `isDeviceSupported` false | No lock (the OS can't authenticate) |
| Resume | Lock on, background 31 s / 10 s | Locks / stays unlocked |
| Deep link or share intent while locked | Cold start via link | Overlay covers the dashboard until unlock |
| Disable lock | Toggle off, auth fails | Setting stays on |
| Bad share id | `payload.id` = `../../x` | Share rejected (parse returns null), nothing written |
| Deep link name | `name=../../db.sqlite` | Saved as a sanitised basename inside `provider_downloads/` |
| Huge frame before hello | 4 bytes `FFFFFFFF` | Client dropped, buffer reset, next client works |
| Silent client | Connects, sends nothing for 15 s | Closed. The real phone can still connect. |
| file_request outside docs | `/etc/passwd`, `../x` | Not resolved (null) |
| file_data name | `db.sqlite` | Doesn't overwrite the DB: written under a unique name |
| Restore fails | Backup with a missing column | Throws. Current data intact, `backup_db` detached. |

</frozen-after-approval>

## Code Map

- `lib/app/view/app.dart` -- root widget for both entry points. `builder:` (~205) is where the lock overlay goes, and `didChangeAppLifecycleState` (~60) feeds the lock with lifecycle changes.
- `lib/core/services/biometric_auth_service.dart` -- `isDeviceSecure` (passcode counts as secure), `authenticate`. Use `isDeviceSecure`, not `isBiometricAvailable`, for the lock.
- `lib/features/onboarding/presentation/pages/splash_page.dart` -- `_resolveDestination`. Remove the auth from it.
- `lib/features/user/presentation/bloc/user_bloc.dart` -- `_onBiometricAuthToggled` (~160-218). The disable branch saves without asking for auth.
- `lib/features/user/data/repository/user_repository_impl.dart` -- `isBiometricAuthEnabled`.
- `lib/features/share_records/domain/services/share_log_buffer.dart`, `lib/features/processing/domain/services/processing_log_buffer.dart` -- singleton log buffers, which write to `Documents/*.log`.
- `lib/features/share_records/presentation/widgets/transfer_views.dart` (~71, ~133), `lib/features/processing/presentation/pages/processing_page.dart` (~469) -- terminal icons.
- `lib/main.dart`, `lib/main_desktop.dart` -- startup. Silence `debugPrint`, sweep temp and delete old logs here.
- `lib/features/share_records/data/service/share_records_service.dart` -- `prepareFilesForSending` (38-53) doesn't clean up when it fails. `_parsePayloadBytes` (~84) and `_createSessionTempDir` (111) use `payload.id`.
- `lib/features/share_records/presentation/bloc/share_records_bloc.dart` -- `_tempFilePath` and `close()` (~519). `share_records_transfer_handler.dart` -- the completed path (~321) doesn't clean up.
- `share_records_session_handler.dart` `_cleanupEphemeralData` (89-107) -- `File('').parent` resolves to `.` when there are no attachments.
- `lib/features/records/presentation/bloc/records_bloc.dart` (~383) -- IPS PDF. `lib/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart` (~81) -- `.pkpass`.
- `lib/features/user/presentation/preferences_modal/sections/storage/storage_section.dart` `_performReset` (~270) -- deletes the whole temp directory (desktop only).
- `lib/core/services/deep_link_service.dart` (92-113) -- `customFileName` used in `path.join` without sanitising.
- `lib/features/desktop/communication/data/services/tcp_service.dart` -- server isolate accept (234-280), `_onData` (482), hello check (~523), `_buffer` reset only in client mode (470).
- `lib/features/desktop/lww_sync/data/services/attachment_sync_service.dart` `resolveFile` (137-166) and `lww_sync_service.dart` `saveReceivedFiles` (307-324).
- `lib/features/desktop/backup/data/services/backup_service.dart` `restoreFromFile` (94-142). The Drift tables are `fhir_resource`, `sources`, `record_notes` and `processing_sessions` (`_database.allTables`).
- Tests to reuse:
  - `test/widget_test.dart` -- `FakeUserRepository`, `FakeBiometricAuthService`.
  - `test/features/desktop/desktop_test_fakes.dart` -- `WireCodec`, `PeerSocket`, `FrameReader`.
  - `tcp_service_test.dart` -- skipped test ~938.
  - `share_records_service_test.dart` -- skipped test ~134.
  - `backup_service_test.dart` -- skipped test ~194.
  - `attachment_sync_service_test.dart` -- `resolveFile` group (~265). It currently asserts that absolute paths outside docs resolve; flip that.

## Tasks & Acceptance

**Execution:**
- [x] `lib/features/app_lock/` (new: `presentation/bloc/app_lock_bloc.dart` + Freezed event/state, `presentation/widgets/app_lock_overlay.dart`) -- the bloc gets the auth service, the user repository and a clock by constructor and is registered with injectable. On start, if onboarding is done, the lock is on and the device is secure, it locks and prompts. It locks again when the app resumes after more than 30 s, ignores lifecycle changes while a prompt is open, and Retry prompts again. The overlay is opaque, swallows input and the back button, and uses `AppButton` and l10n -- one gate for every route.
- [x] `lib/app/view/app.dart` -- provide the bloc and stack the overlay in `builder:`, and forward lifecycle changes.
- [x] `splash_page.dart` -- route only to Onboarding or Dashboard.
- [x] `user_bloc.dart` -- authenticate before disabling the lock; if that fails, leave it on.
- [x] `lib/core/l10n/arb/*.arb` -- lock title, message and Retry, then `fvm flutter gen-l10n`.
- [x] Both log buffers and their icons -- no-ops and hidden when `kReleaseMode`. Add a `@visibleForTesting` constructor that sets the flag and the directory.
- [x] `lib/core/services/temp_file_sweeper.dart` (new) -- deletes only these known patterns in temp: `share_*.json`, `share_session_*/`, `* - IPS Summary - *.pdf`, `HealthWallet_Emergency.pkpass`. In release builds it also deletes the two old log files. Call it from `main.dart` and `main_desktop.dart`, and use it in `_performReset` in place of deleting the whole temp directory.
- [x] `main.dart`, `main_desktop.dart` -- `if (kReleaseMode) debugPrint = (_, {wrapWidth}) {};`
- [x] Share service, bloc and handlers -- delete the temp JSON when sending fails, after it completes and in `close()`. Delete `share_session_<id>` by its id. Reject a payload whose `id` isn't a UUID.
- [x] `wallet_pass_bloc.dart` -- delete the `.pkpass` in a `finally` after `addPass` returns. `records_bloc.dart` -- delete the previous IPS PDF before writing a new one. Don't delete right after sharing: Android targets read the file lazily. The startup sweep covers the rest.
- [x] `deep_link_service.dart` -- sanitise the name to a basename. Fall back to a generated name when it is empty, `.` or `..`.
- [x] `tcp_service.dart`
  - Cap frames at 64 KiB until the hello is verified and at 1 GiB after that. Drop any client over the cap. Large LWW deltas and `file_data` messages from the paired phone stay unaffected.
  - Reset `_buffer` on every client connect and disconnect.
  - Server mode: an unauthenticated client is closed after 15 s. Frames before a valid hello aren't forwarded, and a missing hash or a parse error rejects the client.
- [x] `attachment_sync_service.dart` -- `resolveFile` returns only canonical paths inside the docs directory. The fallbacks use a basename with no separators or `..`.
- [x] `lww_sync_service.dart` -- never overwrite: if the name already exists or is `db.sqlite*`, add a unique suffix.
- [x] `backup_service.dart` -- ATTACH, then a transaction (DELETE and INSERT only for tables that are in the app's table list and present in both databases), then DETACH in a `finally`.
- [x] Tests:
  - Every row of the matrix: an `AppLockBloc` bloc_test with fakes, an overlay widget test, and tests for the sweeper, deep link, share, TCP, LWW and backup.
  - Un-skip the three `BUG:` tests listed above.

**Acceptance Criteria:**
- Given a release build, when the share or processing screens open, then no terminal icon is shown and no `.log` file is written.
- Given any change above, when `scripts/check.sh` runs, then format, analyze (no infos) and every test pass, with no `untranslated_messages.json` entries for the new keys.
- Given a phone paired before this change, when it connects to an updated desktop, then pairing, sync, handover and backup still work.

## Design Notes

SQLite refuses `ATTACH` inside a transaction, so the order is attach → `transaction(() { delete; insert })` → detach in `finally`. The lock overlay sits in the `MaterialApp.router` builder, above the Navigator. That covers deep links and share intents without route guards, and it works the same on desktop. Lock screen copy: title "HealthWallet is locked", message "Unlock to view your health records", button "Unlock".

## Verification

**Commands:**
- `fvm dart run build_runner build` -- after the Freezed bloc and injectable registration.
- `scripts/check.sh` -- expected: no issues, all tests pass.

**Manual checks:**
- On a simulator with the lock on: cancel Face ID and check the lock screen stays up; background the app for 35 s and check it locks; open an `add.healthwallet.me` link and check it lands behind the lock.

## Implementation Notes

### Logs and temp files

- **Log buffers:** `ShareLogBuffer` and `ProcessingLogBuffer` take `isEnabled`; the shared instance uses `enabledFor(releaseMode: kReleaseMode)`, a pure seam tested for both modes. Disabled, `log` keeps nothing in memory, notifies no one and writes no file, and the read/clear calls do nothing. `forTesting(enabled:, directory:)` and `debugOverrideInstance` (tests only) let widget tests check the hidden icons. File writes are now chained, so `readPersistedLogs` sees every entry already logged; a failed write is logged instead of swallowed. The terminal icons in `transfer_views.dart` and `processing_page.dart` show only when the buffer is enabled.
- **`TempFileSweeper`** (`lib/core/services/temp_file_sweeper.dart`) is a plain class, not an injectable registration: directory providers, `deleteDebugLogs` (default `deleteDebugLogsFor(releaseMode: kReleaseMode)`) and `includeProcessingCache` (default false; also deletes top-level `pdf_page_*` and `resized_*` and the `<sha256>.json` OCR cache metadata in `Documents/pdf_preview_cache/`) come by constructor. File names and prefixes are public constants on it (`sharePayloadName`, `shareSessionName`, `ipsSummaryName`, `walletPassFileName`, the two log names), and the share service, `RecordsBloc`, `WalletPassBloc` and the log buffers build their names from them (features → core). It lists only the top level of temp without following links and never deletes the temp directory. It is stricter than the spec patterns on the share files: `share_<uuid>.json` and `share_session_<uuid>/` only, so other apps' `share_*.json` in a shared Windows `%TEMP%` stay. `main.dart` and `main_desktop.dart` call `hardenStartup(releaseMode: kReleaseMode)` (`lib/core/services/startup_hardening.dart`) unawaited right after the binding: it silences `debugPrint` in release and starts the sweep. `pdf_conversion_mixin.dart` and `ai_inference_handler.dart` still write `pdf_page_` / `resized_` as literals (not in this part's files); they could use `TempFileSweeper.ocrPagePrefix` / `resizedImagePrefix`.
- **Reset:** `_performReset`'s data deletion moved to `AppDataResetService` (`lib/features/user/data/service/`, plain class) so it can be tested; it runs the sweeper with `deleteDebugLogs: true` and `includeProcessingCache: true` (the reset also deletes `processing_sessions`, and removes the logs in every build mode). `ResetConfirmationDialog` takes an optional `onReset` for tests; by default it runs the service and exits.
- **Share:** `ShareRecordsService.isValidSessionId` (any well-formed UUID, `ValidationMode.nonStrict`) gates parsing; a bad id returns null before anything is written. A share that fails to parse after its session directory was created has that directory deleted. `cleanupSessionTempDir(id)` replaces the `File('').parent` logic and ignores non-UUID ids. `PeerSelected` runs `sequential()`, so two quick selections can't interleave their temp payloads. The BLoC deletes the sent JSON when a peer is selected again (retries used to leak the previous payload), after a completed send (after the state change), on a final failure and in `close()`, and `close()` also deletes a received session's directory. Ephemeral notes are still deleted only on `dataDestroyed` (D4 is out of scope).
- **Wallet pass and IPS:** the `.pkpass` is deleted in a `finally` around `addPass`. `RecordsBloc` keeps the last IPS PDF path and deletes it before writing the next one; the IPS export error is now logged instead of `catch (_) {}`.
- **Bug pinned, not fixed:** `wallet_pass_bloc_test.dart` "a failed save is reported as a failure" (Google `savePassesJwt` isn't awaited, so `passAddedToWallet` is emitted whatever the result; B1).
- **Not covered by a test:** the `processing_page.dart` icon gate (no test pumps `ProcessingPage`; it needs the processing BLoC and DI) and the one-line `hardenStartup` calls in `main*.dart` (the helper itself is tested).

### App lock

- **`AppLockBloc`** (`lib/features/app_lock/presentation/bloc/`, `@lazySingleton`) takes `BiometricAuthService`, `UserRepository`, `SharedPreferences` and `AppLockClock` (`lib/features/app_lock/domain/services/`, a one-method wall clock tests replace). `SharedPreferences` is a fourth dependency the spec didn't list: it reads the `hasSeenOnboarding` flag that `onboarding_navigation.dart` writes, since `UserRepository` has no onboarding getter. States: `checking` (start-up, covered with the splash image so nothing flickers), `locked`, `unlocked`, plus `isAuthenticating` while the OS prompt is open. The lock applies when onboarding is done, the lock is on and `isDeviceSecure()`; if the setting can't be read it fails closed. Retry re-checks `isDeviceSecure()` first, so a device whose passcode was removed while locked unlocks instead of trapping the user.
- **Background timing:** the first `hidden` or `paused` while unlocked starts the clock; `resumed` after more than 30 s locks and prompts. `inactive` and `detached` are ignored (focus loss, notification shade, desktop window switching). Lifecycle changes are ignored while a prompt is open, and the resume prompt runs from the Unlock handler so the prompt's own lifecycle changes are seen and dropped. A resume while already locked doesn't prompt by itself (a cancel would otherwise loop).
- **`AppLockOverlay`** wraps the router in the `MaterialApp.router` builder: an opaque `Material` over the routes with `BlockSemantics`, and `ExcludeFocus` on the routes while covered. It is a `WidgetsBindingObserver` registered before the Router's `RootBackButtonDispatcher` (it is the Router's ancestor), so `didPopRoute` and `handleStartBackGesture` return true while covered. `App` creates the bloc once, starts it in `initState` and forwards every lifecycle change.
- **Splash** routes only on `SharedPrefsConstants.hasSeenOnboarding` (the key the onboarding, sync placeholder and lock now share). **`UserBloc`** asks for authentication before turning the lock off; on a device with no passcode it turns off without a prompt (the OS can't check and the lock doesn't apply). The toggle handler is `droppable()`.
- A wall clock set back while the app is in the background (negative elapsed time) counts as expired and locks.
- **Bug pinned, not fixed:** `user_bloc_test.dart` "reports a failure and keeps the saved name when the save fails" (`_onUserNameUpdated` shows the name before saving, never rolls back, and the save error escapes the handler).
- **Known limits:** a passcode prompt opened from Preferences (enable/disable) isn't known to the lock, so a passcode entry longer than 30 s that sends the app to the background (Android device-credential screen) is followed by a second prompt. No app-switcher privacy cover (out of scope).

### Untrusted input

- **Deep link:** `DeepLinkService.safeFileName` keeps the last segment after any `/` or `\`, drops control characters and trims; empty, `.` and `..` fall back to the generated `provider_doc_<ms><ext>`. Unicode names are kept. `handleDeepLink` is now `@visibleForTesting` and `AppLinks` can be passed in (`@ignoreParam`, so the injectable registration doesn't change). Its empty `catch` blocks now log. A second download with the same name still replaces the earlier file in `provider_downloads/` (unchanged).
- **TCP server:** frames are capped at 64 KiB (`maxUnauthenticatedFrameBytes`) until the hello is verified and at 1 GiB (`maxFrameBytes`) after; the cap is checked on the length prefix, before the body arrives. A client is dropped through a `dropClient` command to the server isolate, keyed by a per-client id so a late drop can't close the next client. Before the hello nothing is forwarded or answered (pings included); a frame that doesn't decrypt, a hello without a string `pairing_key_hash` that matches, or unreadable hello JSON drops the client. `helloTimeout` (15 s; 5 s at first) runs from every `clientConnected`, also for an accepted pending client. `_buffer` resets on connect, disconnect, drop and `stopServer`. The isolate now uses one listener per socket routed by its current role, which also fixes the replaced-client bug (its `BUG:` test is un-skipped). The client side (mobile) applies the 1 GiB cap and resets its buffer on disconnect.
- **Behaviour changes to know:** a hello with the wrong hash now closes the socket (before, it only marked the link disconnected and kept answering pings); an MPC hello without a key hash is now rejected (phones always send one). A pending (second) client is destroyed once it has sent more than 64 KiB + 4 bytes while waiting for the accept dialog; a phone that starts syncing before it is accepted is therefore dropped and reconnects. `pingInterval`/`pingTimeout` became `@visibleForTesting` instance fields (same values) so the keep-alive is tested.
- **`resolveFile`:** candidates are the path itself (relative ones joined to documents), the part after `/Containers/Data/Application/<id>/Documents/` re-rooted in the current documents, and the bare file name in documents; each must be inside documents after normalising and after resolving symbolic links. The temporary-directory fallback and the old remap to the whole app container (outside `Documents`) are gone.
- **`saveReceivedFiles`:** the sanitised base name is used only when it is free (no file, directory or link of that name) and not `db.sqlite*` (case-insensitive); otherwise `<stem>_<8 hex><ext>`. Failures are logged.
- **Backup restore:** ATTACH, then one transaction that empties and refills only `_database.allTables` present in both databases, then DETACH in `finally`. A table missing from the backup keeps its current rows; extra tables in the backup are ignored.
- **Bug pinned, not fixed:** `lww_sync_service_test.dart` "saveReceivedFiles repoints a percent-encoded attachment url" (`_updateAttachmentUrls` filters rows with `raw.contains(oldPath)` on the undecoded JSON, so an attachment stored as `file://scans/lab%20result.pdf` is never repointed to the received file).

## Review Triage Log

Review pass 1 (2026-10-28): Blind Hunter (BH), Edge Case Hunter (EC), Verification Gap (VG).

| # | Finding | Verdict | Evidence | Route |
|---|---|---|---|---|
| BH1, EC1 | Restore fails on `fhir_resource`→`sources` FK | false | `PRAGMA foreign_keys = ON` is set, but no table declares `REFERENCES` (grep of `lib/core/data/local`), so nothing is enforced | reject |
| BH2, EC2 | Restore of a backup with another schema: `SELECT *` mismatch | medium | A positional copy fails (and rolls back) when column counts differ. This predates the change, which only made it all-or-nothing | defer |
| BH3, EC10 | Fail-closed lock with a settings read that keeps throwing → permanent lockout | low | Only a corrupt prefs type makes `getBool` throw; Unlock still prompts, and that succeeds on a secure device | reject |
| BH4, EC5 | Records show in the app switcher and for a frame on resume | low | The user decided screenshots and the app-switcher preview stay as they are (only the share viewer is protected) | reject (intent) |
| BH5, EC6 | Clock set back while backgrounded → never locks | medium | `difference <= lockTimeout` is true for a negative difference (`app_lock_bloc.dart` resumed branch) | patch |
| BH6 | `resolveFile` returns `db.sqlite*` to a paired peer | medium | The DB is `getApplicationDocumentsDirectory()/db.sqlite` (`app_database.dart:336`), inside the docs root `resolveFile` allows | patch |
| BH7, VG1 | `FhirBundleMapper._resolveFile` (proximity share) still accepts absolute paths, `../`, Caches/tmp | medium | `fhir_bundle_mapper.dart:82-115` is unchanged and was outside this spec's task list | defer |
| BH8, EC11 | Re-sent `file_data` piles up suffixed duplicates | low | A suffix appears only on a name collision. After the URL is repointed, `resolveFile` finds the file, so it isn't requested again | reject |
| BH9 | Hello is a static, replayable token | low | Replay protection is transport crypto, which the frozen intent excludes | reject (intent) |
| BH10, EC3 | Unverified pending socket raises the accept prompt | low | The accept dialog lives on the unreachable `DesktopPage` (backlog section 9), so no prompt shows | reject |
| EC4 | `acceptPending` after the pending socket closed drops the active client | low | `next == null` still destroys `old`; the fix is a one-line guard | patch |
| BH11 | Quadratic buffer copy up to the 1 GiB cap | low | The buffering predates the change; the change only added the caps | reject |
| BH12 | Release silencing misses `logger` and isolates | false | `AppLogger` uses the default `DevelopmentFilter` (silent in release); the server isolate code calls no `debugPrint` | reject |
| BH13 | Reset leaves documents, `provider_downloads`, backups | medium | `_performReset` never deleted them; this predates the change | defer |
| EC15 | Reset now keeps `pdf_page_*` / `resized_*` (scan images) | medium | The old reset wiped all of temp; the sweeper skips these patterns, and reset also wipes `processing_sessions` | patch |
| BH14 | Sweeper never deletes the OCR cache | low | The frozen Never list excludes it | reject (intent) |
| BH15, EC12 | Deep-link download: any URL, no size cap, overwrites the same name | medium | The overwrite and the URL handling predate the change; only the name was in scope | defer |
| BH16, EC9, VG-other | The lock can't be turned off once the passcode is removed | medium | `authenticate()` returns false on a device that isn't secure (`biometric_auth_service.dart:39-50`), so the toggle stays on | patch |
| BH16 (feedback) | Cancelling the disable shows no message | low | Cosmetic; the switch staying on is the feedback | reject |
| EC8 | A Preferences prompt longer than 30 s triggers a second lock prompt | low | Only the Android credential screen is affected; fixing it needs cross-bloc coupling | reject |
| BH17 | `'hasSeenOnboarding'` literal duplicated in the bloc | low | If one copy is renamed, the lock stops applying without any error; there is no constant in `SharedPrefsConstants` | patch |
| BH17 (layering) | Bloc reads prefs; widget builds `AppDataResetService` | low | `getIt` is allowed in presentation; no named harm beyond the key, which the row above fixes | reject |
| BH18 | Log buffers duplicate each other | low | The two classes were already near-identical before this change | reject |
| BH19 | Overlay uses `Image.asset` and a numeric `BoxConstraints` | low | Matches `splash_page.dart:47` exactly, by design (no flicker) | reject |
| BH20 | TCP timing fields are mutable on the singleton | low | `@visibleForTesting`; nothing else assigns them | reject |
| BH21 | Generated l10n missing from the diff; no `@` metadata | false | The coordinator left the generated files out of the diff on purpose (they are regenerated in the tree). Only 118 of 1251 keys have `@` metadata | reject |
| VG2 | `BlockSemantics` is untested | medium | Removing it leaves every test green, and screen readers could then reach the records | patch |
| VG3 | Release-mode gating can't be observed by tests | medium | `kReleaseMode` is false under `flutter test`; nothing tests the release value of each decision | patch |
| VG4 | Sweeper patterns are literals duplicated with the producers | low | A producer rename would silently stop the sweep | patch |
| VG5 | Processing page icon gating is untested | low | A disabled buffer holds no data; a page test needs heavy DI | reject |
| VG-other | Windows demo PDF is outside the PathResolver docs root | low | Only demo data is affected (`records_repository_impl.dart:364`); real attachments use PathResolver | reject |
| EC7 | A native sheet (share/pass) stays above the lock on resume | medium | A native modal presents above the Flutter view; there was no re-lock before this change | defer |
| EC13 | Concurrent `PeerSelected` can delete a payload mid-send | low | `on<PeerSelected>` has no transformer (`share_records_bloc.dart:87`); the fix is `sequential()` | patch |
| EC14 | Unawaited startup sweep races a session started at launch | low | Sessions use fresh UUIDs created after the listing; awaiting would delay start on a large `%TEMP%` | reject |
| EC16 | Removed temp/container fallbacks in `resolveFile` | false | Removing them is what the spec asks for | reject |
| EC17 | Desktop MPC path has no hello gate | false | Every MPC frame is AES-GCM-decrypted with the pairing key (`tcp_service.dart:144`), so a peer without the key gets nothing through | reject |
| EC18 | `resolveFile` returns the unresolved symlink path | low | The check resolves links but returns `File(candidate)`; the fix is to return the resolved file | patch |
