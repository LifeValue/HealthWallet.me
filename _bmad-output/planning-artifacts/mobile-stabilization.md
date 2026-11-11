# Mobile stabilization backlog

The problems found while reading the code (October 2026), sorted for the next period: **stabilize the mobile app (iOS, Android) first; the desktop app stays as it is and is aligned later.** Each item is meant to become one HM ticket and one branch.

Items marked _(likely)_ were inferred from the code and need to be confirmed on a device first.

## Rules for this period

1. **A fix starts with a test that fails.** Write the test that shows the bug, then fix it. A bug fixed without a test can come back unnoticed.
2. **A skipped `BUG:` test is a ticket.** The suite has 24 skipped tests, each describing a known bug (section 6). Fixing the bug means removing the `skip:` so the test runs and passes.
3. **Code you touch leaves with tests.** A BLoC, repository or service you change gets tests for the behaviour you changed, even if it had none before.
4. **Don't break the desktop contract.** The desktop isn't being worked on, but phones already pair with it. A mobile change to `fhir_resource`, `sources` or `record_notes`, or to the messages sent to the desktop, must keep working on the desktop side. The LWW sync, wire protocol and handover tests protect this; keep them green.
5. **No silent failures in new code.** Never write an empty `catch`; log the error and show the user what happened.

## Status on `develop` (2026-11-03)

Checked in the code on `develop` at `b079f4f5`, after `feature/mobile-stabilization`, `bugfix/record-values-errors-and-deletes` and `feature/records-stabilization` were merged. "Holders" is `feature/holders-and-sources` (17 commits, not merged yet). Nothing was run on a device.

**Fixed on `develop`:**

- Notes on phone and desktop no longer share ids (`uuid` since schema v12).
- Doses keep their decimals (0.5 mg stays 0.5). `extractDosage`, which rounds, is only called from tests.
- `<` and `>` are kept on record values, components and ranges.
- US weight ranges convert both bounds.
- The calendar week starts on Monday in de, es and ro (from the app language). English with the Europe region still starts on Sunday.
- Every empty `catch` outside `desktop/` and `share_records/` has a comment.

**Fixed on holders only (not repeated elsewhere):**

- D3, the duplicate patient after the first Fasten sync.
- The empty `Patient/` link on scanned documents.
- Source renames not saved, and Fasten overwriting source names and deletes.
- `canEditSource`, `PatientDataUpdatedFromSync`.
- Home scope and Patient BLoC tests.

**Left out for now:** the Fasten items (D1, D2, and every Fasten sync bringing back records the user deleted), because fetching from Fasten can't be checked at the moment. Also the Home counts (B3), because holders rewrites that code.

**Still open, in two batches.** Each item is one spec on `feature/mobile-stabilization-remaining`. Nothing that `feature/holders-and-sources` changes is planned here.

Batch 1, in this order (specs in `_bmad-output/implementation-artifacts/`). **Done 2026-11-03** on `feature/mobile-stabilization-remaining`, all four specs reviewed and committed. Coverage of the 55 touched `lib/` files went from 57.0% to 95.2% (the whole app from 45.8% to 54.0%; 3,192 tests). The coverage pass pinned five bugs as skipped `BUG:` tests, listed in `deferred-work.md`. Device checks are still to do; each spec lists its own.

1. **Profile and patient dialogs** (`spec-profile-and-patient-dialogs.md`).
   - Every profile change waits 1 s (B8).
   - A failed name save still shows the new name (pinned by a skipped test in `user_bloc_test.dart`).
   - Profile errors show raw exception text and name the wrong setting.
   - The Preferences snackbar renders under the modal's blur.
   - Both patient dialogs reset the gender when the theme or language changes (`didChangeDependencies`).
2. **Scan and AI settings (B5)** (`spec-scan-and-ai-settings.md`).
   - The default token limit is 500 in Preferences and 4,096 in Processing; saving Preferences caps every later scan at 500. The Processing screen saves every value, so its first Save restarts mapping.
   - Deep Scan isn't sent to the running `ProcessingBloc`, and its default differs between the dialog and the bloc.
   - PDF pages reach OCR and AI at 72 dpi.
   - Cancelling a model download only stops listening, so the file still lands; the "cancelled" notification uses the wrong id.
   - Out of memory shows "too large for the current AI context size" (pinned by a skipped test in `processing_failures_test.dart`).
