---
title: 'Unique ids and file names for documents; attachment files removed with their records after the 30-day window'
type: 'bugfix'
created: '2026-11-03'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '711c4720deee240420aedd2bf0aacbde26609b8c'
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
- Scanned and encounter documents get millisecond ids, so two saved in the same millisecond overwrite each other.
- Stored file names collide or get reused: `scanned_document_<date>_<n>`, `pdf_<ms>_<name>`, and same-name imports.
- Attachment files of deleted records stay on the device for ever, and nothing removes files already left behind. Meanwhile record and attachment deletes remove the file immediately, so undoing a delete or a restore can't bring the file back.

**Approach:**
- Use uuids for document ids and stored names.
- Files work like a recycle bin: a deleted record keeps its files until its tombstone is purged after 30 days, and the purge then deletes every file no other row refers to.
- A start-up sweep on phone and desktop removes old files that no row refers to.
- One shared, strict cleaner decides what may be deleted.

**Depends on:** `spec-complete-backups.md` is implemented first. It creates `lib/core/services/attachment_references.dart`, and a restore brings files back.

## Boundaries & Constraints

**Always:**
- Write a failing test first, and un-skip `document_reference_service_test.dart:173`.
- Deleting a record, an attachment or a session's replaced documents, locally or through sync, removes no file. Files go only:
  - at the 30-day purge (`cleanupTombstones`), counting every live or tombstoned row except the rows being purged; or
  - by the start-up sweep, counting every row.
