---
title: 'Correct record values, surface silent errors, and keep deletes deleted'
type: 'bugfix'
created: '2026-10-28'
status: 'done'
baseline_commit: 'f41a7bdbef11e5d3e2b676d06c927a7d48601330'
route: 'dispatch'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/mobile-stabilization.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Records show wrong values (section 4 of the stabilization backlog). IPS export, Google Wallet, sync, scan and import fail without a readable message, and 75 empty catches hide failures. Attachments with the same name overwrite each other, and wallet passes list resolved conditions, inactive allergies and only MedicationStatement. A record deleted on the phone or the desktop comes back from the other device.

**Approach:** Fix the section 4 extractor bugs by un-skipping their `BUG:` tests. Turn every silent failure into a log plus a translated message where the user is waiting. Store attachments under unique names and filter wallet-pass items by status. Make deletes of synced rows soft (`deleted_at` tombstones that already travel over LWW) and hide tombstoned rows from every read. All of this ships on one branch, `bugfix/record-values-errors-and-deletes`, cut from `develop`, with delete sync done last.

## Boundaries & Constraints

**Always:**
- Follow the rules for this period (backlog top): failing test first, un-skip each fixed `BUG:` test, no silent failures, keep the LWW, wire protocol and handover tests green.
- Every touched file gets tests for its changed **and existing** behaviour. Report per-file coverage before and after (baseline: 1,707 pass / 23 skipped / 30.0%, lcov in the session scratchpad). A bug found in existing behaviour is pinned as a skipped `BUG:` test, not silently fixed.
- New strings go into all four ARB files plus `gen-l10n`. Use `logger`, `context.l10n` and the UI kit.
- The QR payload shape stays unchanged.

**Never:**
- Anything in `lib/features/share_records/`: the colleague owns it, and its 4 skipped mapper tests stay.
- Fasten-side work: D1, full downloads, timeouts, Cancel, the duplicate patient.
- Sync networking behaviour: only the sync error messages change.
- Schema version bumps or new wire messages.
- Rewriting the 10 empty catches that already carry a reason comment.
- Turning Reset or backup restore into soft deletes; they stay local hard wipes.

**Decisions:**
- **Quantities:** keep at least 2 decimals, at most the decimals of the source value (cap 6). So 120 shows as `120.00`, 0.004 as `0.004`, 1.2345 as `1.2345`.
- **Missing parts:** a missing unit falls back to `code`, otherwise it is omitted. A missing value or bound is omitted, and when nothing is left the result is null.
- **Partial dates:** shown as recorded (`From 2024-03`).
- **`_history` bug:** fixed in `fhir_reference_utils.dart` and `records_repository_impl.dart:589` with new tests; the share mapper copy is left alone.
- **Wallet pass:**
  - Conditions and allergies are dropped when `clinicalStatus` is inactive, resolved or remission, or when `verificationStatus` is refuted or entered-in-error. A missing status keeps the item.
  - MedicationStatement is kept when its status is active, intended, on-hold, unknown or missing. MedicationRequest is kept when it is active, on-hold, unknown or missing.
  - Names are de-duplicated, case-insensitively.
- **Google Wallet:** the plugin cannot report a cancel or a save error, so a launch error becomes `failure` with a translated message. No "added" claim is shown; the native wallet UI is the success signal.
- **Sync errors:** classified by exception type (`DioException.type`, status code, `FormatException`) rather than by text, and shown on the sync screen. The generic message carries no exception text.
- **Scan and import errors:** the UI shows text from typed `PipelineFailureReason`s. `Failure.error` keeps the English text for logs and the handover message.
- **Deleting a record or source** also tombstones the notes of the deleted records. Demo-data clear and DocumentReference replacement on re-processing tombstone too.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Delete on phone | Phone and desktop paired, record deleted on phone | Row gets `deleted_at` (ms) and a fresh ms `updated_at`; the desktop hides it after the next delta; a full-table resend from the desktop does not bring it back | Tombstone wins LWW per row |
| Edit after delete | Desktop edits the same record later than the delete | The newer edit resurrects the row on both ends (existing LWW rule) | — |
| Re-add same id | Demo data loaded again after clearing | Save clears `deleted_at`; the rows show again | — |
| Same-name attach | Two `report.pdf` attached | Two files on disk; titles stay `report.pdf`; deleting one keeps the other | Copy failure is logged and shown |
| IPS export fails | Builder throws | Snackbar with a translated error; nothing shared | Logged |

</frozen-after-approval>

## Code Map