3. **Complete backups** (`spec-complete-backups.md`, desktop).
   - Backups hold only the database.
   - A restore keeps old stamps, so a paired phone partly undoes it, and the dialog says the phone isn't affected.
   - Nothing lets a wrong restore be undone.
   - This must ship before item 4 deletes any file.
   - For the holders merge: `sources.holder_id` (v14) is filled only at start-up (`linkUnassigned`), so after a restore of a pre-holders backup, the linker must run again.
4. **Attachment ids and files** (`spec-attachment-ids-and-files.md`).
   - Scanned and encounter documents get millisecond ids, so two saved in the same millisecond overwrite each other (pinned by a skipped test in `document_reference_service_test.dart`). Stored file names collide or get reused.
   - Files of deleted records stay for ever, while record and attachment deletes remove the file immediately, so an undo can't bring it back. From now on files follow their record: kept 30 days, deleted at the purge. A start-up sweep removes files nothing refers to.
   - Source deletes are left to the same purge and sweep, because holders rewrites that code.

Batch 2:

5. **Records filters and paging (B4).**
   - Choosing a specialty clears the type filter.
   - Specialty is filtered after paging, so pages come up empty and load-more duplicates rows.
   - Search ignores the type and date filters.
   - The Attachments view ignores the date filter.
   - A25–A28 in `records-audit.md`.
6. **Cleanup and logging.**
   - Section 5 dead code: `PdfStorageService` (two copies), `ClearDemoData`, `deleteResourceWithRelated`, the old model download methods, `CaptureMode.pdf`, the `add-document` intent filter, the `build.yaml` exclude.
   - `extractDosage`.
   - Model sizes written in two places.
   - The Spanish-only key `counterAppBarTitle`.
   - 18 empty `catch (_) {}` (11 in `desktop/`, 7 in `share_records/`); the backup ones (`backup_service.dart`, `backup_bloc.dart`, `backup_card.dart`) are fixed in item 3.
7. **Tests and CI (section 6).**
   - No BLoC tests for Home, Onboarding, Notifications, Focus Mode, Preview; Load Model and Attach to Encounter are only partly covered.
   - No widget tests for the review form, scanning and the Preferences toggles (the patient dialog and Preferences modal tests come with item 1).
   - No data tests for migrations 1→8.
   - `integration_test/` (including `app_l10n_test.dart`) isn't run in CI.
   - No coverage gate.
   - The translation tests don't catch dropped plurals or outdated translations.

**Also open, not in a batch:**