- **A file may be deleted only when all of these hold:**
  - It is a top-level regular file in `PathResolver.getDocumentsPath()`: not a symlink, not a dot-file, not `db.sqlite*`, not `*.log`, not `*.db`. Nothing in a subfolder.
  - No reference to it is found through `attachment_references.dart`: any `file://` URL in any `fhir_resource.resource_raw`, or any entry in `processing_sessions.file_paths` or `resources`. Basenames are split on `/` and `\` and compared raw and decoded, case-insensitively. An unparseable row is matched as raw text, so the file is kept.
  - For the sweep only: the file is more than 7 days old by `max(modified, changed)`. Every copy into Documents sets `setLastModified(now)`.
- Each file is checked and deleted inside `AppDatabase.transaction`, so sync writes can't interleave.
- The sweep runs only on Android, iOS, macOS and Windows.
- Every delete and every failure is logged with `logger`.
- Sync row shapes don't change.

**Never:**
- Touch the source delete path (`sync_local_data_source.dart`, `soft_delete.dart`), `clearDemoData`, `home_bloc.dart`, or the `SyncLocalDataSourceImpl` and `RecordAttachmentsBloc` constructors, which holders rewrites. In `record_attachments_bloc.dart`, touch only `:213-227`, `:270-298` and `:471-487`.
- Use `getApplicationDocumentsDirectory()` in the cleaner.
- Run the sweep on Linux.
- Fix the Windows attachment folder (`record_attachments_bloc.dart:213`); that is deferred desktop work.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two documents saved in one ms | Same source | Two rows, two ids | N/A |
| Same-name imports or PDFs | One save, or a deleted `_n` name | Distinct uuid names; a name is never reused | N/A |
| Record or attachment deleted | On phone or desktop, or received via sync | Row tombstoned; file kept | N/A |
| Undo within 30 days | Restore or re-sync brings the row back | Record opens its file again | N/A |
| Purge after 30 days | Tombstone with a file no other row uses | Row purged, file deleted | Logged |
| File shared by two records | One purged | File kept | N/A |
| Legacy, Windows `C%3A%5C…`, encoded or different-case URL | Another row uses the file | File kept | N/A |
| Unparseable row | `%` error or bad JSON | File kept | Logged |
| Purged row points into a subfolder (`ai_models/x.gguf`) | Purge | Not deleted | N/A |
| Sweep | Top-level file, older than 7 days, unreferenced | Deleted in a transaction | Logged |
| Sweep | Freshly copied file with an old mtime, row not yet written | Kept (mtime set on copy) | N/A |
| Sweep on Linux | Any | Doesn't run | N/A |

**Decisions (2026-11-03):**
- A deleted record's files are kept for 30 days, like the record, on phone and desktop, so undo and restore always work with files. Storage is freed at the purge.
- Leftover files nothing refers to are swept at every start, in the background, on phone and desktop. Revised by the user after review: the sweep moves them into a hidden `<Documents>/.trash/` folder and deletes them only 30 days later, because earlier bugs left real documents without a row. Files of purged records are still deleted directly. Counts are logged, names only as hashes.
- Source deletes stay out of this slice (holders owns that code). Their files follow the same 30-day purge and sweep.

</frozen-after-approval>

## Code Map

- Ids and names:
  - `lib/features/processing/domain/services/document_reference_service.dart` -- `_generateId` `:355-357` (used at `:142,193`); the row id is at `:237`, saved with `insertOnConflictUpdate` at `:251`.
  - `lib/features/processing/data/services/pdf_generation_service.dart` -- `:82` copies a file; `:136,155-157` name files `pdf_<ms>`; `:159-199` builds `scanned_document_<date>_<n>`.
  - `lib/features/processing/presentation/bloc/handlers/session_handler.dart:546` names imports `${base}_<ms>`.
  - `lib/features/desktop/handover/data/services/handover_service.dart:96` uses the same kind of name.
  - `uniqueStoredFileName` is a static at `lib/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc.dart:270-298`, already with a uuid suffix (`:290`). Move it unchanged to `lib/core/utils/stored_file_name.dart` and reuse it for the other three names. Move its tests (`record_attachments_bloc_test.dart:979+`, a file holders edits) to `test/core/utils/stored_file_name_test.dart`. Add `setLastModified` after the copy at `:227`.
- Immediate deletes to remove:
  - `lib/features/records/data/repository/records_repository_impl.dart:272-295` -- record delete calls `_deleteFileIfUnused` (`:373-399`; collected by `_attachmentFileUrls` `:346-368`). Stop deleting files there. `clearDemoData` (`:711-725`, untouched because holders rewrites it) tombstones the demo rows through `deleteSource` (`:720`), so its PDF is also kept until the purge. Remove the call from record delete. Keep the `_deleteFileIfUnused` method only because `clearDemoData` calls it (`:725`); make its body do nothing, with a comment that files go at the 30-day purge. Only the purge and the sweep delete files.
  - `record_attachments_bloc.dart:471-487` -- an unguarded second delete. Remove it.
- `lib/core/services/attachment_file_cleaner.dart` (new, injectable; takes `AppDatabase`, `PathResolver` and `AttachmentReferences`, the API defined in the backup spec) -- provides `deleteUnreferenced(Iterable<String> candidateUrls)`, checked against every remaining live or tombstoned row, and `sweep()`.
- `lib/features/desktop/lww_sync/data/services/lww_sync_service.dart`:
  - The constructor is at `:114`, with 4 test sites.
  - `cleanupTombstones` (`:911-947`, no transaction today): collect the purged rows' URLs and run the DELETE in one `transaction`. After it commits, call `deleteUnreferenced(candidates)`. Each file is checked against the remaining rows inside its own transaction, so a row resurrected meanwhile keeps its file. Then start `sweep()` unawaited.
  - `_repairAttachmentUrls` (`:842-869`) repoints rows to any top-level file of the same name, which is why each check runs in a transaction.
  - `_applyRow` and `applyBatch` stay unchanged.
- `lib/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart:134-139` -- `_onInitialised` runs `cleanupTombstones()` on both apps (`main.dart:57`, `main_desktop.dart:62`). Its constructor is unchanged.
- `lib/core/services/path_resolver.dart:18-24` -- on non-Windows the docs root is `getApplicationDocumentsDirectory()`, which is why Linux is excluded.
- Only `LwwSyncService` gains the cleaner. `RecordsRepositoryImpl`, `DocumentReferenceService` and `RecordAttachmentsBloc` keep their constructors: their deletes only tombstone.
- Tests:
  - `test/features/records/data/repository/records_repository_delete_test.dart`: `:116-151` "deleting a document deletes its file" becomes "keeps its file until the purge"; around `:170-205` "clearing the demo data deletes its notes and its PDF" becomes "…keeps its PDF until the purge".
  - `test/features/records/presentation/widgets/record_attachments/bloc/record_attachments_bloc_test.dart:127,1018+` -- relies on the second delete.
  - `test/features/processing/domain/services/document_reference_service_test.dart:173`
  - `test/features/desktop/lww_sync/data/services/lww_sync_service_test.dart:739-800` (cleanup)
  - `test/features/desktop/lww_sync/delete_sync_round_trip_test.dart:150-183`
  - Holders edits `lww_sync_service_test.dart` and both `record_attachments_bloc_test.dart` files, so put new cases in new files.
- Docs: `_bmad-output/planning-artifacts/architecture.md:202` ("no live record uses"). Change it to the 30-day rule and describe the sweep.

## Tasks & Acceptance

**Execution:**
- [x] `document_reference_service_test.dart`, new `test/features/processing/data/services/pdf_generation_service_test.dart` -- Un-skip `:173`; test same-name PDFs and names not reused after a delete.
- [x] `lib/core/utils/stored_file_name.dart` and `test/core/utils/stored_file_name_test.dart` (moved), `document_reference_service.dart`, `pdf_generation_service.dart`, `session_handler.dart:546`, `handover_service.dart:96`, `record_attachments_bloc.dart:227,270-298` -- Uuid ids and names, plus `setLastModified` after each copy.
- [x] `lib/core/services/attachment_file_cleaner.dart`, `test/core/services/attachment_file_cleaner_test.dart` -- Tests for a resurrected row keeping its file, the top-level and exclusion rules, symlinks and a symlinked root, subfolder URLs, the Linux guard, the age rule with an old mtime, a per-file transaction, and a sync write racing the sweep.
- [x] `records_repository_impl.dart`, `record_attachments_bloc.dart:471-487` -- Deletes keep files; `_deleteFileIfUnused` does nothing; `clearDemoData` is unchanged. Update the delete tests.
- [x] `lww_sync_service.dart` `cleanupTombstones()` -- Purge cleanup and the unawaited sweep. New `test/features/desktop/lww_sync/data/services/lww_sync_file_cleanup_test.dart`: a purged row's file is deleted; a shared file is kept; a tombstone younger than 30 days keeps its file; a received tombstone deletes nothing; a record deleted and brought back within 30 days (re-sync or restore) opens its file.
- [x] `_bmad-output/planning-artifacts/architecture.md` -- The 30-day file rule and the sweep.

**Acceptance Criteria:**
- Given phone and desktop on this version, when deletes sync both ways, then `delete_sync_round_trip_test.dart` stays green and no live record loses its file.
- Given a deleted record, when it is brought back within 30 days, then it opens its file on the device that deleted it.
- Given a fresh install with demo data, when the app starts twice, then the sweep deletes nothing that any record uses.

## Implementation Notes

- Choices that don't block the work and aren't settled by this spec may be decided during implementation; record each one here with its reason.
- Built in parallel worktrees `.claude/worktrees/spec4-{A,B,C}` on a local base `02a6fed3` (develop plus spec 1 plus spec 3's data layer). `baseline_commit` is set when spec 3 is committed.
- Cross-spec fixes at merge: spec 3's `restore_sync_round_trip_test.dart` and `lww_sync_pause_test.dart` build `LwwSyncService` and now pass the cleaner. The round-trip test's step "deleting the record removes its file" now expects the file to be kept (the 30-day rule) and removes it as the purge would before checking that the safety copy brings it back. `scripts/check.sh` with specs 1–4 passes (2,798 tests, 13 skips).
- Merge (2026-11-03): packages A, C and B applied on top of spec 3 (`711c4720`) without conflicts. Added backup metadata (`*.db.meta.json`, `*.db.meta.json.tmp`) to `AttachmentFileCleaner.isProtectedName`, because a backup folder can be the Documents root. The new sweep test fails without the fix.
- Package B, cleaner and sweep (worktree `spec4-B`):
  - `@lazySingleton AttachmentFileCleaner(AppDatabase, PathResolver, AttachmentReferences)`. `deleteUnreferenced` and `sweep` return a count and never throw. Also `fileUrlsOf`, `isProtectedName`, `supportedPlatforms`, `sweepMinAge` and a `forTesting` constructor.
  - `LwwSyncService` takes it as its 4th argument; its 4 test sites are updated.
  - `cleanupTombstones` collects URLs and deletes in one transaction, then calls `deleteUnreferenced`, then an unawaited `sweep()`.
  - Each file's lstat, age, reference and delete checks run in one transaction.
  - URLs are matched raw and decoded, case-insensitively. Bare names, absolute paths directly in Documents and iOS container paths all count; other absolute paths fall back to their basename; relative subfolder paths name no file.
  - Decisions:
    - Both methods delete nothing off Android, iOS, macOS and Windows.
    - A symlinked Documents root deletes nothing.
    - An unreadable purged row adds no candidate; the sweep handles it.
  - `architecture.md:133,202,206` updated in that worktree.
  - Tests: cleaner 34, purge cleanup 9; mutation checks fail as expected.
  - Known noise: in old lww tests the background sweep can log after tearDown closes the database.
  - Risk: a user-chosen backup folder equal to the Documents root would have its `*.db.meta.json` swept.
- Package A, ids and names (worktree `spec4-A`):
  - `lib/core/utils/stored_file_name.dart` holds `uniqueStoredFileName` (moved unchanged, now top-level) and a new `copyAsNewFile` (copy, then `setLastModified(now)`; a failed timestamp is logged with `logger.w`, not thrown, because the change time is already fresh).
  - Document id and `document-id` use one uuid, as the old double ms call was effectively one value.
  - Scans are named `scanned_document_<8hex>.pdf`; imports `<sanitised>_<8hex>.pdf`.
  - `session_handler` and `handover_service` use `uniqueStoredFileName`. Their names are sanitised, so a path in the phone's `file_name` can no longer leave `imports/`.
  - Handover and `createPdfFromImages` write rather than copy, so they get a fresh mtime with no extra call.
  - Tests:
    - New `stored_file_name_test` and `pdf_generation_service_test`.
    - `document_reference_service_test.dart:173` un-skipped.
    - The `handover_service_test` same-name skip un-skipped.
    - `processing_session_steps_test` extended.
    - The moved group removed from `record_attachments_bloc_test` (expect a small conflict there with package C).
  - Known limit: names keep an 8-hex suffix plus an existence check, so "never reused" holds in practice, not absolutely.
- Package C, deletes keep files (worktree `spec4-C`):
  - `_deleteRecords` only tombstones.
  - `_deleteFileIfUnused` has an empty body with a comment and stays only for the untouched `clearDemoData`.
  - The unused `package:path` import is removed.
  - `_pathResolver` is no longer read but the constructor must stay, so it is kept with `// ignore: unused_field` and a comment.
  - `record_attachments_bloc.dart`: only the second delete (old `:471-487`) is removed.
  - Tests: three delete tests now expect the file to be kept; new cases for "brought back finds its file" and "encounter delete keeps files" are in `records_repository_delete_test.dart`. The delete test at `:1019` of the bloc test is updated.
  - All of them fail on the old code. Full suite: 2,559 passed.
  - `architecture.md:133,202` is left for package B.