- `lib/features/records/domain/utils/extractors/fhir_observation_extractor.dart` -- :20/47/52/67/89/91 raw quantity, range, ratio and period interpolation; :283-295 blood type (use `value.coding`, `BloodTypes.fhirDisplayMapping` and `snomedCodes` in `lib/core/constants/blood_types.dart`).
- `.../extractors/fhir_common_extractor.dart` -- :25 first coding only; :78 `toStringAsFixed(2)`. 15+ entity callers of `extractQuantity` and about 125 of `extractCodeableConceptText`.
- `.../extractors/fhir_temporal_extractor.dart` -- :66-97 partial dates dropped (fall back to `extractPeriod`, including a mixed bound); :116 onset and :146 abatement open range (copy the :317-325 pattern).
- `lib/core/utils/fhir_reference_utils.dart:9` -- strip `/_history/<v>` before taking the id; test in `test/fhir_reference_utils_test.dart`.
- `test/features/records/domain/utils/extractors/` -- skipped tests: observation :125/140/327/788/808, temporal :112/192, common :96/239. Tests expecting 2 decimals must stay green: `fhir_field_extractor_test.dart`, `additional_info_l10n_test.dart`.
- `lib/features/records/presentation/bloc/records_bloc.dart:365-406` -- IPS export only logs. Add an export-error state; the sheet is opened from `home/presentation/widgets/share_options_sheet.dart:100-123`.
- `lib/features/wallet_pass/presentation/bloc/wallet_pass_bloc.dart:55-60,112-141` -- unawaited `savePassesJwt`, raw `e.toString()`. Nothing listens to the bloc (provided at `app.dart:150`); skipped test at `wallet_pass_bloc_test.dart:205-225`.
- `lib/features/wallet_pass/domain/service/emergency_card_builder.dart:64-95` -- item selection (no tests yet). MedicationRequest's `medicationX` is read via `FhirFieldExtractor.extractCodeableConceptText`.
- `lib/features/sync/presentation/bloc/sync_bloc.dart:70,155-185,255` -- substring classification and raw text; `SyncState.errorMessage` is never displayed. Test `sync_bloc_test.dart:85` expects raw text and must change.
- `lib/features/processing/presentation/bloc/handlers/session_handler.dart:93,149,238,324`, `processing_handler.dart:256,460,566`, `processing_bloc.dart:197`, `processing_state.dart:5` (`PipelineFailureReason`), `pages/processing/widgets/processing_mapping_section.dart:98` (`_sanitizeError`) -- raw text in the UI. The pattern to copy is `HandoverFailureL10n` in `lib/core/l10n/display_names.dart:176`.
- Empty catches outside desktop and share_records: 75 total, 65 to fix. Targets are the investigation table; user-waiting ones (log and show): `records_page.dart:297,318`, `import_page.dart:412,436`, `load_model_page.dart:394`, `attachment_detail_panel.dart:352`, `processing_path_helper.dart:71`. Probes, parsers and temp deletes get a reason comment; the rest get `logger`.
- `lib/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart:240-353,543` -- copies to `Documents/<basename>`; ms `_generateId` collides in loops. Keep the `file://` + percent-encoded relative URL and the original `title`; use the uuid8 + sanitize pattern of `LwwSyncService._freeFileName`.
- Delete paths to soft-delete:
  - `records_repository_impl.dart:170-218,492-497`
  - `fhir_resource_datasource.dart:108-128`
  - `sync_local_data_source.dart:274-284`
  - `record_attachments_bloc.dart:430-445`
  - `processing/domain/services/document_reference_service.dart:26-37`
- Reads to filter (`deleted_at IS NULL`):
  - `fhir_resource_datasource.dart` :18/42/57/66/116/131/160
  - `records_repository_impl.dart` :147/222/248/268/285
  - `sync_local_data_source.dart` :107/124/219
  - `document_reference_service.dart` :214/253
- `lib/features/desktop/lww_sync/data/services/lww_sync_service.dart:96-98,142` and `attachment_sync_service.dart:17,43` -- broken-attachment check and attachment embed/restore must skip tombstones.
- `lib/core/data/local/app_database.dart:232-264` -- triggers stamp `updated_at` in ms at second precision; `DateTimeColumn` maps to seconds in Drift.

## Tasks & Acceptance