- Notifications: routes aren't stored, so taps do nothing after a restart, and handover notifications have no route (B6).
- Untitled records show the English "Resource", and other types fall back to the English type name.
- `<` and `>` are dropped, and 0.004 shows as "0.00", in the IPS PDF (`fhir_ips_export` package). They are also dropped in age onsets, encounter length, specimen quantities and the Home blood pressure.
- D7, one bad entry drops a received share.
- A source renamed after it was deleted on the other device comes back without its records. The fix is a sync rule on both ends.
- Google Wallet never reports a failed or cancelled save to the app, and the button shows without checking that Wallet is available. Whether adding again updates the pass needs a device.
- Release path (section 7): `master` is 505 commits behind and has no `.gitlab-ci.yml`; the Shorebird fallback is still silent; `fhir_ips_export` and `airdrop` aren't pinned to tags.

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
| D3  | **A duplicate patient after the first Fasten sync** _(likely)_. The default "Health Wallet Holder" is created before the sync with different identifiers, so the two never merge. _Confirmed; A1 in `holders-sources-audit.md`, which plans the fix with the rest of holder and source handling._                              | `default_patient_service.dart`                |
| D4  | **Notes from a received share are written to the real `record_notes` table** and deleted when the session ends. If the app is killed during the session, they stay. Because `record_notes` syncs, they can also reach the desktop. | `share_records/`                              |
| D5  | **Attaching two files with the same name overwrites the first,** because files are copied under their original name. _Done on `bugfix/record-values-errors-and-deletes`: each file is stored under a unique name and the title keeps the original._                                                                                           | `records/` attachments                        |
| D6  | **Wallet passes include resolved conditions and inactive allergies** (no status filter) and list only `MedicationStatement` medications. _Done on `bugfix/record-values-errors-and-deletes`: resolved, inactive, refuted and entered-in-error items are dropped, active `MedicationRequest`s are added and names are de-duplicated._                                                                         | `wallet_pass/`                                |
| D7  | **One bad entry in a received share throws away the whole share,** and a document whose encounter reference is a list is silently dropped (pinned by skipped tests).                                           | `share_records/data/mapper/`                  |
| D8  | **Lab values land on the wrong test.** Vision returns a table column by column and the OCR text keeps that order, so names and numbers are separated and the small model guesses the pairing. A synthetic 4-page lab PDF on the simulator gave 6 right pairs out of 24 ("Hemoglobin 137.9" was the sodium value, "ALT 10^3/uL" a unit). It also stopped after 251 tokens, so the last two pages gave no values. Check on an iPhone; rebuilding rows from Vision's bounding boxes is the likely fix. |
| D9  | **A saved PDF's attachment is rebuilt from the 72 dpi previews** (77 ppi images), so its small print can't be read, while OCR used 200 dpi. Seen on a session whose pages were edited. |
| D10 | **Patient files stay on the device after processing.** Saving leaves the original PDF in `imports/`: `discardOcrPages` deletes the page map, and the later cleanup finds originals through that map _(likely)_. Deleting a session leaves its `healthwallet_resized_*` copies in Caches, which only Reset removes. |
| D11 | **The AI fills report fields that aren't in the document.** On the simulator step 1 proposed issued date 2023-01-01, "Sample Lab" and a practitioner "Analyser A87"; on an iPhone 13 Pro Max it proposed issued date 2027-05-27, in the future. All marked low or medium confidence, none in the test PDF. | `ai_extraction_repository.dart` (step 1 prompt) |

## 3. Behaviour and silent failures