## Spec Change Log

## Review Triage Log

All `patch` rows and the quarantine decision are fixed. Building the quarantine also found that `AttachmentSyncService` served files from dot-folders (`.trash/`, `.restore-*`, `.sync-*.part`), so sync and backups now refuse them. `scripts/check.sh` with specs 1–4 passes (2,824 tests, 13 skips).

| # | Source | Finding | Verdict | Evidence | Route |
|---|---|---|---|---|---|
| 1 | blind | The first sweep would permanently delete real documents that earlier bugs left without a row | high | For example, a same-millisecond overwrite left its PDF with no row | intent_gap; resolved by the user: quarantine in `.trash/` for 30 days |
| 2 | blind, verification, edge | Windows: attachments in the user's Documents root are never deleted after their record is purged | medium | The old immediate delete used `toAbsolute`; the cleaner only saw its own root | patch: purge-only handling of `LegacyAttachmentFolders.roots()` |
| 3 | blind, edge | `isReferenced` decodes every row per file inside a write transaction | medium | Full-table `SELECT` per candidate | patch: SQL `instr` pre-filter with `sqlNeedle` |
| 4 | blind, edge | The purge path has no age guard; a just-written fixed-name file can be deleted | medium | `checkAge: false` | patch: 1-hour `purgeMinAge` |
| 5 | blind | File names logged at info level | medium | Names can carry health data | patch: counts at info, hashed names at debug |
| 6 | blind | Non-ASCII names mangled in stored names and imported PDF titles | medium | ASCII-only `[^\w.\-]` filter | patch: Unicode letters, marks, digits and spaces kept; `originalFileStem` for titles |
| 7 | verification | The test can't show the purge doesn't await the sweep | medium | The recording cleaner passes through | patch: Completer-gated sweep |
| 8 | blind | The "by a restore" test can't fail; `sessions.resources`, Media single map and `copyAsNewFile` failure untested | low | Test gaps | patch |
| 9 | blind, verification | Doc says the cleaner is the only file deleter, but session deletes remove `imports/` files | low | Wording | patch |
| 10 | blind | Files of purged records in subfolders are never deleted | medium | The frozen rule says "nothing in a subfolder" | defer: accepted limit, documented |
| 11 | blind | The sweep runs at every start with no throttle | low | Cheap once pre-filtered | reject |
| 12 | blind | Root ownership is decided by OS name; an unsandboxed macOS build would sweep `~/Documents` | low | Release builds are sandboxed | defer |
| 13 | blind, edge | Dead `clearDemoData` URL loop and `ignore: unused_field` | low | Kept because holders rewrites `clearDemoData` and the constructor must stay | reject |
| 14 | blind | `PdfStorageService.savePdfToStorage` copies without `setLastModified` | low | No callers; batch 2 removes it | reject |
| 15 | edge | The sweep could race a restore that reuses an orphan | low | Sweep runs at start-up for seconds; restores are user-started | reject |
| 16 | edge | A system clock jump purges early | low | Predates this change | reject |
| 17 | edge | OneDrive-shared `HealthWallet\Documents` across two PCs | low | Rare setup | defer |
| 18 | edge | Tests inherit `Platform.operatingSystem` | low | CI runs on macOS | reject |
| 19 | edge | The unawaited sweep after tearDown logs noise | low | Test-only noise | reject |
| 20 | edge | `deleteProcessingSession` and the OCR helper delete files without the cleaner | low | Session `imports/` files, not attachments; documented via #9 | reject |

## Verification

**Commands:**
- `fvm dart run build_runner build` -- expected: succeeds
- `fvm flutter test test/features/processing test/features/records test/features/desktop test/core` -- expected: all pass, no skip at `document_reference_service_test.dart:173`
- `scripts/check.sh` -- expected: no issues

**Manual checks (if no CLI):**
- On a phone and on macOS: delete a record with a PDF. The file stays. Move the device clock (or seed `deleted_at`) past 30 days and restart: the record and its file are gone, other records still open theirs, and the log lists what was removed.