**Execution:**
- [x] Section 4 extractors + `fhir_reference_utils.dart` + `records_repository_impl.dart:589` -- fix and un-skip the 9 tests; pin the unpinned siblings (ratio, period, abatement) with passing tests.
- [x] `records_bloc.dart`, `records_state.dart`, listener in the home/records UI -- IPS export failure state with a translated snackbar.
- [x] `wallet_pass_bloc.dart` + a `BlocListener` near `app.dart:150` -- await the Google save; failures carry a translated message; un-skip :205-225.
- [x] `sync_bloc.dart` + sync page -- typed classification, no raw text at :70/174/255, error shown; update `sync_bloc_test.dart`.
- [x] Processing files listed above + ARB -- typed reasons and translated UI text; `Failure.error` unchanged for handover.
- [x] Empty catches (65) -- log, show, or comment per the Code Map, one commit per feature.
- [x] `record_attachments_bloc.dart` -- unique stored names and ids; first `RecordAttachmentsBloc` tests (attach, view and delete paths).
- [x] `emergency_card_builder.dart` -- status filters, MedicationRequest, de-duplication; first builder tests.
- [x] Delete sync, last -- add the contract below to `architecture.md` (LWW section, replacing the "nothing sets deleted_at" note); soft-delete and filter as in the Code Map; save paths clear `deleted_at`; tombstone guards in the LWW services; tests for repository deletes, reads, resurrect-on-save, and a phone→desktop delete round trip through `LwwSyncService`.
- [x] `deferred-work.md` + `mobile-stabilization.md` -- mark done items; defer the note-id collision (pinned as a `BUG:` test) and orphaned files of tombstoned DocumentReferences.

**Acceptance Criteria:**
- Given any record with a missing unit, value or bound, when it is displayed, then no "null" appears.
- Given a failing IPS export, Google or Apple pass, sync, scan or import, when it fails, then the user sees a translated message without exception text, and the error is logged.
- Given `grep` for empty catch bodies in lib/ outside desktop and share_records, when it runs, then every hit has a reason comment.
- Given a mobile build with this change paired with a desktop build of it, when either side deletes a record, note or source, then it stays deleted on both after reconnect and after a full-table resend.
- Given `scripts/check.sh`, when it runs, then it passes, with 9 fewer skipped tests plus the wallet one.

## Implementation Notes

- **How the work ran:** five agents in parallel on one branch. The extractors and delete sync ran in the main checkout; the error messages, empty catches, and attachments plus wallet pass ran in worktrees and were cherry-picked. Every commit applied without conflicts, and gen-l10n and build_runner regenerated identical output.
- **Values:** the decimals of a region-converted value follow the recorded value (70 kg shows as `154.32 lbs`). `valueRange`/`valueRatio` stay unitless, as before. The raw `extractOnsetX`/`extractAbatementX` keep raw numbers, while the `…Formatted` variants use `extractQuantity`. If either bound of a period does not parse, both bounds are shown as recorded.
- **Blood type:** the order is value text, then a SNOMED code (SNOMED or system-less codings only), then a coding display, then the observation's code display.
- **Errors:** IPS export uses `RecordsState.ipsExportStatus` (each export passes through `exporting`). The wallet pass uses a translated `errorMessage`. Sync uses `SyncFailureReason.of` (a QR code that does not parse fails before any network call; `syncErrorGeneric` lost its placeholder). Scan and import use the extended `PipelineFailureReason` with `localizedMessage`. The IPS, wallet and capture listeners live in `MaterialApp.builder`, inside the app's `ScaffoldMessenger`; the sync listener wraps `SyncPage`. "Not enough memory" and "corrupted" are still matched on the AI engine's fixed English text.
- **Empty catches:** grep found 61 bare ones plus 13 comment-only ones, 74 rather than 75. All bare ones are now logged, shown (6) or commented (the 8 extractor ones included). The `patient_source_utils` and `sync_repository_impl` comments already state a reason and were kept.
- **Attachments:** the stored name is always the sanitized name plus an 8-character suffix (`report_1a2b3c4d.pdf`), and ids are UUIDs. A copy whose database save fails is deleted again. Attach and delete failures carry `attachFileFailed`/`attachmentDeleteFailed`, shown by `RecordAttachmentsWidget` and the attachment detail panel.
- **Wallet pass:** a status without a code is matched on its text. MedicationStatement takes its name from the title, then the medication; MedicationRequest from the medication, then the title. Statements come before requests when names are de-duplicated.
- **Delete sync:** the SQL lives in the `SoftDelete` extension (`lib/core/data/local/soft_delete.dart`). "Any save clears `deleted_at`" means upserts and replaces; single-column updates (raw JSON, specialty, note text, encounter link) leave it alone. The demo and wallet source rows now leave `updated_at` to the trigger (ms), so a re-created source beats its tombstone. Share sessions called `deleteRecordNote`, so their cleanup sent tombstones; since `develop` was merged on 2026-10-30, received notes are served from memory (`SharedNotesDatasource`) and never written, so shares leave no tombstones. `share_records` itself is untouched.
- **New `BUG:` pins (skipped):**
  - the note-id collision across devices;
  - `DocumentReferenceService` ids colliding within one millisecond;
  - attaching to a record without a subject, which writes `Patient/`;
  - the out-of-memory scan message, which tells the user to raise the context size.
