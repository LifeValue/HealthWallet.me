---
title: 'Desktop backups include attachment files; restore goes back in time on both devices and can be undone'
type: 'feature'
created: '2026-11-03'
status: 'in-progress'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'b079f4f5b097bbb7b2d2b679f00894e7e5b65b6c'
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
- Desktop backups, made by hand or requested from the phone, hold only the database, so restored records can point at PDFs and photos that no longer exist. Once attachment cleanup ships (`spec-attachment-ids-and-files.md`), they won't.
- A restore keeps old `updated_at` stamps, so with a paired phone the phone's newer rows and tombstones win again and partly undo it. The dialog wrongly says the phone is not affected.
- Nothing lets a wrong restore be undone.

**Approach:**
- Each backup keeps today's `<name>.db` and `.db.meta.json`, plus a `<name>.files/` folder with every attachment file its rows refer to.
- Restore works like OneDrive, Dropbox Rewind and iCloud:
  - It first saves an automatic "Before restore" backup.
  - It adds the backup's files.
  - It makes the backup the current state on desktop and phone: restored rows get a fresh stamp, and rows added since the backup become tombstones, kept 30 days.
- Old database-only backups keep working.

## Boundaries & Constraints

**Always:**
- Write a failing test first.
- Old backups (metadata without `formatVersion` 2) restore their rows with the same point-in-time rules and keep every current file. New backups stay listable by older app versions, because the `.db` and `.db.meta.json` pair stays.
- **Before the restore:**
  - If the phone is connected, the desktop first calls `LwwSyncBloc.waitUntilDrained()` (`lww_sync_bloc.dart:590-604`, which only drains the desktop's own outbox), then sends a digest and waits for `state.tablesMatch == true` (set in `_onDigest`, `:461`), with a 60 s timeout. This uses the existing protocol, so the phone's latest records are in the safety copy and the current data.
  - On timeout, or if the phone is paired but not connected, skip the wait and show `backupRestorePhoneOffline` in the confirm dialog.
  - While restoring, received batches wait: add `LwwSyncBloc.pauseApplying()` and `resumeApplying()`, where `_onBatch` (`:390`) awaits a completer before applying. It never replies `sync.ack ok:false`. A phone ack timeout (60 s) and resend is expected and harmless, because applying is idempotent.
- **Point in time**, for the synced tables `fhir_resource`, `sources` and `record_notes`, in one transaction with stamp `S = MAX(now, max(updated_at) over current and backup synced rows + 1)`:
  1. Copy the current rows whose key is not in the backup into TEMP tables. The keys are `fhir_resource.id`, `sources.id`, and `COALESCE(uuid, 'legacy-' || id)` for notes, compared the same way on both sides.
  2. Delete children first, as today.
  3. `INSERT … SELECT` the shared columns from the backup, with `updated_at = S`. Backup tombstones also get `deleted_at = S`, so the purge doesn't drop them before they reach the phone. For old backups missing `updated_at`, `deleted_at` or `uuid`, write `S`, `NULL` and `'legacy-' || id` in the SELECT.
  4. Re-insert the TEMP rows as tombstones: `deleted_at` and `updated_at` set to `MAX(S, row.updated_at + 1)`, `resource_raw` kept. Notes go back without `id` (they keep `uuid`) so they can't clash with a backup note's id.
  - Plain INSERTs only, no upsert. The insert trigger stamps only a NULL `updated_at`, so `S` stays.
  - `sync_outbox` is never restored from a backup. The other local tables (`processing_sessions`, …) are restored as today.
  - Don't call `resetPeerState`, which prunes the outbox the restore just filled. After commit, send `LwwSyncEvent.localChanged()`. The digest reconcile on every connect (`lww_sync_bloc.dart:236`) covers a phone that was offline.
- **Files:**
  - Backups include only files referenced from `fhir_resource` rows. Scan-session files (`processing_sessions`, under `imports/`) are not backed up; restored sessions behave as today.
  - Restore never deletes or overwrites a current file.
  - A file with the same name and the same hash is skipped.
  - A file with a different hash goes under a free name, and its URLs are repointed in the restored rows inside the transaction. The rows keep the restore stamp, as `_writeRawKeepingStamp` does (the update trigger must not re-stamp them).
  - Files are staged into `Documents/.restore-<id>/`, hashed after copying, moved, and given `setLastModified(now)`.
  - A missing or damaged file doesn't stop the restore: the rows and every good file are restored, and the user is told how many files couldn't be restored.
- **Failures:**
  - A failure before the transaction leaves the database untouched and removes the staging folder.
  - A failure inside the transaction rolls back.
  - `backupRestoreFailed` is shown only when the transaction didn't commit. Errors after the commit, such as the sync notification, are logged, and the restore counts as done.
  - The safety backup stays either way.
  - A leftover `.restore-*` folder is removed at start-up and before each restore.
  - A partial backup is removed on failure. The metadata is written last, as the commit marker.
- Hashes are streamed for the database and for files.
- The `.db` and `.files/` paths come from where the `.meta.json` actually is, not from the stored absolute `filePath`.
- Paths come from `PathResolver`, plus any referenced file that resolves outside it, such as Windows attachments in the Documents root.
- Log every failure with `logger`. No empty catches.
- New strings go into all four ARBs, right after `desktopBackupActionFailed` (en `:1147`), never at the end of the file. Then gen-l10n, and build_runner after DI or entity changes.

**Never:**
- Change the sync protocol, the phone code, the backup folder choice, or user-backup retention (user backups are never auto-deleted).
- Copy whole folders, or files no row refers to.
- Call the attachment cleaner from restore.
- Reference holders-branch code (`HolderLinker`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create backup (desktop button or phone request) | Records with files | `.db`, then `.files/` with free names, then metadata `formatVersion: 2`, `files: [{name, sourcePaths, sha256, size}]`, `missing: [url]` | Failure: partial `.db` and `.files/` removed; the phone gets `backup.error` `backup_failed` |
| List | Old and new | Both listed; old ones labelled "Records only"; size includes files | Unreadable metadata logged and skipped |
| Delete backup | New | `.db`, meta and `.files/` removed | Logged |
| Restore, phone connected | New backup | Sync with the phone first; then safety backup, files added, rows stamped `S`, newer rows become tombstones; the phone shows the same records and fetches missing files | N/A |
| Restore, phone paired but offline | New backup | The same restore; the dialog says records added on the phone since its last sync come back after it reconnects | N/A |
| Phone clock ahead | Phone rows stamped later than the desktop's clock | `S` is above every existing stamp, so the restore still wins | N/A |
| Restore old backup | No files | The same point-in-time rows; current files kept | N/A |
| Bad file in backup | Missing or hash mismatch | Everything else restored | Message: "{count} files couldn't be restored" |
| Name clash | Same name, other content | Free name; rows repointed; stamp kept at the restore time | N/A |
| Undo | User restores "Before restore {date}" | The previous state returns on both devices, with files | N/A |
| Safety copy age | "Before restore" copy older than 30 days | Deleted automatically at start-up and after each backup | Logged |
| Phone asks for a backup during a restore | `backup.request` | Rejected with `backup.error` | N/A |
| Crash mid-restore | `.restore-*` left behind | Removed at the next start | Logged |

**Decisions (2026-11-03):**
- Each backup has its own folder of files next to its `.db`.
- With the phone connected, the desktop syncs with it first, then restores. If the phone is offline, its unsynced records come back to the desktop after it reconnects. Nothing is lost, and the dialog says so.
- A restore makes the backup the current state on desktop and phone, the way OneDrive, Dropbox and iCloud do. Records added since the backup move to deleted for 30 days instead of being wiped.
- Every restore first saves "Before restore {date}", with files. It is the undo, and it is deleted automatically after 30 days.
- Missing or damaged files don't stop a restore; the user is told how many couldn't be restored.
- Old database-only backups restore records only and keep every current file.
- Windows attachments stored in the Documents root are backed up too.
- Strings, with their keys:
  - `backupRecordsOnly`:
    - en: "Records only"
    - es: "Solo registros"
    - de: "Nur Aufzeichnungen"
    - ro: "Doar înregistrări"
  - `backupRestoreConfirmPointInTime`:
    - en: "This replaces your records on this computer and on your paired phone with the backup from {date}. Records added since then are moved to deleted items for 30 days. A safety copy of your current data is saved first, so you can undo this."
    - es: "Esto reemplaza tus registros en este ordenador y en tu teléfono vinculado por la copia del {date}. Los registros añadidos desde entonces pasan a eliminados durante 30 días. Antes se guarda una copia de seguridad de tus datos actuales para que puedas deshacerlo."
    - de: "Dadurch werden deine Aufzeichnungen auf diesem Computer und deinem gekoppelten Telefon durch das Backup vom {date} ersetzt. Seitdem hinzugefügte Aufzeichnungen werden für 30 Tage in die gelöschten Elemente verschoben. Vorher wird eine Sicherheitskopie deiner aktuellen Daten gespeichert, damit du das rückgängig machen kannst."
    - ro: "Aceasta înlocuiește înregistrările de pe acest computer și de pe telefonul asociat cu copia din {date}. Înregistrările adăugate între timp sunt mutate la șterse timp de 30 de zile. Mai întâi se salvează o copie de siguranță a datelor actuale, ca să poți anula."
    - It is a new key. `backupRestoreFailed` replaces `desktopRestoreFailed` (en `:1146`, used at `backup_bloc.dart:246`); remove that key from all four ARBs. The `desktopRestoreBackupMessage` key (en `:642`, with `{name}` and `{count}`, saying the phone isn't affected) is no longer used: remove it from all four ARBs.
  - `backupOldNoFiles`:
    - en: "This backup has no files. Records will be restored and your current files kept."
    - es: "Esta copia no tiene archivos. Se restaurarán los registros y se conservarán tus archivos actuales."
    - de: "Dieses Backup enthält keine Dateien. Die Aufzeichnungen werden wiederhergestellt, deine aktuellen Dateien bleiben erhalten."
    - ro: "Această copie nu conține fișiere. Înregistrările vor fi restaurate, iar fișierele actuale păstrate."
  - `backupSafetyName`:
    - en: "Before restore {date}"
    - es: "Antes de restaurar {date}"
    - de: "Vor Wiederherstellung {date}"
    - ro: "Înainte de restaurare {date}"
    - `{date}` is the locale's date and time.
  - `backupRestoreFailed`:
    - en: "Restore failed. Your data was not changed; the \"Before restore\" backup is in the list."
    - es: "La restauración falló. Tus datos no cambiaron; la copia \"Antes de restaurar\" está en la lista."
    - de: "Wiederherstellung fehlgeschlagen. Deine Daten wurden nicht geändert; das Backup \"Vor Wiederherstellung\" ist in der Liste."
    - ro: "Restaurarea a eșuat. Datele nu au fost modificate; copia \"Înainte de restaurare\" este în listă."
  - `backupSafetyFailed`:
    - en: "Couldn't make a safety backup, so nothing was restored. Check free space and the backup folder."
    - es: "No se pudo crear la copia de seguridad previa, así que no se restauró nada. Comprueba el espacio libre y la carpeta."
    - de: "Das Sicherheits-Backup konnte nicht erstellt werden, daher wurde nichts wiederhergestellt. Prüfe den freien Speicher und den Ordner."
    - ro: "Copia de siguranță nu a putut fi creată, așa că nu s-a restaurat nimic. Verifică spațiul liber și folderul."
  - `backupFilesNotRestored` (ICU plural on `count`):
    - en: `{count, plural, =1{1 file couldn't be restored.} other{{count} files couldn't be restored.}}`
    - es: `{count, plural, =1{No se pudo restaurar 1 archivo.} other{No se pudieron restaurar {count} archivos.}}`
    - de: `{count, plural, =1{1 Datei konnte nicht wiederhergestellt werden.} other{{count} Dateien konnten nicht wiederhergestellt werden.}}`
    - ro: `{count, plural, one{Un fișier nu a putut fi restaurat.} few{{count} fișiere nu au putut fi restaurate.} other{{count} de fișiere nu au putut fi restaurate.}}`
  - `backupRestorePhoneOffline`:
    - en: "Your phone isn't connected. Records added on it since its last sync will come back after it reconnects."
    - es: "Tu teléfono no está conectado. Los registros añadidos en él desde la última sincronización volverán cuando se conecte."
    - de: "Dein Telefon ist nicht verbunden. Seit der letzten Synchronisierung darauf hinzugefügte Aufzeichnungen kommen zurück, sobald es sich wieder verbindet."
    - ro: "Telefonul nu este conectat. Înregistrările adăugate pe el de la ultima sincronizare vor reveni după ce se reconectează."
  - `{date}` is a pre-formatted `String` placeholder, declared in the `@` metadata.

</frozen-after-approval>

## Code Map

- `lib/features/desktop/backup/data/services/backup_service.dart`:
  - `:19` constructor. Add `PathResolver` and `AttachmentReferences`.
  - `:43-49` default folder. On macOS that is inside the sandbox Documents, a subfolder, so the sweep never touches it.
  - `:74-89` folder access through the bookmark, which covers the whole tree.
  - `:97-130` create (`VACUUM INTO` at `:110`) and metadata.
  - `:101-102` the name sanitiser is ASCII-only (`[^\w\s\-.]`). Allow Unicode letters (`\p{L}`, `unicode: true`) and keep the date readable.
  - `:138-148,236-241` hashing with `readAsBytes`. Stream it instead.
  - `:150-188` restore (checkpoint, ATTACH, shared tables, transaction, DETACH).
  - `:209-227` list. Its empty catch must log.
  - `:253-265` delete.
- `lib/features/desktop/backup/domain/entity/backup_entry.dart:7-16` -- add `formatVersion`, `files`, `missing` and `isSafetyCopy`, keeping old JSON parseable. Run build_runner.
- `lib/features/desktop/backup/presentation/bloc/backup_bloc.dart`:
  - `:146` streams a backup to the phone. Make the safety backup by calling the service directly instead.
  - `:159-167` `_onBackupRequested` never sends `backup.error`. Send `backup_failed`; current phones already map unknown codes (`:466-469`).
  - `:216-227` restore; `:227` calls `resetPeerState`, which this spec replaces with `localChanged()`. Keep `isRestoring` set during the pre-sync and the safety backup, and pause `applyBatch` while it is set.
  - `:400-419` the wait-for-sync pattern to reuse before restoring.
  - `:367-398` phone snapshot; `:371` checks only `isBackingUp`, so also refuse while restoring.
  - `:116,233` empty catches.
- `lib/features/desktop/presentation/widgets/backup_card.dart`:
  - `:98` "backup succeeded" message; the safety backup must not trigger it.
  - `:140,145` empty catches.
  - `:566-630` list tile (add the label).
  - `:723-739` confirm dialog (new text, plus the old-backup line).
- `lib/core/data/local/app_database.dart`:
  - `:18-24` `allTables` includes `sync_outbox`; exclude it by name.
  - `:329-346` the insert trigger stamps only a NULL `updated_at`; the update trigger re-stamps when `updated_at` is unchanged or NULL.
  - `:350-360` the outbox triggers.
  - Notes are keyed by `uuid`, or `legacy-<id>` when it is NULL (`lww_sync_service.dart:116`).
- `lib/features/desktop/lww_sync/data/services/lww_sync_service.dart`:
  - `:162-165` `resetPeerState` prunes the outbox. Don't call it after a restore.
  - Patterns to copy: `_freeFileName` `:786-815`, `_repointAttachment` `:817-833` (match by basename here, not exact path), `_writeRawKeepingStamp` `:894-907`.
  - `_attachmentsOf` `:881-892` misses Media's single `content`.
- `lib/features/desktop/lww_sync/presentation/bloc/lww_sync_bloc.dart:230,435,482-500` -- both apps request missing attachment files after a sync, so the phone fetches restored files from the desktop.
- `lib/core/services/attachment_references.dart` (new; spec 4 reuses it). Define this API here:
  - `Future<List<AttachmentRef>> fromResourceRaw(String raw, {required OnUnparseable mode})`, where `mode` is `skip` (backups: log and skip) or `rawText` (cleaner: keep the file by matching the basename against the raw text).
  - `Future<Set<String>> referencedBasenames({bool includeSessions = true})` over every live and tombstoned row.
  - `bool matches(String basename, String url)`.
  - It lists the files referenced by every `file://` URL in `fhir_resource.resource_raw` (DocumentReference `content[].attachment`, Media `content`, live and tombstoned) and in `processing_sessions.file_paths` and `resources`.
  - Basenames split on `/` and `\`, compared raw and decoded, case-insensitively.
  - Also reads `processing_sessions.resources`, as the attachments spec requires.
  - Unparseable rows: for backups, log and skip; for the cleaner, keep the file.
  - Move `_isDatabase` from `attachment_sync_service.dart:80` here.
- Tests:
  - `test/features/desktop/backup/data/services/backup_service_test.dart` (temp dir `:53`, prefs `:54`, memory DB `:57`, `_FakeFolderAccess` `:29`, foreign-key variants `:375-433`).
  - `test/features/desktop/backup/presentation/backup_bloc_test.dart` uses a bare `Fake` at `:13`; write a real fake.
  - `test/features/desktop/presentation/widgets/backup_card_dialogs_test.dart`, `backup_card_buttons_test.dart`.
  - Path fakes: `lww_sync_test_helpers.dart:119`, `records_test_helpers.dart:30`.

## Tasks & Acceptance

**Execution:**
- [ ] `lib/core/services/attachment_references.dart` and `test/core/services/attachment_references_test.dart` -- The API above, with tests for Windows, legacy, encoded, case-different and Media URLs, tombstones, and both unparseable modes.
- [ ] `backup_entry.dart` -- The new fields, with an old-JSON test. Then run build_runner.
- [ ] `backup_service.dart` and `backup_service_test.dart`:
  - Create with files, metadata written last, cleanup on failure, streamed hashes, paths derived from the meta location, Unicode names.
  - Restore with staging, the point-in-time rows, repointing that keeps the stamp, add-only files, a bad-file count, and `.restore-*` cleanup.
  - Delete the folder too, and auto-delete safety copies after 30 days.
  - Tests for each I/O row, including the default macOS folder and the stale `filePath` case.
- [ ] `lww_sync_bloc.dart` and a new `test/features/desktop/lww_sync/presentation/bloc/lww_sync_pause_test.dart` -- `pauseApplying()` and `resumeApplying()`. A batch received while paused is applied after resume; no `ok:false` is sent.
- [ ] `backup_bloc.dart` and `backup_bloc_test.dart` -- Sync first when the phone is connected (drain, digest, `tablesMatch`, 60 s timeout), pause received batches, safety backup, `localChanged()` after the restore instead of `resetPeerState`. If it fails, show the failure message and don't restore. `backup.error` on failure. Refuse phone requests while restoring. Log the empty catches.
- [ ] `backup_card.dart`, the ARBs, then gen-l10n -- The strings from Decisions. Update the widget tests.
- [ ] `test/features/desktop/backup/restore_sync_round_trip_test.dart` (new) -- Phone and desktop in memory:
  - After a restore and a sync, the phone matches the backup and newer rows are tombstones.
  - A phone clock that runs ahead doesn't win.
  - Backup tombstones survive a restart before the sync.
  - Notes with clashing ids are kept apart.
  - An offline phone's unsynced rows come back.
  - Restoring the safety copy brings everything back.
- [ ] `_bmad-output/planning-artifacts/architecture.md` -- Backup format v2, point-in-time restore (stamp `S`, no `resetPeerState`; update `:198`) and the safety copy rules.

**Acceptance Criteria:**
- Given a v2 backup of records with attachments, when every attachment file is deleted and the backup is restored, then every record opens its file on the desktop, and on the phone after sync.
- Given a backup made by the current release, when the new version restores it, then the rows return and no current file is removed.
- Given a v2 backup, when an older app version lists it, then it appears and restores rows only.

## Implementation Notes

- Choices that don't block the work and aren't settled by this spec may be decided during implementation; record each one here with its reason.
- Sync package (worktree `.claude/worktrees/agent-add831df0064503ce`, not yet applied to the branch): `LwwSyncBloc` (on `getIt<LwwSyncBloc>()`) gained:
  - `Future<bool> syncAndConfirmMatch({Duration timeout = 60s})`: drain, then a fresh digest, then wait for `tablesMatch`. It returns `false` at once when not connected or paused, on disconnect during the comparison, and on timeout. Each `false` is logged.
  - `pauseApplying()` and `resumeApplying()`, both idempotent. Held batches wait in `_onBatch` before `_applying` is set, and are never answered `ok:false`. `close()` resumes.
  - A new event, `LwwSyncEvent.matchCheckRequested()`.
  - 11 tests in `test/features/desktop/lww_sync/presentation/bloc/lww_sync_pause_test.dart`.
  - Decision: applying is paused only *after* the pre-sync, not during it. A paused desktop can't apply the phone's rows, so the tables would never match. The order for the backup bloc:
    1. `await syncAndConfirmMatch()`; on `false`, show `backupRestorePhoneOffline`.
    2. `pauseApplying()`.
    3. Safety backup, then restore.
    4. `add(LwwSyncEvent.localChanged())`.
    5. `resumeApplying()` in a `finally`. Without it, sync stays held until restart, because the pause has no safety timeout.

## Spec Change Log

## Review Triage Log

## Verification

**Commands:**
- `fvm dart run build_runner build` -- expected: succeeds
- `fvm flutter test test/features/desktop/backup test/features/desktop/presentation/widgets test/features/desktop/lww_sync test/core/services` -- expected: all pass
- `scripts/check.sh` -- expected: no issues

**Manual checks (if no CLI):**
- On macOS with a paired phone:
  1. Back up, then delete a record with a PDF on the phone, then restore. The record and its PDF return on both devices.
  2. Restore "Before restore …". The deletion is back.
