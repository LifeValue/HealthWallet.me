---
title: 'Correct record values, surface silent errors, and keep deletes deleted'
type: 'bugfix'
created: '2026-10-28'
status: 'in-progress'
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
- [ ] Section 4 extractors + `fhir_reference_utils.dart` + `records_repository_impl.dart:589` -- fix and un-skip the 9 tests; pin the unpinned siblings (ratio, period, abatement) with passing tests.
- [ ] `records_bloc.dart`, `records_state.dart`, listener in the home/records UI -- IPS export failure state with a translated snackbar.
- [ ] `wallet_pass_bloc.dart` + a `BlocListener` near `app.dart:150` -- await the Google save; failures carry a translated message; un-skip :205-225.
- [ ] `sync_bloc.dart` + sync page -- typed classification, no raw text at :70/174/255, error shown; update `sync_bloc_test.dart`.
- [ ] Processing files listed above + ARB -- typed reasons and translated UI text; `Failure.error` unchanged for handover.
- [ ] Empty catches (65) -- log, show, or comment per the Code Map, one commit per feature.
- [ ] `record_attachments_bloc.dart` -- unique stored names and ids; first `RecordAttachmentsBloc` tests (attach, view and delete paths).
- [ ] `emergency_card_builder.dart` -- status filters, MedicationRequest, de-duplication; first builder tests.
- [ ] Delete sync, last -- add the contract below to `architecture.md` (LWW section, replacing the "nothing sets deleted_at" note); soft-delete and filter as in the Code Map; save paths clear `deleted_at`; tombstone guards in the LWW services; tests for repository deletes, reads, resurrect-on-save, and a phone→desktop delete round trip through `LwwSyncService`.
- [ ] `deferred-work.md` + `mobile-stabilization.md` -- mark done items; defer the note-id collision (pinned as a `BUG:` test) and orphaned files of tombstoned DocumentReferences.

**Acceptance Criteria:**
- Given any record with a missing unit, value or bound, when it is displayed, then no "null" appears.
- Given a failing IPS export, Google or Apple pass, sync, scan or import, when it fails, then the user sees a translated message without exception text, and the error is logged.
- Given `grep` for empty catch bodies in lib/ outside desktop and share_records, when it runs, then every hit has a reason comment.
- Given a mobile build with this change paired with a desktop build of it, when either side deletes a record, note or source, then it stays deleted on both after reconnect and after a full-table resend.
- Given `scripts/check.sh`, when it runs, then it passes, with 9 fewer skipped tests plus the wallet one.

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