- **Tests:** 2,133 pass and 17 are skipped (baseline 1,707 / 23; 10 un-skipped, 4 new pins). Total coverage went from 30.0% to 37.0%.
- **Touched files left at low coverage (at review time):** `records_page`, `attachment_detail_panel`, `record_detail_page`, `dashboard_page`, `image_preview_page`, `processing_page`, `sync_page`, `ai_settings_dialog`, `source_selector_widget` and `ai_inference_data_source`. Covered in the final validation (see the Spec Change Log); 5 changed lines remain unreachable from tests, in `deferred-work.md`.
- **Flaky test:** `ssdp_service_test` "stopAdvertising releases the socket" failed once during the parallel runs (port 1900 shared by the agents) and passed on every rerun.
- **After review pass 1:** 12 findings patched in 14 commits, including sync errors moved to the app shell (the sync page is never opened), open ranges shown as `≥`/`≤` (the `…Formatted` variants too), reference ranges with source decimals, and `droppable()` on the export and wallet handlers. Final: 2,154 pass and 18 skipped (one new `BUG:` pin for the region conversion of reference ranges); analyze clean; total coverage 37.1% (baseline 30.0%).

## Spec Change Log

- **2026-10-29, region units (after review, from manual testing).** Making the Records list, Home's recent records and related records use the region units like the details (574ea5f3) spread an older bug: in Europe and UK every lab value in mg/dL was converted with the glucose factor (cholesterol 200 mg/dL showed as 11.10 mmol/L, creatinine 1.0 mg/dL as 0.06 mmol/L). Decisions confirmed by the user:
  - Convert only when the observation's LOINC code says it is a weight, height, temperature or glucose (`regionUnitVital`), and only from one of that measurement's units, recognised by the UCUM `code` first and the written `unit` second. Every other value shows as recorded.
  - A record from a scanned or imported document (a `wallet-` source) shows exactly what the document says, in every region. No migration is needed: existing scans are already in `wallet-` sources.
  - Each reference-range bound is converted from its own unit, which fixes the pinned `BUG:` test for 50–100 kg in the US.
  - Unchanged: the Home vitals card (it converts per vital type, so the glucose factor never reached cholesterol there) and the share feature.
  - Tests: 2,215 pass and 17 are skipped; analyze clean.
- **2026-10-29, found while testing on the phone and the desktop.**
  - **Launch logo after an update** (8fb3f3c4): iOS kept showing the old logo after an update because it caches the launch screen by asset name. The launch image is now named after its content (`LaunchImage-<hash>`), and `tool/generate_brand_assets.sh` renames it whenever the logo changes.
  - **VPN notice** (54282008, 22be2204, 41d060b9, 077ae065): a full-tunnel VPN on the computer lets the phone connect and then drops it. The desktop now says so in the connection dialog and in Preferences → Sync. It rechecks every 5 s while the app runs, when a phone drops and when Preferences open. The reconnect logic is unchanged.
  - **Document sizes** (6ce83903): shown in KB, MB or GB (`FileSizeFormatter`, 1024-based, one decimal) instead of bytes; the `sizeBytes` string was removed.
  - **App messages** (84908ad9, 519aedab, 4078aae3): the user asked for messages styled like the app instead of the default snackbar. This reverses triage finding 22, which had rejected a shared helper. Every message outside `share_records` now goes through `AppSnackBar`: a card tinted with the status colour, with an icon and a ✕, floating above the bottom navigation (480 px wide on a wide desktop). The card itself is `AppMessageCard`, also used inline in the desktop Backup dialog.
  - **Attachment names** (ff895462): the list showed the stored name (`report_1a2b3c4d.pdf`) since the unique names were added. It now shows the title the user picked, falling back to the file name.
  - **Local times** (085666bc): times stay stored as recorded (UTC in the FHIR data) and are shown in the phone's time zone (`FhirTemporalExtractor` converts with `toLocal()` before formatting). Tests compute their expected text from the same instant in local time, so they pass in any time zone.
  - **Unreadable PDF** (d2eec3ad): the iOS PDF view drew a blank page for a file it could not read and reported nothing. `CheckedPdfView` opens the file with pdfx first and shows "Failed to load PDF" when it has no pages; used by every full-screen PDF viewer.