| #   | Problem                                                                                                                                                                                                                                                                                         | Where                                                         |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| B1  | **IPS export and wallet pass fail without telling the user.** IPS export has `catch (_) {}`; nothing listens to the wallet pass BLoC, whose "added" state is emitted whatever the result. _Partly done on `feature/mobile-stabilization`: the IPS export error is now logged but still not shown; the Google pass "added" state is pinned by a skipped `BUG:` test in `wallet_pass_bloc_test.dart`. Done on `bugfix/record-values-errors-and-deletes`: both show a translated message (Google Wallet only reports a failure to open), as do sync, scan and import errors, without exception text._ | `records_bloc.dart` (IPS export), `wallet_pass_bloc.dart`              |
| B2  | **115 empty `catch (_) {}` blocks in 47 files** (80 outside the desktop feature). Each one hides a failure. Go through them by feature: log with `logger`, show an error where the user is waiting, or comment why ignoring it is safe. _Done outside `desktop/` and `share_records/` on `bugfix/record-values-errors-and-deletes`._                                                         | whole `lib/`                                                  |
| B3  | **Home counts and vitals are capped at 20 records per category** (`getResources` defaults to `limit = 20`). "Recent Records" shows the newest records of the first non-empty category, not the newest overall. Categories overlap, so some records are counted twice.                           | `home/`, `records_repository.dart`                            |
| B4  | **Records filters:** choosing a specialty clears the type filter; specialty and date filters run after paging, so a page can be empty while more matches exist; search ignores the active filters; the Attachments view ignores the date filter; the page reloads on every Home state change. _The reload is fixed on `feature/records-stabilization`; the rest is step 5 of `records-audit.md`._ | `records/presentation/`                                       |
| B5  | **AI models and scanning:** cancelling a model download may not stop the transfer _(likely)_; turning Deep Scan on or off applies only after a restart; the default token limit differs between screens (4,096 in Processing, 500 in Preferences); PDF pages are rendered at 72 dpi for OCR and AI, which hurts accuracy on small text. | `processing/`, `capture/`                                     |
| B6  | **Notifications:** the route isn't saved, so old notifications lead nowhere after a restart. Handover banners have an empty route _(likely broken when tapped)_.                                                                                                                                | `notifications/`                                              |
| B7  | **About 40 hardcoded English strings** (among them "Show All", "Patient:", "Attachments / Records" and the notification texts). `untranslated_messages.json` lists 11 German and 7 Spanish and Romanian keys. _Done on `feature/mobile-stabilization`, including the desktop screens: see `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`._                                                                                  | `lib/core/l10n/arb/`                                          |
| B8  | **Every profile update waits one extra second:** `MockUserRemoteDataSource` adds a 1-second delay to theme, name and Share Proximity changes.                                                                                                                                                  | `user_remote_data_source.dart`                                |
| B9  | **A document with no patient name fails when the vision projector is missing.** The text pass finds nothing, the vision fallback logs `mmproj file not found, vision disabled`, sends images anyway and ends in `LlamaException` and "Processing failed". _Done on `bugfix/ai-stop-and-no-projector`: without the projector file, or when it doesn't load, no images are sent and the text pass's result (or no patient) stands; phase 2 reads the pages as text. The review opens with empty patient fields, not matched to anyone, and the note "No patient found in the document. Enter the details."_ | `ai_extraction_repository.dart`, `processing_handler.dart`, `resources_form.dart` |
| B10 | **Continue after cancelling step 2 can fail.** The cancelled generation was still running, so the retry ended with `llama.cpp generation is already in progress` and "Processing failed". Seen once, on the simulator. _Done on `bugfix/ai-stop-and-no-projector`, for step 1 too: Cancel stops the native generation and waits for it before disposing the model; AI runs take turns and the engine is never reused while generating. Until the AI has stopped the screen says "Stopping…" and Continue Processing and Retry are disabled. A step that fails after its Cancel (the vision model failing to load) now leaves the session cancelled instead of queuing it again, and the vision fallback doesn't load the model after a Cancel._ | `processing_repository_impl.dart`, `ai_inference_handler.dart`, `processing_handler.dart` |
| B11 | **Attaching a document without processing shows no preview and no confirmation.** With no AI model, the import goes from the model screen straight to the encounter picker, then back to the app without a message. `DialogHelper`'s attachment success dialog is never shown. _Done on `feature/mobile-stabilization-remaining`: choosing to attach on the AI page opens the pages (turn, reorder, delete) with one Attach to Encounter action; after saving, the Successfully Saved dialog says which visit it went to, also when the import is reopened from the list and attached from its No AI model notice. A failed save shows its reason on the same screen. `AttachDocumentsService` has no caller left._ | `document_handler.dart`, `dialog_helper.dart` |
| B12 | **A document handed over from the phone loses its name** _(likely, from reading the code)_. The desktop stores each received file as `<index>_<name>` with every character other than letters, digits, `.`, `-` and `_` replaced, and passes that path on, so `Scrisoare medicală.pdf` would be titled "PDF: 0_Scrisoare_medical_". Found merging `develop` into `feature/mobile-stabilization-remaining`; imports keep their names. _Done on `feature/mobile-stabilization-remaining`: each page is saved as `<session>/<index>/<name>`, with the phone's copy suffix removed and only unsafe characters replaced (`safeFileName`), so processing adds one suffix and the title reads back as the original name._ | `handover_service.dart` (`_safe`) |
| B13 | **The desktop says "Not paired" after a restart while the phone is away.** The home Connection card shows Not paired until the phone connects, because the paired phone is loaded only on a connection; the pairing and sync state are still saved, and the restore dialog correctly says the phone isn't connected. _Kept as it is, as decided by the product owner on 2026-11-11: working as intended._ | `home_page.dart` (Connection card), `communication_bloc.dart` |
| B14 | **Deep Scan says there isn't enough memory on an iPhone 13 Pro Max (6 GB)** _(to check: intended or a wrong threshold)_. Seen on the review screen after step 1. _Done on `feature/mobile-stabilization-remaining`, as decided by the product owner: it was a wrong table (the core service mapped every iPhone14,x to 4 GB); one memory table now serves both services, 6 GB iPhones get Deep Scan with the Lite model, the Advanced model is offered on iPhones only from 8 GB, and where Deep Scan can't run step 2 stays available and reads the text only, with the notice kept. iPads now read their memory from a per-model table too, and an Advanced model chosen before on a device that can't run it is replaced by Lite at start-up, with a notification saying why._ | `device_capability_service.dart` |
| B15 | **A saved document whose file name has accents can't be opened or shared.** Since saved files keep their original name (`Scrisoare medicală_70f744fd.pdf`), the scan and import save writes the link unencoded, and four readers decode it with `Uri.decodeComponent`, which throws on any non-ASCII letter: the attachment has no view button and is left out of the viewer, one such document empties its visit's attachment list in the browser, and sharing the record fails. Found on the simulator importing `Scrisoare medicală.pdf`. _Done on `feature/mobile-stabilization-remaining`: one reader (`filePathOfUrl`) decodes encoded links and keeps unencoded ones as they are, as the sync and the cleanup already did._ | `record_attachments_bloc.dart`, `repository_attachment_browse_service.dart`, `pdf_preview_service.dart`, `fhir_bundle_mapper.dart` |
| B16 | **After the desktop app restarts, the phone keeps "Reconnecting…" until its own app is reopened** _(to check with a real quit and relaunch; seen after a hot restart of the debug desktop app)_. The phone showed "Reconnecting to Tudors MacBook Pro… Connecting…" for more than 4 minutes, and Sync Now was disabled, while the desktop was advertising again on mDNS and SSDP; relaunching the phone app connected at once. Seen on an iPhone 13 Pro Max on 2026-11-11. _Done on `feature/mobile-stabilization-remaining`: the phone tries every Bonjour answer carrying the desktop's token, not only the first (a stale one could hide the live one), and gives up a connection attempt after 60 s so a hung step can't keep it connecting forever; the product owner kept the give-up after 5 tries._ | phone discovery / reconnect (`desktop/communication`) |
| B17 | **A cancelled step 2 comes back after the app restarts.** Cancel puts the session back to step 1 and drops step 2's results only in memory (`onMappingCancelled` calls `updateSession` without `updateDb`), while each step 2 result was already written to the session. After a restart the session loads at step 1 with the cancelled results, and Done would save them. Seen on the simulator on 2026-11-11 (5 results back after a cancel). _Done on `feature/mobile-stabilization-remaining`: the cancel saves the session back at step 1 with no results._ | `processing_handler.dart` (`onMappingCancelled`) |
| B18 | **Switching patient in Preferences takes about 3 seconds.** Tapping another patient plays a fixed sequence (close the open card, move the new patient to the top, open its card) with waits of 560 + 840 + 140 + 560 + 840 + 140 ms, on top of 600–900 ms card and list animations. The Home screen switch takes 200 ms. Raised by the product owner on 2026-11-11: it should be faster. _Done on `feature/mobile-stabilization-remaining`: the switch runs about 4 times faster._ | `patient_bloc.dart` (patient selection), `unified_patient_card.dart`, `animated_reorderable_list.dart` |
| B19 | **A review the other device took back turns into a bare "Session not found!" page.** When the phone deletes a document it handed over, the desktop's open review switches to an empty page with only that line: it doesn't say the phone took the document back, and it doesn't return to the Import list. Nothing is saved, so it is safe. Seen on 2026-11-11 during check 5.2. _Done on `feature/mobile-stabilization-remaining`: the desktop leaves the review and says the phone took the document back (`handoverTakenBack`). A handover being read when it is taken back or saved elsewhere is now stopped first, stages nothing, and its page files are deleted._ | `processing_page.dart` (missing session) |
| B20 | **Records added filters the user never chose.** With no record type chosen, Records added Encounter + Diagnostic Report by itself, also on top of a specialty the user picked, so a person without visits or reports saw an empty list with chips they never set. Found on the desktop during check 5b.4 on 2026-11-11. _Done on `feature/mobile-stabilization-remaining`, as decided by the product owner: Records adds no filters; the filters a person chooses are kept for that person on the device, also after a restart, until cleared; each person has their own; a share shows none. A Home card filters its whole visit, reloads and syncs included, and a person no longer in the wallet loses their saved filters._ | `records_bloc.dart`, `records_filter_store.dart` |
| B21 | **Closing the "Successfully Saved" dialog with ✕ (or a tap outside) keeps the saved session.** Only Go to Records and Continue Importing/Scanning clear it, so the screen stays on the document with its Attach/Done button active and the session stays in the Scan/Import list as Pending; saving it again would likely store the document twice. Seen on the iPhone on 2026-11-11 after attaching a scan without the AI (check 5c.6). _Done on `feature/mobile-stabilization-remaining`, as decided by the product owner: the message has no ✕, and closing it any other way works like Continue (the session is cleared)._ | `processing_page.dart` (saved dialog, `barrierDismissible: true` with no clear on dismiss) |
| B22 | **After downloading the model from the AI page, the document was not read.** The AI page leaves with "model ready" by popping the top route, but the model list it opened was still on top when the download ended, so the list closed and the AI page stayed, its one "ready" signal spent. Seen on the iPhone on 2026-11-11 (check 5c.6). _Done on `feature/mobile-stabilization-remaining`: the page closes any window over it first, then leaves to read the document._ | `load_model_page.dart` |
| B23 | **A document the app was killed in during step 2 comes back at step 1 with step 2's partial results.** Each step 2 result is written to the session as it comes; on the next start the session loads at step 1 still holding them, so Done would save them, and Continue Processing (or the desktop carrying on a handover by itself) would add the new results to them, so the phone's draft could hold records twice. Found reviewing the B17 fix on 2026-11-11. _Done on `feature/mobile-stabilization-remaining`, as decided by the product owner: as after a Cancel, a session found in step 2 at start-up goes back to step 1 with no step 2 results, keeping its patient, visit and report, and is saved so; one found in step 1 still waits to start again._ | `processing_bloc.dart` (`onProcessingInitialised`) |

