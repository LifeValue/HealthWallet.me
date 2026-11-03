---
title: 'Unique ids and file names for documents; attachment files removed with their records after the 30-day window'
type: 'bugfix'
created: '2026-11-03'
status: 'ready-for-dev'
route: 'dispatch'
review_loop_iteration: 0
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
- Leftover files nothing refers to are swept at every start, in the background, on phone and desktop. Every deleted file is logged.
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
- [ ] `document_reference_service_test.dart`, new `test/features/processing/data/services/pdf_generation_service_test.dart` -- Un-skip `:173`; test same-name PDFs and names not reused after a delete.
- [ ] `lib/core/utils/stored_file_name.dart` and `test/core/utils/stored_file_name_test.dart` (moved), `document_reference_service.dart`, `pdf_generation_service.dart`, `session_handler.dart:546`, `handover_service.dart:96`, `record_attachments_bloc.dart:227,270-298` -- Uuid ids and names, plus `setLastModified` after each copy.
- [ ] `lib/core/services/attachment_file_cleaner.dart`, `test/core/services/attachment_file_cleaner_test.dart` -- Tests for a resurrected row keeping its file, the top-level and exclusion rules, symlinks and a symlinked root, subfolder URLs, the Linux guard, the age rule with an old mtime, a per-file transaction, and a sync write racing the sweep.
- [ ] `records_repository_impl.dart`, `record_attachments_bloc.dart:471-487` -- Deletes keep files; `_deleteFileIfUnused` does nothing; `clearDemoData` is unchanged. Update the delete tests.
- [ ] `lww_sync_service.dart` `cleanupTombstones()` -- Purge cleanup and the unawaited sweep. New `test/features/desktop/lww_sync/data/services/lww_sync_file_cleanup_test.dart`: a purged row's file is deleted; a shared file is kept; a tombstone younger than 30 days keeps its file; a received tombstone deletes nothing; a record deleted and brought back within 30 days (re-sync or restore) opens its file.
- [ ] `_bmad-output/planning-artifacts/architecture.md` -- The 30-day file rule and the sweep.

**Acceptance Criteria:**
- Given phone and desktop on this version, when deletes sync both ways, then `delete_sync_round_trip_test.dart` stays green and no live record loses its file.
- Given a deleted record, when it is brought back within 30 days, then it opens its file on the device that deleted it.
- Given a fresh install with demo data, when the app starts twice, then the sweep deletes nothing that any record uses.

## Implementation Notes

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `fvm dart run build_runner build` -- expected: succeeds
- `fvm flutter test test/features/processing test/features/records test/features/desktop test/core` -- expected: all pass, no skip at `document_reference_service_test.dart:173`
- `scripts/check.sh` -- expected: no issues

**Manual checks (if no CLI):**
- On a phone and on macOS: delete a record with a PDF. The file stays. Move the device clock (or seed `deleted_at`) past 30 days and restart: the record and its file are gone, other records still open theirs, and the log lists what was removed.