- **2026-10-30, found while testing on the phone and the desktop.**
  - **Delete dialog** (b6bfa17c): the dialog for a record with related resources had no ✕, put Delete above the choice it depends on, and showed a second Delete button only after something was ticked. It is now `DeleteRecordDialog`: a "Delete <record>" header with ✕, a line saying related resources are kept unless ticked, the related resources as a checklist with Select all / Deselect all, and Cancel and Delete at the bottom. Delete reads "Delete + N related" when items are ticked. The user chose to keep the "Are you sure?" confirmation after it. New strings: `relatedResourcesKeptHint`, `relatedResourcesCount`, and `deselectAll`, because the German and Romanian "Clear all" read as "delete all".
  - **Backup dialog in long languages** (5ddb582a): the three backup buttons had fixed widths and cut off longer translations ("Creează copie de siguranță"). They now have a minimum width and grow with the label, and the "Sync with phone first (not connected)" line wraps.
  - **Restore failed when notes had a source** (003b9a9b; the bug was already on `develop`): restore replaces the tables one by one, so midway a note pointed at a source that was already gone, and SQLite refused it. Foreign keys are now checked once, at commit (`PRAGMA defer_foreign_keys`). A backup with broken references still fails as a whole and changes nothing. The service tests had missed it because their in-memory database had foreign keys off, unlike the app.
  - **Backup messages** (68fe0f7a, c399233a, a781916a): errors showed as plain red text, a finished backup said nothing, and the "Backup restored" dialog was missed when a restore started and finished between two frames. The card now listens to the bloc's states (a BlocListener sees every state, a rebuild only the last). An error shows as a red `AppMessageCard` and a finished backup as a green one ("\"<name>\" has been saved. It holds N records."). Both hide after 6 s or with ✕, and the next backup or restore clears them. "← All backups" moved to the top of the dialog.
  - **Tests added for checks that cannot be run by hand** (47cda212, d67efe19): two attachments with the same title reach the other device as two files; after the 30-day purge nothing reappears, whichever device purges first.