## 4. Record display bugs pinned by skipped tests

These change what the user reads on a record, so they belong to stabilization. _All but the two share mapper bugs ("Observation" title, shallow copy) are done, on `bugfix/record-values-errors-and-deletes` and `feature/records-stabilization` (see `records-audit.md`); the `_history` fix went into `fhir_reference_utils.dart` and the records repository, while the share mapper copy and its skipped test stay with the share feature._ Each one is a skipped test in `test/features/records/domain/utils/extractors/` or `test/features/share_records/data/mapper/`:

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
- ~~**The LWW offline queue is cleared on every mobile start,** so changes made while disconnected are lost if the app restarts before the next sync.~~ _(gone on `feature/records-stabilization`: unsent changes wait in the `sync_outbox` table and survive a restart; see `sync-audit.md`)_
- ~~**Restore is not wrapped in a transaction**~~ _(fixed on `feature/mobile-stabilization`: one transaction, only the app's own tables)_, and **backups don't include attachment files.**
- ~~**Handover:** a result clears every pending session on the phone, not only the one sent; the desktop tracks one handover at a time; skipped tests pin file ordering, duplicate files and file-name clashes.~~ _(reworked on `feature/handover-stabilization`; see `handover-audit.md`)_
- **TCP server:** a skipped test pins `stopServer` killing the isolate too early. _The replaced client socket and the receive buffer never reset in server mode are fixed on `feature/mobile-stabilization`._
- **Desktop UI:** the empty-state Import and Scan buttons jump to the wrong tabs _(likely)_; the record details side panel can't collapse; ~~a second phone gets no accept/reject dialog because it lives on the unreachable `DesktopPage`~~ _(the dialog shows on any page, `feature/records-stabilization`)_; hardcoded strings in the From Phone tab and the tray menu _(translated on `feature/mobile-stabilization`)_.
- **Dead code:** `DesktopPage` and its cards, the unused tab child routes including `SyncRoute`, and the `backup_start`, `backup_chunk` and `backup_complete` messages nothing listens for.
- **Windows:** no runner is registered for `windows:release`, and the Microsoft Store submission is not documented.