- **2026-10-30, final validation (an independent review of the branch against this spec and the user's requests, plus line coverage of every change).**
  - **30-day purge failed after deleting a source with notes** (f9c24593; new on this branch, since nothing was purged before): the purge deleted `sources` before `record_notes`, and a note's `source_id` references its source. With the foreign keys the app turns on, the purge threw on every start and left those tombstones forever. It now purges notes first, then records, and keeps a deleted source while a newer note still points at it. The LWW test database now turns foreign keys on like the app, which also exposed a repository test saving a note for a source it never created.
  - **One day in local time** (df73fb04): a period was collapsed to one date by comparing its UTC dates; it now compares the dates as the user sees them (23:30Z–00:30Z is one day in Romania).
  - **Viewer titles and exception text** (1c6f4f02):
    - The viewer opened from a record page or the attachment panel titled itself with the stored file name; it now shows the attachment's title, then the record's.
    - The PDF and file viewers showed exception text ("Error loading PDF: …", "Error on page …", "Error opening file: …", and the source label error). They now log it and show `failedToLoadPdf`, the new `fileOpenFailed` or `errorUpdatingSourceLabel`. Six strings that existed only to carry exception text were removed, as was the unused `PdfPreviewService.previewPdfFromFile`.
    - The three PDF viewers now pick desktop or mobile with `AppPlatform`, as AGENTS.md asks, instead of `dart:io` `Platform`, so tests can reach the mobile branch.
    - `CheckedPdfView` gained two test seams, `defaultCanOpen` and the `open` parameter of `canOpenPdf`: pdfx refuses to open files on Linux, where CI runs.
  - **pdfx on Linux** (70534e7b, 0088c77c, 25a6d75b): the suite was also run on Linux in Docker, as CI runs it (`buildpack-deps:bookworm`, Flutter 3.47.7, empty `.env`), and six tests that passed on macOS failed there.
    - pdfx checks its platform support without awaiting the check, so on Linux the failure escaped as an uncaught error. Every PDF now opens through `openPdfDocument`, which awaits the check first and fails in a way callers handle.
    - The attachment panel tests counted pdfx channel calls, which differ by host; they now check what the user sees.
    - The viewer tests waited a fixed 100 ms for real file I/O; they now poll until the work is done.
    - The same pass replaced the media viewer's "Failed to link media: <exception>" with the translated `linkMediaFailed`, and dropped the viewer title's file-name fallback, which no record can reach.
  - **Merged `origin/develop`** (8bb2cca9, 15 commits: end-to-end share encryption, notes from a share kept in memory, proximity sharing hidden on the desktop). No conflicts. The generated translations regenerate unchanged. The repository tests now pass the new `SharedNotesDatasource` (c9366b6a). After the merge, all CI jobs, the Linux run and the builds were repeated.
  - **Static helpers** (c423dd43): `AppSnackBar` and `FileSizeFormatter` are `abstract final`, so they need no private constructor that no test can reach.
  - **Tests for the screens left at low coverage:** record page (delete flow through `DeleteRecordDialog` and the confirmation), records page, attachment panel, attachment and media viewers, PDF preview, source label dialog, record cards in the region units, the desktop backup and connection dialogs, and the remaining logged error paths.

## Review Triage Log

Review pass 1: three layers (blind, edge case, verification gap). 28 findings: 12 patched, 4 deferred, 11 rejected; one was split, with its docs part patched and its code part rejected.

| # | Finding | Verdict | Evidence | Route |
|---|---------|---------|----------|-------|
| 1 | Sync errors are never shown: `SyncErrorListener` wraps only `SyncPage` (verification gap, edge case, blind) | high | Nothing pushes `SyncRoute`; Fasten sync starts from `ConnectionDialog` (`connection_dialog.dart:72,496`) and demo data from `SyncPlaceholderWidget`. A repeated demo-data failure never re-fires because `errorMessage` is not cleared. | patch |
| 2 | The app-level IPS, wallet and capture listeners can be removed without any test failing (verification gap) | medium | `widget_test.dart` pumps `App` but never emits a failure; each listener test mounts its own `MaterialApp`. | patch |
| 3 | Reference ranges still use `toStringAsFixed(2)` while the value keeps its decimals (verification gap) | medium | `observation.dart:184-185,511-515`; 0.004 against `< 0.01` reads as out of range. | patch |
| 4 | An open value range or ratio shows a bare number (blind, edge case) | medium | `fhir_observation_extractor.dart:52-66` (`joinNullable`) and `fhir_temporal_extractor.dart:45-50` drop the direction: high-only 5 shows `5.00`. | patch |
| 5 | Age onset/abatement and `doseQuantity` print `null` (edge case) | medium | `fhir_temporal_extractor.dart:124,150` and `fhir_common_extractor.dart:200` interpolate `.value` unguarded; breaks the "no null" acceptance criterion. | patch |
| 6 | `RecordsSharePressed` and `WalletPassRequested` have no `transformer:` although they now await (blind, edge case) | medium | `records_bloc.dart:47`, `wallet_pass_bloc.dart:29`. A double tap runs two exports, and the second deletes the PDF the first is sharing. | patch |
| 7 | The backup record count includes tombstones (blind, edge case) | low | `backup_service.dart:224` has no `deleted_at IS NULL`; contract point 3. | patch |
| 8 | `clearDemoData` tombstones in two transactions (blind) | low | `records_repository_impl.dart:499-504` calls `deleteResourcesBySourceId`, then `deleteSource`, which does both in one transaction; a failure between them leaves a live empty source. | patch |
| 9 | After a multi-file attach fails partway, the saved files are missing from the list (edge case) | medium | `record_attachments_bloc.dart` emits an error without reloading; a retry duplicates the files saved earlier. | patch |
| 10 | The attachment panel caches pages when some PDFs failed, so reopening hides the failure (edge case) | low | `attachment_detail_panel.dart:371-373` caches whenever `pages.isNotEmpty`; the new snackbar then shows only the first time. | patch |
| 11 | The `fallback` parameter of `PipelineFailureReason.of` is unused (blind) | low | No caller passes it. | patch |
| 12 | A re-created source or re-saved row gets a whole-second stamp and can lose to a same-second tombstone; the docs say "millisecond stamp" (blind, edge case, verification gap) | low | The trigger stamps `strftime('%s')*1000`. Only a re-add within the same second as its delete loses (tests shift by 2 s), which is unlikely in use, and a code fix would add a second statement to five save paths. The misleading comment in `sync_local_data_source.dart` and `architecture.md` point 4 are corrected. | patch (docs only) |
| 13 | The deferred entry claims the deleting device removes the files (blind) | low | Only the single-attachment delete removes a file; bulk deletes and the 30-day purge leave files behind (as hard deletes did before). The entry is corrected. | patch (docs) |
| 14 | A Fasten sync re-inserts deleted records and sources (blind, edge case) | medium | `cacheFhirResources`/`cacheSources` use `insertOrReplace`. This existed before, since hard-deleted rows also came back from Fasten, and Fasten is excluded by the intent. | defer |
| 15 | Tombstones keep the deleted health data (`resource_raw`, note text) for 30 days, in deltas and backups (blind) | medium | Real, and caused by tombstones. Stripping content changes what an old peer shows (it does not filter tombstones), so it is a product decision; raised to the user. | defer |
| 16 | `Quantity.comparator` is dropped (`< 0.5` shows as `0.50`) (blind) | medium | The code before this branch dropped it too; not among the section 4 bugs. | defer |
| 17 | Google Wallet reports success when the plugin has no activity or Wallet is unavailable (edge case) | maybe-false (medium if true) | Settle it by running on a device without Google Wallet and checking `getWalletApiAvailabilityStatus()`. | defer |
| 18 | A record brought back by a later edit stays without its notes (blind) | low | Real, but needs a concurrent offline edit against a delete; a fix would revive notes on resurrection, which adds logic. | reject |
| 19 | The out-of-memory message is new code pinned as a bug (blind) | false | The old `_sanitizeError` mapped "Not enough memory" to `processingFailedCapacity` too; the behaviour is kept and deferred. | reject |
| 20 | The `'corrupted'` match is too broad (blind) | false | The old `_sanitizeError` matched the same substring on every failure; typed exceptions are already deferred. | reject |
| 21 | `ShareResultStatus.unavailable` is ignored (blind) | false | On Android `unavailable` is the normal result after sharing, so treating it as a failure would report successful exports as failed; failures to open throw. | reject |
| 22 | Snackbar code is repeated instead of shared (blind) | low | The codebase already shows snackbars inline in about 30 places, and no UI kit helper exists; a helper adds new public surface. | reject |
| 23 | The spec does not log its own deviations (blind) | low | Fixing it means editing this build's spec. | reject |
| 24 | Values below 5e-7 show as `0.000000` (edge case) | low | The cap of 6 is the frozen decision; lab values that small are not reported in such units. | reject |
| 25 | `SyncPage` cannot be reached (verification gap, other) | low | Covered by finding 1: the listener moves to the app shell. | reject (duplicate) |
| 26 | Re-adding a row in the same second as its delete is not pinned by a test (verification gap, other) | low | Covered by finding 12. | reject (duplicate) |
| 27 | Desktop backup count / `_getRecordCount` (edge case claim) | low | Same defect as finding 7. | reject (duplicate) |
| 28 | `cacheSources` re-caches deleted backend sources (edge case claim) | medium | Same root cause as finding 14. | reject (duplicate) |

## Design Notes

**Delete sync contract (no wire or schema change):**
1. A user delete of a `fhir_resource`, `sources` or `record_notes` row runs `UPDATE … SET deleted_at = :nowMs, updated_at = :nowMs`. The value is written in ms with raw SQL, never through a Drift `DateTime`, which would store seconds.
2. Tombstones travel in normal deltas (`computeDelta` does not filter them). LWW per row decides: the newer `updated_at` wins, so a later edit resurrects the row.
3. Every UI and export read excludes `deleted_at IS NOT NULL`. Row counts already do.
4. Any save or insert of a row clears `deleted_at`.
5. `cleanupTombstones` keeps purging after 30 days. A device offline for longer than that can resurrect the row; this limit is accepted and documented.
6. **Mixed versions:** an old peer stores the tombstones, keeps showing the rows until it updates, and its own deletes stay hard.

## Verification

**Commands:**
- `scripts/check.sh` -- expected: format, analyze and tests clean, 0 infos.
- `scripts/coverage.sh --files <dir>` for each touched dir -- expected: touched files ≥ 90% on new or changed code, reported against the baseline.
- `fvm flutter gen-l10n` and `fvm dart run build_runner build` after ARB or Freezed changes -- expected: `untranslated_messages.json` has no new keys.

**Manual checks:**
- On a phone paired with the desktop: delete a record on each side, then reconnect; both stay gone.

**Final validation (2026-10-30, after merging `origin/develop` at 07cf3f78):**
- **CI jobs run locally as CI runs them:**
  - `checks`: format of every tracked Dart file, analyze with 0 issues, and 2,456 tests passing with 17 skipped, on macOS and on Linux in Docker (`buildpack-deps:bookworm`, Flutter 3.47.7, empty `.env`, fresh build_runner).
  - **Share transfer race** (7c0e1d03): after the merge, a share test from `develop` failed on Linux ("Bad state: seal() must run first"), and plain `develop` failed the same file in 5 of 5 Linux runs.
    - The cause is real: when the share screen closed while a payload was being sealed, the handler resumed on the disposed session. It started a key exchange that threw, and it left the payload file behind, because the bloc's cleanup had already run.
    - The handler now deletes that payload and stops. A disposed `SecureShareSession` cancels instead of throwing, and keeps no keys sealed after disposal.
    - The two tests wait for the handler instead of assuming one event-queue pass, and a new test pins the close-while-writing case.
    - The share tests then passed 5 of 5 more times on Linux.
    - The user approved this change to `share_records`, which this spec otherwise leaves alone, to get the pipeline green.
  - `lint`: pre-commit on the files changed since `develop`.
  - `lint:commits`: commitlint.
  - `scan:secrets`: gitleaks, no leaks.
  - `scan:dependencies`: osv-scanner, no issues.
- **Coverage:** 1,183 of the 1,189 executable lines this branch adds or changes are covered on macOS (99.5%; 82.7% before the validation). Whole app: 44.7% after the merge (baseline 30.0%).
  - Not covered: 5 lines no test can reach (see `deferred-work.md`), and the unsupported-platform throw in `pdf_open.dart`, which runs only on Linux, so CI covers it.
- **End to end:** `integration_test/app_l10n_test.dart` passes on the iOS simulator. `extraction_bench_test.dart` is a benchmark that needs the AI model and a dataset; it was not run, and this branch changes only error messages in that pipeline.
- **Builds:** iOS release, macOS desktop release (`lib/main_desktop.dart`) and Android debug APK (JDK 17) all succeed. Windows cannot be built on a Mac and is built only by its manual CI job.

**Manual check results (2026-10-28 to 2026-10-30, iPhone 13 Pro, iOS simulator, macOS desktop):** 79 of 86 checks passed. The checklist was kept outside the repository and removed when testing ended.
- **Record values:** missing units, values and bounds, open ranges, decimals, blood type, partial dates and the region units, on the phone and the desktop.
- **Errors:** IPS export failure (forced with a test build), scan, import, demo data and the wallet pass show translated messages; an attachment that is missing or not a readable PDF shows a message.
- **Attachments:** two files named `report.pdf` are kept apart and each opens its own content; deleting one keeps the other; two files picked at once are both saved.
- **Delete sync:** done with a paired phone, and with the simulator paired with the desktop through a copy of the desktop's pairing. Records, notes, attachments, sources, encounter-with-related deletes and re-processed documents stay deleted on both sides after reconnecting and restarting both apps, also when deleted offline and after a phone restart that clears the offline queue. An edit after a delete brings the record back. Lists, search, Home counts, IPS export, backups, restore and reset hide deleted records.
- **Desktop backup:** create, restore (including with notes), the failed-restore card, the success card and dialog, auto-hide, and the Romanian and German layout.
- **Update over an existing install:** a `develop` build carrying production's old launch image, updated to this branch on the simulator. Only the new logo shows on cold launches; records, notes, attachments and the pairing are kept; attachments saved by the old build still open after the app container moved. Production itself cannot run on this Mac's only simulator runtime (iOS 27; its ML Kit pods are Intel-only), and `develop` has the same schema, so the 9 → 11 migration is covered only by `migration_test.dart`.
- **Covered by automated tests instead:** the 30-day tombstone purge; same-named attachments arriving on the desktop as two files.
- **Not checked by hand (7):**
  - the delete dialog's six checks, covered by `delete_record_dialog_test.dart` but not looked at in dark mode or in Romanian or German;
  - deleting a note on the desktop and seeing it go on the phone (phone → desktop passes).

**Known limitations (not bugs of this branch):**
- Not checkable on a local build or device:
  - a signed Apple Wallet pass (signing files live in CI variables);
  - Android: Google Wallet, its unavailable case, install;
  - Fasten sync (out of scope; only its error text changed).
- With a full-tunnel VPN on the computer, the phone keeps reconnecting and never syncs. The app warns about it; the reconnect logic is unchanged.
- A desktop build without this change keeps showing records deleted on the phone; ship both together.
- A delete and a re-create or edit on the other device within the same second can leave the record deleted (whole-second stamps).
- A record brought back by a later edit on the other device returns without its notes.
- A deleted Fasten record or source comes back with the next Fasten sync.
- Deleted records keep their content on the device and in desktop backups for 30 days, until the purge (open product decision).
- Attachment files of deleted documents stay on disk. Only the single-attachment delete on the phone removes its file.
- Notes created on both devices can share an id and overwrite or delete each other (pinned `BUG:` test).
- A dose of 0.5 mg shows as "1 mg", and a lab value with a comparator (`< 0.5`) shows without it. Both existed before and are deferred.
- The Home vitals card still shows a scanned weight or temperature in the region unit (open product decision).
