# Records audit

Audit of the records feature, for triage. Written 2026-10-29 against `develop` at `07cf3f78`.

**Scope.** `lib/features/records/` (data, domain, presentation), and the places records code reaches outside it: the `fhir_resource` and `record_notes` tables, the Fasten cache write, the LWW sync of notes and attachments, the processing step that saves DocumentReferences, the share mapper's record titles and `PdfPreviewService`. The problems already tracked in `mobile-stabilization.md` were left out; their current status is listed under [Known issues](#known-issues).

**Method.** Four independent code reviews (data layer and persistence; the Records screen, its BLoC and filters; a single record with its notes, attachments and media; turning FHIR into what the user reads), merged and de-duplicated. _Verified_ means the reviewer re-read the exact code; the 14 most serious findings were re-read again while compiling this document. _Traced_ means a reviewer followed the code path but the outcome depends on data or timing; _Device_ means it also needs checking on a phone. Reviewers confirmed `fhir_r4` parsing, SQLite foreign-key behaviour and two BLoC races with throwaway scripts outside the repo. Nothing was changed in the code.

## Summary

| Severity | Count |
| -------- | ----- |
| Critical | 1     |
| High     | 27    |
| Medium   | 32    |
| Low      | 10    |
| Test gap | 5     |

**What holds up.** The paginated list skips a record it can't parse instead of failing, and every `.first` on optional FHIR data is guarded. Field labels go through ARB (enforced by a test) and dates follow the app language. New attachments and processing PDFs store relative `file://` URLs, and `PathResolver` remaps old iOS container paths, so attachments survive a reinstall or restore. `AttachmentSyncService` only serves regular files inside Documents and never `db.sqlite`. The Fasten import is one batch. The `updated_at` triggers are correct for the tables Dart doesn't stamp itself, and migrations are hand-written SQL with snapshot tests. Read-only mode hides every edit action on received records; received notes stay in memory. IPS temp files are named safely, deleted and swept at startup. The page guards `context` after `await`.

**Where it breaks.**

1. **Values a patient, or a clinician they show, can misread.** The detail page converts any mg/dL lab with the glucose factor; stopped medications, refuted allergies and entered-in-error results look current; "<20" shows as "20"; dates move by a day across time zones (A1–A8).
2. **Another patient's records leak into the view.** Search, the Media filter, the Attachments view and IPS export each scope by patient differently, and several fall back to "every patient" (A10–A12, B9).
3. **Notes, attachments and files lose or outlive their records.** Notes overwrite each other across devices, records with the same FHIR id overwrite each other, deletes leave notes and files behind, a foreign key makes source deletion fail silently, and every phone copies its database into SharedPreferences (A13–A18).
4. **Fixed caps and in-memory filtering stand in for queries.** Blood type, a record's attachments, the Attachments view and search only look at the newest 100 to 2 000 rows, so records silently drop out as history grows (A19, A20, B6).
5. **The Records screen's state drifts from what it shows.** A search outlives its search box, the list jumps to the top every 20 records, the specialty filter never finishes loading, and sharing drops selected records (A25–A28).

## Proposed order

| Step | Issues                             | Why                                                                                                               |
| ---- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| 1    | A1–A8, then section 4 of the backlog | What the user reads. A1, A2 and A5 are small, local fixes; do them with the skipped `BUG:` display tests, which cover the same code |
| 2    | A10–A12, B9                        | Patient scoping: one rule for "this patient's records", used by list, search, Media, Attachments and IPS export |
| 3    | A13–A18                            | Data loss and leftovers. A13 and A14 change a synced table's key and need the desktop to ship the same change (backlog rule 4) |
| 4    | A19–A24, A9                        | Caps replaced by queries; attachment linking, preview and temp files                                              |
| 5    | A25–A28, then B and C              | Records screen state, with the first `RecordsBloc` and `AttachmentBrowseBloc` tests; then robustness, UX, leftovers |
| 6    | T1–T5, alongside each step         | A failing test first for each fix (backlog rule 1); test databases with foreign keys on                          |

## Status

Steps 1–4 are implemented on `feature/records-stabilization` (step 1 on `feature/records-display`, merged in), each fix with a test that failed before it, and not yet run on devices. `scripts/check.sh` passes except the two SSDP tests, which fail on any machine where another app holds UDP port 1900. Records coverage went from 15.2% to 43.8%.

| Issue      | Status                                                                                                                                                                                                                                                                                   |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1–A8      | Fixed, with the nine skipped display tests of backlog section 4 (now running)                                                                                                                                                                                                            |
| A9         | Fixed: a received record without a coded name names itself. The other four share-mapper skips (D7, versioned reference, shallow copy) stay skipped                                                                                                                                       |
| A10–A12    | Fixed. One rule (`PatientSourceUtils.recordsScope`) decides whose records Records shows; the page now also follows patient changes and reloads only when the source changes, which removes backlog B4's "reloads on every Home state change"                                             |
| A13        | Fixed with schema v12: notes sync on a `uuid` (existing notes get `legacy-<id>` on both ends). Phone and desktop both need this version for notes to sync; release them together                                                                                                         |
| A14        | Fixed without changing existing ids: only a resource whose id is taken by another source or type gets `sourceId/type/id`. Every Fasten sync downloads everything, so a record overwritten before the fix comes back on the next sync                                                     |
| A15        | Fixed: deleting a source, desktop Reset and notes on records without a source. Test databases now run with foreign keys on                                                                                                                                                              |
| A16        | Fixed for records and demo data. Removing a source from Home still leaves its attachment files (that path has no file access)                                                                                                                                                            |
| A17        | Fixed. Documents saved before the fix carry no session tag, so saving such an old session again adds new documents next to the old ones                                                                                                                                                 |
| A18        | Fixed: a device that never synced queues nothing; queued deltas carry no files and merge per table; the watcher listens to table updates. Still open (pinned as "KNOWN ISSUE"): an offline sync on a device that synced before moves the last sync time, and mobile clears the queue on start |
| A19–A21    | Fixed. A21 refuses the attachment, but the error isn't shown yet (B13)                                                                                                                                                                                                                   |
| A22        | Fixed; the race needs a device to confirm. The preview cache is now keyed by the attachments too (part of B27)                                                                                                                                                                           |
| A23, A24   | Fixed                                                                                                                                                                                                                                                                                    |
| A25–A28    | Fixed on `feature/mobile-stabilization-batch-2` with the rest of backlog B4, and their four `BUG:` tests run. The repository fills each page past the rows a date or specialty filter skips and counts its offset in stored rows (`getResourcePage`); a newer load drops an older one's result; loading more and refreshes keep the list on screen; leaving the search box clears its search; a new scope clears the selection, and Share reads the selected records from the database. A26 still needs a device. B16 (one reload per sync) is open |
| B9         | Fixed with A10–A12, including the emergency card                                                                                                                                                                                                                                         |
| T2–T4      | Done for the notes, attachments and records BLoCs, the entities and cards, and the sync and file paths changed here. T1 still lacks paging and IPS export tests; T5 (devices) is open                                                                                                   |

Also changed because the fixes needed it: desktop backup restore deleted parents before children (the A15 failure again) and could not restore a backup from an older schema; it now empties tables children first and copies only shared columns.

Found while fixing, not yet triaged:

- LOINC 882-1 ("ABO and Rh group"), common in EHR data, is not recognised as a blood type; only 883-9, 10331-7 and 34530-6 are.
- `records_page` groups and sorts by the local day of a UTC-midnight timestamp; `FhirFieldExtractor.recordDay` (step 1) gives the calendar day.
- `record_detail_page.dart:87` has an empty `catch`; `FhirObservationExtractor.extractInterpretation` is now unused.
- Tooling: the `rubocop` pre-commit environment doesn't build on Ruby 3.4.7 here (the `json` gem's native extension), and the `dart-format` hook fails inside a git worktree because `fvm` can't read its cache under pre-commit's `GIT_DIR`.

---

## A. Critical and high

| ID  | Issue                                                                                  | Area           | Severity | Confidence     | Decision |
| --- | -------------------------------------------------------------------------------------- | -------------- | -------- | -------------- | -------- |
| A1  | The detail page converts every mg/dL or mmol/L lab with the glucose factor             | Display        | Critical | Verified       |          |
| A2  | Medication status is never shown; stopped and cancelled medications look current       | Display        | High     | Verified       |          |
| A3  | Allergy cards hide refuted, inactive and entered-in-error status                       | Display        | High     | Verified       |          |
| A4  | Entered-in-error, not-done and refuted records are shown like any other                | Display        | High     | Verified       |          |
| A5  | `Quantity.comparator` is dropped: "<20" shows as "20.00"                               | Display        | High     | Verified       |          |
| A6  | Statuses, interpretation flags and BP components with only a code disappear            | Display        | High     | Verified       |          |
| A7  | Times are shown in UTC and dates move by a day west of UTC                             | Display        | High     | Verified       |          |
| A8  | A medication given as `medicationReference` is never named                             | Display        | High     | Verified       |          |
| A9  | Received allergies and other records are titled with the raw resource type             | Share mapper   | High     | Verified       |          |
| A10 | Search and the Media filter show other patients' records                               | Records screen | High     | Verified       |          |
| A11 | The Attachments view loads unscoped on first visit and never refreshes                 | Records screen | High     | Traced         |          |
| A12 | IPS export uses the source the Records page last saw, not Home's                       | Records screen | High     | Traced         |          |
| A13 | Notes sync on a per-device integer id, so they overwrite each other                     | Sync           | High     | Verified       |          |
| A14 | Records with the same FHIR id from different sources or types overwrite each other     | Data           | High     | Traced         |          |
| A15 | Deleting a source fails silently once it has a note; desktop Reset stops halfway       | Data           | High     | Verified       |          |
| A16 | Deleting a record leaves its notes, attached documents and files behind                | Data           | High     | Verified       |          |
| A17 | Saving a scan to an existing encounter deletes its earlier documents                   | Data           | High     | Traced         |          |
| A18 | Every phone queues full copies of its database, attachments included, in SharedPreferences | Sync       | High     | Traced, device |          |
| A19 | Blood type drops off the emergency card after 100 newer observations                   | Data           | High     | Verified       |          |
| A20 | A record shows no attachments once there are 100 newer DocumentReferences              | Record detail  | High     | Verified       |          |
| A21 | Attaching to an Immunization, Allergy, Claim or Coverage creates a patientless document | Record detail  | High     | Verified       |          |
| A22 | The attachment preview can show, and cache, another record's document                  | Record detail  | High     | Verified, device |        |
| A23 | Received non-PDF attachments open in external apps                                     | Record detail  | High     | Traced, device |          |
| A24 | Viewing a Media record writes health data to temp files that are never deleted         | Record detail  | High     | Verified       |          |
| A25 | A search outlives its search box and can show the previous patient's hits              | Records screen | High     | Verified       |          |
| A26 | Loading more records throws the list back to the top                                   | Records screen | High     | Verified, device |        |
| A27 | The specialty filter spins for ever, duplicates records, and from Home restores the type filter | Records screen | High | Verified       |          |
| A28 | Sharing drops selected records that aren't in the loaded page                          | Records screen | High     | Verified       |          |

### A1. The detail page converts every mg/dL or mmol/L lab with the glucose factor

- **Where:** `domain/utils/extractors/fhir_observation_extractor.dart:100-139` (`convertQuantityForRegion` looks only at the unit string), called from `observation.dart:429,448,487-504` through `record_detail_page.dart:83-86`. The default region is Europe (`user_bloc.dart:360,376`). The test at `fhir_observation_extractor_test.dart:238` locks the behaviour in.
- **What happens:** in the default region, cholesterol 200 mg/dL shows as "11.10 mmol/L" (correct: 5.17), calcium 9.5 mg/dL as "0.53 mmol/L" (reads as critically low), creatinine 1.0 mg/dL as "0.06 mmol/L". In the US region sodium 140 mmol/L shows as "2522.55 mg/dL". Any cm or in value becomes feet and inches: a 2.3 cm lesion shows `0'1"`. The reference range goes through the same conversion, so the result still looks plausible, and the card (unconverted, "200.00 mg/dL") disagrees with the detail page.
- **Fix:** convert glucose only for glucose LOINC codes and length only for body height (8302-2); show every other analyte as reported. Replace the test that locks the current behaviour.

### A2. Medication status is never shown; stopped and cancelled medications look current

- **Where:** `medication_request.dart:243`, `medication_statement.dart:133` read `status?.display?.valueString`; `fhir_r4`'s status enums never set `display` when parsed from JSON.
- **What happens:** `{"status":"stopped","medicationCodeableConcept":{"text":"Warfarin 5 mg"}}` has no status line on the detail page, and the card shows only the medication and dosage. A stopped anticoagulant looks like one the patient takes.
- **Fix:** read `status?.valueString`, map it to a localized label, put it on the card, and mark inactive statuses visibly.

### A3. Allergy cards hide refuted, inactive and entered-in-error status

- **Where:** `allergy_intolerance.dart:121-170` puts criticality, reactions, category and type first; clinical and verification status come after (`:179-200`). The card shows the first two lines (`resource_info_content.dart:38-41`).
- **What happens:** a refuted penicillin allergy with "Criticality: high · Reactions: Anaphylaxis" shows exactly those two lines; nothing says it was ruled out. The same holds for inactive and resolved allergies.
- **Fix:** put clinical and verification status on the first card line and mark inactive, refuted and entered-in-error allergies visibly.

### A4. Entered-in-error, not-done and refuted records are shown like any other

- **Where:** none of these codes appear anywhere under `lib/`. `immunization.dart:208` puts "Date given" on the card with status at `:260`; `procedure.dart` puts "Date performed" first with status at `:214`; Observation status sits under "Additional information" (`observation.dart:284`).
- **What happens:** a `not-done` MMR immunization with "Patient refused" shows "Vaccine: MMR · Date given: 2021-04-01". An entered-in-error Observation shows its value like any result.
- **Fix:** hide entered-in-error records from lists or strike them through; for not-done records, show the status and reason in place of the date.

### A5. `Quantity.comparator` is dropped: "<20" shows as "20.00"

- **Where:** `fhir_observation_extractor.dart:18-21,78-91`, `fhir_common_extractor.dart:74-82`; nothing under `lib/` reads `comparator`.
- **What happens:** an eGFR of ">60 mL/min/1.73m2" shows as "60.00", which reads as borderline kidney disease; an HIV viral load of "<20 copies/mL" shows as "20.00", which reads as detectable.
- **Fix:** prefix the value with `comparator` in every Quantity formatter, including the region path.

### A6. Statuses, interpretation flags and BP components with only a code disappear

- **Where:** `fhir_common_extractor.dart:8-33` returns null when a CodeableConcept has neither `text` nor `display`. Used for Condition and Allergy clinical and verification status (`condition.dart:121-145`, `allergy_intolerance.dart:180-200`), interpretation (`fhir_observation_extractor.dart:243-255`) and component labels (`observation.dart:151-167`, which skips a component without a label).
- **What happens:** `"clinicalStatus":{"coding":[{"code":"resolved"}]}` shows no status; `"interpretation":[{"coding":[{"code":"HH"}]}]` loses the critical-high flag; a BP panel whose components carry only LOINC 8480-6 and 8462-4 shows no values. Synthea and several EHRs send codes without a display.
- **Fix:** map the known status and interpretation code systems to localized labels, otherwise fall back to `coding.code`; name components from the vital codes.

### A7. Times are shown in UTC and dates move by a day west of UTC

- **Where:** `fhir_temporal_extractor.dart:236-238,251,265,279` (`DateTime.parse` without `.toLocal()`); the `date` column read back as local time and formatted in `record_type_header.dart:30` and every entity's date line; the same-day check in `extractPeriodFormatted` (`:77-83`) compares UTC fields.
- **What happens:** `"effectiveDateTime":"2023-07-14T21:30:00-04:00"` shows "Jul 15, 2023 1:30 AM". A sort date of `2024-03-05T00:00:00Z` shows in the list header as "March 4, 2024" for US users, so the list header and the detail page can disagree by a day in opposite directions.
- **Fix:** format times in local time consistently; keep date-only values as calendar dates that never pass through UTC.

### A8. A medication given as `medicationReference` is never named

- **Where:** `medication_request.dart:156`, `medication_statement.dart:125`, `medication_administration.dart:128`, `medication_dispense.dart:137` read only `medicationCodeableConcept`. The title fallbacks use `category` (`medication_request.dart:143`, a list, so always null). Contained resources are never resolved.
- **What happens:** `{"medicationReference":{"reference":"#m1","display":"Lisinopril 10 MG"}}` shows no medication and the card is titled "Medication Request".
- **Fix:** fall back to `medicationReference.display`, then the contained Medication's `code`; use the medication name for the title.

### A9. Received allergies and other records are titled with the raw resource type

- **Where:** `lib/features/share_records/data/mapper/fhir_bundle_mapper.dart:209-248` (the `default` branch returns `resourceType`, and `displayTitle` prefers a non-empty `title`); `_extractCodeableConceptTitle` ignores `text` when a coding has no display.
- **What happens:** a received penicillin allergy is titled "AllergyIntolerance"; MedicationStatement, Goal and Coverage likewise.
- **Fix:** return an empty title so the entity's own `displayTitle` applies, or carry the sender's title in the bundle.

### A10. Search and the Media filter show other patients' records

- **Where:** `records_bloc.dart:83-89` passes only `sourceId` to search, which is null under "All" sources; `searchResources` (`records_repository_impl.dart:686-700`, `fhir_resource_datasource.dart:143-170`) has no `sourceIds`. `records_bloc.dart:91-93` drops the source when the Media filter is on, and `sourceIds` is only used when `sourceId` is null.
- **What happens:** with two patients on the phone (family members, or the demo patient), searching "insulin" lists the other patient's medications; turning on the Media filter shows every patient's photos.
- **Fix:** add `sourceIds` to search; derive one scope (`sourceId` or `sourceIds`) per query in one place and never drop it for a type.

### A11. The Attachments view loads unscoped on first visit and never refreshes

- **Where:** `records_page.dart:104-116,360-433`; `records_bloc.dart:153-159`.
- **What happens:** the Attachments view is the default. On the first visit after launch, `RecordsInitialised` sets the default filters before `RecordsSourceChanged` runs; the filter listener fires with no source, so a second load covers every patient's encounters and reports. The listener ignores source changes, so the right scope never arrives; what the user sees depends on which load finishes last (`AttachmentBrowseBloc` has no transformer and does file I/O). The view also never reloads after a Fasten sync, a desktop sync, a deletion or a specialty change: a deleted record stays in the strip.
- **Fix:** drive the Attachments view from one listener on source and filters, after the source is set; send the same reload signal the list gets.

### A12. IPS export uses the source the Records page last saw, not Home's

- **Where:** `records_bloc.dart:370-373` reads `state.sourceId`, which only changes while the Records page is open; `fhir_resource_datasource.dart:20-24` lets `sourceId` win over `sourceIds`.
- **What happens:** the user visits Records on source S1, switches Home to another patient and exports. The export reads only S1: either the patient isn't found and the export fails silently (B1 in the backlog), or the PDF leaves out the patient's other sources.
- **Fix:** carry the scope from Home in `RecordsSharePressed`.

### A13. Notes sync on a per-device integer id, so they overwrite each other

- **Where:** `records/data/data_source/tables/record_notes.dart:6` (`autoIncrement`); `lww_sync_service.dart:186-226` (`ON CONFLICT(id) DO UPDATE` on every column; `_getIdColumn` is always `id`). Pinned as "KNOWN ISSUE" in `lww_sync_service_test.dart:572`, not in the backlog.
- **What happens:** between syncs the phone writes note 7 on a lab result and the desktop writes note 7 on a condition. The newer row replaces the other entirely, `resource_id` included: one note is lost on both devices and the survivor may move to another record. Both sides keep counting from their own maximum, so it recurs.
- **Fix:** give notes a UUID key and sync on it, migrating existing rows. This changes a synced row shape, so the desktop ships the same change.

### A14. Records with the same FHIR id from different sources or types overwrite each other

- **Where:** `sync_local_data_source.dart:35-60` (`id: e.resourceId ?? ''`, `InsertMode.insertOrReplace`); `fhir_resource_table.dart:21-22`. Attachments and processing use a second scheme, `${sourceId}_$resourceId` (`record_attachments_bloc.dart:382`, `document_reference_service.dart:181`).
- **What happens:** the primary key is the provider's bare id. Two sources returning `Patient/12345`, or one server whose `Encounter/100` and `Observation/100` share an id (common with numeric per-type ids), keep only the last row; the other record disappears and its notes show on the survivor. Every resource without an id collapses into one row with id `''`.
- **Fix:** one composite id (`sourceId/type/resourceId`) everywhere, with a migration. Synced key, so desktop too.

### A15. Deleting a source fails silently once it has a note; desktop Reset stops halfway

- **Where:** `record_notes.dart:8` (`source_id REFERENCES sources(id)`, no `ON DELETE`); `app_database.dart:341` (`PRAGMA foreign_keys = ON`); `sync_local_data_source.dart:274-284` via `home_bloc.dart:470`; `app_data_reset_service.dart:40-46`; `records_repository_impl.dart:507-512` (clear demo data). Test databases don't enable foreign keys, so no test sees it.
- **What happens:** a user adds any note, then removes that provider from Home: `DELETE FROM sources` fails, the bloc only logs, and the source and its records stay with no message. On desktop, Reset deletes `fhir_resource`, then `sources`, which throws; the single `try` skips `record_notes`, `processing_sessions` and `prefs.clear()`, so notes, sessions, the pairing and the Fasten token survive a reset and the app exits. Clearing demo data after noting a demo record leaves the demo source and shows an error. A note on a record whose `sourceId` is `''` can't be saved.
- **Fix:** delete notes before sources in one transaction (or `ON DELETE CASCADE` with a migration); give each reset step its own `try`; store null instead of `''`; turn foreign keys on in test databases.

### A16. Deleting a record leaves its notes, attached documents and files behind

- **Where:** `records_bloc.dart:466-480`; `fhir_resource_datasource.dart:107-128`; `records_repository_impl.dart:191-199`; `record_detail_page.dart:739-750`. Only the per-attachment delete in `record_attachments_bloc.dart:430-447` removes a file.
- **What happens:** the user deletes a condition with two notes and a scanned PDF after a "cannot be undone" dialog. The notes stay and keep syncing to the desktop; the DocumentReference still lists in the Attachments view; the PDF stays in Documents and in device backups. Deleting a DocumentReference record, a source or demo data leaves its files too.
- **Fix:** one repository method that, in a transaction, deletes the record, its notes and the DocumentReferences pointing at it, then deletes the files no other row references.

### A17. Saving a scan to an existing encounter deletes its earlier documents

- **Where:** `processing/presentation/bloc/handlers/processing_handler.dart:550-553`; `document_reference_service.dart:26-37` deletes every DocumentReference with the same wallet `sourceId` and `encounterId` (added in `973b2506` against duplicates on re-save).
- **What happens:** attaching a new scan to an encounter also deletes earlier scans and files attached by hand to it, which share the wallet source and encounter id. Their PDFs are orphaned; if PDF generation then fails, the encounter has no documents.
- **Fix:** store the ids a session created and delete only those, in the same transaction as the insert.

### A18. Every phone queues full copies of its database, attachments included, in SharedPreferences

- **Where:** `lib/main.dart:53` → `lww_sync_bloc.dart:107-110` (`startWatching()` whether or not a desktop is paired); `change_watcher_service.dart:33-100`; `offline_queue_service.dart:17-21,83-86`; `attachment_sync_service.dart:69-89`.
- **What happens:** the watcher fires at launch and 500 ms after every write, processing-session progress included. On a phone that never paired, the last sync time is empty, so each delta is every row of `fhir_resource`, `sources` and `record_notes` since 1970, with every attached file inlined as base64. With no connection it is appended to `lww_offline_queue`, re-encoding the whole queue each time, on the UI isolate. The prefs file (backed up on iOS and Android) holds another copy of the health records on every change; with a few hundred MB of scans this risks running out of memory at launch or during a scan. Clearing the queue at startup (`main.dart:28-30`) hides the size.
- **Fix:** watch only while a desktop is paired; keep a "dirty since" timestamp instead of queuing deltas; never put file bytes in prefs.

### A19. Blood type drops off the emergency card after 100 newer observations

- **Where:** `records_repository_impl.dart:525-566`; `wallet_pass/domain/service/emergency_card_builder.dart:57-59`; `patient_edit_service.dart:427-498`.
- **What happens:** blood type is looked for among the 100 newest Observations of all patients (the card passes no source). After a Fasten sync brings 100 lab results, or a family member's labs, the wallet pass and QR are built without a blood type, and editing blood type creates a second Observation. `orElse: () => patientList.first` returns the first patient's blood type when the id isn't found.
- **Fix:** query by LOINC code and subject in SQL with no limit; return nothing rather than another patient's value.

### A20. A record shows no attachments once there are 100 newer DocumentReferences

- **Where:** `record_attachments_bloc.dart:80-84` filters the 100 newest DocumentReferences (all patients) in memory.
- **What happens:** after a Fasten import with a few hundred clinical notes, every older encounter's attachment dialog says "No files attached", while the Attachments view still shows a thumbnail for it.
- **Fix:** a repository query by encounter or related reference in SQL, with an index (B5).

### A21. Attaching to an Immunization, Allergy, Claim or Coverage creates a patientless document

- **Where:** `record_attachments_bloc.dart:458-475` reads only `subject`; these types use `patient` or `beneficiary`. `:233-238,296-299`; `sync/domain/services/source_type_service.dart:48-73`.
- **What happens:** attaching a vaccination certificate to a Fasten immunization creates a DocumentReference with `subject: Patient/` and a nameless "Wallet - Patient " source among the sources. With a patient selected, the attachment falls outside that patient's views and exports.
- **Fix:** resolve the patient from `subject`, `patient` or `beneficiary`; refuse and say so if none is found.

### A22. The attachment preview can show, and cache, another record's document

- **Where:** `attachment_browse/attachment_detail_panel.dart:316-385` (`_buildPages` caches under `widget.detail.record.id` after its awaits and calls `setState` without checking the record is the same).
- **What happens:** the user swipes from record A (a 20-page PDF) to record B (one image). A's render finishes last, so B's panel shows A's document, tapping it opens A's DocumentReference, and the static cache keeps A's pages under B for the rest of the session.
- **Fix:** capture the record id before the first await; cache under it and skip `setState` when the panel has moved on.

### A23. Received non-PDF attachments open in external apps

- **Where:** `record_attachments_widget.dart:288-295` (the eye icon shows in read-only mode), `:209-235` (falls back to `OpenFile.open`); received files keep the sender's extension (`fhir_bundle_mapper.dart:196-203`).
- **What happens:** in a share session the receiver taps the eye icon on a `.docx`, `.txt` or `.heic` attachment; the file goes to Word, Files or a gallery app, which can save or forward it, outside screen protection and after the session ends.
- **Fix:** never call `OpenFile` in read-only mode; show unsupported types as not previewable.

### A24. Viewing a Media record writes health data to temp files that are never deleted

- **Where:** `lib/core/services/pdf_preview_service.dart:54-55,81-100` (`<title>_<ms>.pdf`); `media_fullscreen_viewer.dart:134-145` (`<title>.pdf`); neither matches `temp_file_sweeper.dart:89-98`.
- **What happens:** every "View document" on a Media record writes another decoded copy to temp (on Windows, `%TEMP%`). In a share session the received Media goes there too, outside the session folder, and survives the session.
- **Fix:** write into a folder the sweeper owns (or the session folder) and delete the file when the viewer closes.

### A25. A search outlives its search box and can show the previous patient's hits

- **Where:** `records_toolbar.dart:31-35,80-93` (search text lives in the widget; the query lives in the app-wide `RecordsBloc`); `records_bloc.dart:69-77,139-143` (`_isSearching` latch); `records_page.dart:94-97`.
- **What happens:** the user searches "aspirin", switches view or tab and comes back: the toolbar is empty and collapsed, the list still shows only aspirin results (or "No records found"), and there is no chip. Opening Records sends `RecordsInitialised` (starts a search on the old source, sets the latch) then `RecordsSourceChanged` (new source, but the load returns early because of the latch); a throwaway BLoC test ended with the new source and the old source's hits, so after a patient switch the page lists the previous patient's results.
- **Fix:** restore the toolbar from `state.searchQuery` or clear the search when the page closes; remove the latch and use `restartable()`.

### A26. Loading more records throws the list back to the top

- **Where:** `records_bloc.dart:79` (every load, load-more included, emits `loading`); `records_page.dart:675-682` replaces the list with a centred spinner when loading.
- **What happens:** the `ListView` is rebuilt and, with no `PageStorageKey`, starts at 0 again: every 20 records the user is back at the top, and the inline loader at `records_list_body.dart:146` never shows. Listener-driven reloads (B16) do the same.
- **Fix:** an `isLoadingMore` flag, or a full-screen spinner only while the list is empty.

### A27. The specialty filter spins for ever, duplicates records, and from Home restores the type filter

- **Where:** `records_bloc.dart:110-137,163,173` (`hasMorePages` from the unfiltered count; next offset from the filtered count); `records_page.dart:207`; `home_dashboard_sections.dart:236-243` with `records_bloc.dart:153-159,187-191`.
- **What happens:** extends known B4. If 3 of 20 rows match "Cardiology", the list can't scroll, load-more never fires and the bottom spinner stays. When it fires, the offset is 3, not 20, so rows are read again and matches appear twice (the date filter has the same offset bug). Tapping a specialty on Home empties the filters, and opening Records puts the Encounter and Diagnostic Report defaults back, so "Cardiology" shows only encounters and reports.
- **Fix:** count database rows separately from displayed rows, or better, filter specialty in the query; apply default filters only when the user hasn't chosen any.

### A28. Sharing drops selected records that aren't in the loaded page

- **Where:** `records_page.dart:587-596` maps selected ids through `RecordsBloc.resources`; `attachment_thumbnail_strip.dart:45-51`.
- **What happens:** the selection holds ids; the list holds 20 records per page. Selecting older records in the Attachments view (up to 1 000) shows "3 selected" and opens Share nearby with 0 or 1. The selection is app-wide and survives a reload, a filter change or a patient switch.
- **Fix:** load the selected ids from the repository; clear the selection on source or patient change.

---

## B. Medium

| ID  | Issue                                                                                           | Area           | Confidence     | Decision |
| --- | ----------------------------------------------------------------------------------------------- | -------------- | -------------- | -------- |
| B1  | Every Fasten sync wipes specialty overrides and re-stamps every row                              | Data           | Verified       |          |
| B2  | Received attachments are written again on every sync; old copies are never removed              | Sync           | Verified       |          |
| B3  | Attachment-URL repair can point a record at another record's file                               | Sync           | Traced         |          |
| B4  | `sources.updated_at` is stored in seconds; sync compares milliseconds                           | Sync           | Verified       |          |
| B5  | All database work runs on the UI isolate, without indexes for the common queries                | Data           | Verified       |          |
| B6  | The Attachments view, its detail panel and search silently cap at 1 000, 2 000, 500 and 100 rows | Data           | Verified       |          |
| B7  | Search matches raw JSON, limits before sorting, folds ASCII only and treats `%`/`_` as wildcards | Data           | Verified       |          |
| B8  | One unparseable resource breaks search, encounter view, IPS export, paging and the delete dialog | Data           | Traced         |          |
| B9  | An empty or unresolved patient scope means "every patient"                                      | Data, screen   | Traced         |          |
| B10 | Windows: database and attachments in the user's Documents; two code paths disagree on the folder | Data (desktop) | Verified       |          |
| B11 | No at-rest protection or backup policy for the database and attachments                         | Data           | Verified       |          |
| B12 | One-sided date filters match only that period; undated records pass every date filter           | Records screen | Verified       |          |
| B13 | List, attachment and note errors show as empty states or nothing                                | Screen, detail | Verified       |          |
| B14 | "View related" on a Fasten lab report finds nothing                                             | Records screen | Traced         |          |
| B15 | Every card rebuilds on every state change; all "View related" buttons spin together             | Records screen | Verified       |          |
| B16 | Sync events trigger repeated full reloads of the list                                           | Records screen | Verified       |          |
| B17 | Navigating to Records after attaching documents lands on Home                                   | Records screen | Traced         |          |
| B18 | Toolbar, chips and headers: no screen-reader labels, small targets, overflow with large text    | Records screen | Device         |          |
| B19 | Scrubbing the attachment timeline can show another record's details                             | Record detail  | Verified       |          |
| B20 | After a failed load, the next attachment is linked to an empty placeholder record               | Record detail  | Traced         |          |
| B21 | Typed note text is lost on rebuild; controllers leak; blank notes are saved                     | Record detail  | Verified       |          |
| B22 | Most provider documents and every Media image can't be viewed                                   | Record detail  | Verified       |          |
| B23 | Attaching reads the whole file into memory on the UI isolate to get its size                    | Record detail  | Device         |          |
| B24 | File-picker copies of attached files are never cleaned up                                       | Record detail  | Device         |          |
| B25 | Exporting an attachment does nothing on iPad                                                    | Record detail  | Device         |          |
| B26 | "Link to encounter" on a Media record writes invalid FHIR and asks for a raw id                 | Record detail  | Verified       |          |
| B27 | The preview cache keeps rendered PDF pages without limit and shows deleted documents            | Record detail  | Verified       |          |
| B28 | Many date fields show raw ISO strings                                                           | Display        | Verified       |          |
| B29 | Structured dosage loses frequency, as-needed and dose ranges                                    | Display        | Verified       |          |
| B30 | Allergy reaction severity is never shown; criticality, category and type are raw codes          | Display        | Verified       |          |
| B31 | English strings and English number formats reach es, de and ro                                  | Display        | Verified       |          |
| B32 | Unknown resource types (CarePlan, Appointment) show as "Resource" with no details               | Display        | Verified       |          |

- **B1.** `cacheFhirResources` uses `INSERT OR REPLACE` (`sync_local_data_source.dart:36-58`), which deletes and re-inserts each row with only the server columns: `specialty_override` set on a Fasten record and `device_id` go back to null on every sync (every sync downloads everything, backlog D2), and the insert trigger re-stamps every row, so the next desktop sync resends the whole table and the desktop's overrides lose. Fix: `ON CONFLICT(id) DO UPDATE` on the server-owned columns; skip unchanged rows.
- **B2.** `restoreAttachments` (`attachment_sync_service.dart:91-121`) writes each inline file under a fresh `<name>_<uuid8>` before the LWW check (`lww_sync_service.dart:78-80`), so losing rows orphan their file and winning rows orphan the previous one; every full resend (after any hard delete, or B1) adds another copy of every attachment. Fix: decide first; reuse a file with the same hash; delete the replaced file.
- **B3.** `fixBrokenAttachmentUrls` (`lww_sync_service.dart:408-477`, run at every mobile start and after every `fhir_resource` delta) repoints a missing file to the first file in Documents whose name contains the old stem, and `_updateAttachmentUrls` (`:359-406`) matches by basename. A missing `scan.pdf` can become another patient's `lab_scan_ab12cd34.pdf`. Files go missing in normal use through D5. Fix: exact relative paths or a stored hash only.
- **B4.** Drift stores `DateTime` as Unix seconds; the triggers and LWW use milliseconds. Source renames set `updatedAt: Value(DateTime.now())` (`sync_local_data_source.dart:87,205,238,263`), so they never match `updated_at >= sinceMs` and arrive on the other side as January 1970. Fix: let the trigger stamp `updated_at`.
- **B5.** `NativeDatabase(file)` (`app_database.dart:338`), not `createInBackground`; only `resource_type` and `resource_id` are indexed, and `_createOptimizationIndexes` creates none. Queries on `source_id`, `encounter_id`, `subject_id`, `date` and `record_notes.resource_id` scan the table, reading `resource_raw` overflow pages; the change watcher re-reads every row after every write. With thousands of resources, scanning, import and search freeze the UI. Fix: background isolate; indexes on `(source_id, date)`, `encounter_id`, `subject_id`, `record_notes(resource_id)`; watch `tableUpdates()`.
- **B6.** `repository_attachment_browse_service.dart:28-34` (1 000 records, before Patient and Organization are dropped), `:45-51` (2 000 DocumentReferences), `:204-207` (500, not patient-scoped); search returns at most 100 with no "more". Older years disappear from the timeline after "Clear all"; detail misses documents. All decoded on the UI isolate at once. Fix: page the view; resolve documents per record in SQL.
- **B7.** `fhir_resource_datasource.dart:159-218`: `LIMIT 100` before the title-first sort loses older title matches; matching raw JSON makes "patient", "final" or "code" hit every record; SQLite `lower()`/`LIKE` fold ASCII only, so "ärztlicher" misses "Ärztlicher"; `%` and `_` aren't escaped. Fix: FTS5 over title and display text (`unicode61`), or sort before limiting and escape.
- **B8.** `getResources` skips rows that `fhir_r4` rejects (`records_repository_impl.dart:59-76`) but logs only, so the record vanishes silently, and a short page sets `hasMorePages` false, ending the timeline. Search, encounter detail, IPS export and the delete dialog (`:93,127,304,699,727-729`) map without a guard, so one bad row (an Observation without `status`, an Immunization without `occurrence[x]`) fails the whole view. Fix: one tolerant mapper that falls back to a `GeneralResource` with title and date; compute paging from rows read.
- **B9.** `fhir_resource_datasource.dart:20-24` treats an empty `sourceIds` as no filter, so a patient whose sources resolve to none gets every patient's records in IPS export and the emergency card. `_resolvePatientSourceIds` (`records_page.dart:173-192`) returns null while patients are loading, when the patient has no group, or on error, and the page never listens for patients, so it stays on "all patients". Fix: empty means no results; "patient selected, sources unknown" means loading.
- **B10.** On Windows `getApplicationDocumentsDirectory` is `%USERPROFILE%\Documents` (often OneDrive-synced): `db.sqlite` and attachments land there unencrypted. `PathResolver` and `AttachmentSyncService` use `Documents\HealthWallet\Documents`, `LwwSyncService` the root (`:162,254,309,409`), so restored attachments look missing and B3 matches against the user's own documents. Fix: route every path through `PathResolver`; database under application support. Desktop; defer unless touched.
- **B11.** `AndroidManifest.xml:23-29` sets no `allowBackup` or `dataExtractionRules`, and nothing sets `NSURLIsExcludedFromBackupKey`: the plain database and every attachment go into Google and iCloud backups and device transfers (plus A18's copy in prefs). Needs a product decision: exclude, or document that backups carry the records; consider SQLCipher.
- **B12.** `date_filter.dart:34-41,131-142`: "From 2023" keeps only 2023, "Until Mar 2020" only March 2020, while the chip says "From"/"Until". Undated records pass every date filter (`records_repository_impl.dart:63-67`). Fix: open ranges for one-sided filters; exclude undated records while a date filter is active.
- **B13.** `RecordsStatus.failure` is neither logged nor rendered (`records_bloc.dart:140-141`), so a database error shows the "sync or import your records" placeholder; `AttachmentBrowseBloc` drops errors (`:99-100`); empty catches in `records_page.dart:190,297,318,773`. Notes and attachments widgets never render their error status: Attach on a DocumentReference flashes a spinner and does nothing (the localized `cannotAttachToDocumentReference` is never shown); a failed note save closes the editor and loses the text; a corrupt PDF shows "No attachments" while the panel says "file 1 of 1" and the document isn't closed (`attachment_detail_panel.dart:352`). Fix: error views with retry, snackbars, keep the editor open, close the PDF in `finally`.
- **B14.** `records_bloc.dart:237-245` finds a Diagnostic Report's related records by `encounter_id == report id`, which fits scanned reports but not Fasten reports that reference their results. Fix: fall back to `getRelatedResources(resource)`.
- **B15.** `resource_card.dart:104,163-166,447`: `_buildButtons` has no `buildWhen` and reads the shared `recordDetailStatus`, so opening related records on one card spins every card's button, and each selection tap or search keystroke rebuilds every card (each in an `IntrinsicHeight`). Fix: per-card related state keyed by id; `buildWhen`.
- **B16.** The sync listener (`records_page.dart:360-408`) has no `listenWhen`, so every sync state change reloads; the desktop-sync listener fires when rows arrive and again when the transfer finishes, for every table including `record_notes`. Each reload shows the spinner and resets the scroll (A26). Separate from the known reload on every Home change. Fix: reload once when a sync completes, for `fhir_resource` only.
- **B17.** `RecordsRoute` exists only as a dashboard child (`app_router.dart:36-43`), but `DashboardPage` is a `PageView` that ignores child routes; `document_handler.dart:181` calls `replaceAll([RecordsRoute()])` and the user lands on Home. Fix: navigate to the dashboard and select page 1.
- **B18.** Search, filter, the view toggle, chips and "clear all" are bare tap handlers with no semantics and 20–30 px targets (`records_toolbar.dart:99-147`, `records_view_toggle.dart:35`, `records_active_filters_bar.dart:85-143`); the toolbar's fixed 36 px height clips large text; `record_type_header.dart:25-35` overflows with a long German type and date on a 360 px phone. Fix: buttons with tooltips and 48 px targets; let the date wrap.
- **B19.** `AttachmentBrowseBloc` has no transformer (`:22-26`) and the scrubber sends a select for every item it passes (`attachment_timeline_scrubber.dart:157-185`); a dozen `loadDetail` calls race, so the strip highlights one record while the panel, notes and attach buttons belong to another. Fix: `restartable()`; drop results for an index no longer selected.
- **B20.** When loading a record's attachments fails (`record_attachments_bloc.dart:172-174`, e.g. one malformed related row at `:127-129`), `state.resource` stays the placeholder; the dialog still offers Attach, which creates a DocumentReference with `related: GeneralResource/` and `subject: Patient/`. Same path through `_EmptyAttachmentContent` (`attachment_detail_panel.dart:684-703`). Fix: carry the resource in the event; refuse to attach to the placeholder.
- **B21.** `record_notes_widget.dart:150-152` creates a `TextEditingController` in `build`: a resize, rotation, theme or locale change resets what the user is typing; controllers are never disposed (`:251-255`); whitespace-only notes are saved and Done on an empty field does nothing. Fix: one controller in `State`, disposed; trim and validate.
- **B22.** `pdf_preview_service.dart` ignores inline `data` ("No file path found"), returns Media `url`s with `file://` unresolved, writes all Media data as `.pdf` and decides type by extension; `media_fullscreen_viewer.dart:72-81` handles PDF only, and a `/` in the title breaks its temp path; the browse service shows no preview for `data` or `Binary/` URLs (`:385-399`). Fasten Media photos show "No PDF data available"; a HEIC opens in the PDF viewer and fails. Fix: one resolver for `file://`, relative, inline and `Binary/`, choosing the viewer by `contentType`.
- **B23.** `record_attachments_bloc.dart:281-282,324` reads the whole file to get its size; a large video can crash the app. Fix: `await file.length()`.
- **B24.** Nothing calls `FilePicker.clearTemporaryFiles()`; the picker's copy of every attached file stays in cache (`record_attachments_widget.dart:145`, `attachment_detail_panel.dart:674`). Fix: clear after copying.
- **B25.** `record_attachments_widget.dart:301-305` shares without `sharePositionOrigin`; on iPad that throws and no sheet appears. Fix: pass the icon's rect.
- **B26.** `media_fullscreen_viewer.dart:263-328` calls the DocumentReference linker with a Media id (`document_reference_service.dart:247-290`), writing `context.encounter` (DocumentReference-only) into the Media JSON, and asks the user to type an encounter id that isn't checked. Fix: remove, or set `Media.encounter` from a picker.
- **B27.** `attachment_detail_panel.dart:239` keeps a static map of every page rendered at 2×, never cleared; a cache hit (`:276-294`) isn't compared with the current attachments, so a deleted document keeps showing; long PDFs show a spinner until every page is rendered; received documents stay in it after the session. Fix: lazy pages, a small LRU keyed by attachment ids, cleared at session end.
- **B28.** Condition onset and abatement, Immunization occurrence and expiry, DiagnosticReport, MedicationStatement and MedicationAdministration effective dates, Allergy `lastOccurrence`, MedicationRequest validity and Practitioner `birthDate` use the unformatted extractors: "Onset: 2019-04-12T10:00:00-05:00", while Allergy onset is formatted. Fix: use the `*Formatted` extractors everywhere and delete the others.
- **B29.** `fhir_common_extractor.dart:142-178` reads only route, `timing.code` and `doseQuantity`: "Oral, 1 tablet" without "twice daily" or "as needed". `extractDosage` (`:180-212`) is dead and rounds 0.5 tablet to "1". Fix: render `timing.repeat`, `asNeeded[x]`, `doseRange`; delete `extractDosage`.
- **B30.** `allergy_intolerance.dart:121,145-163`: `reaction[].severity` is never read; criticality, category and type show as raw codes ("unable-to-assess", "medication") in every language. Fix: show severity; localize the code sets.
- **B31.** `displayTitle` falls back to `fhirType.display` ("Medication Request"); `GeneralResource` is "Resource"; Encounter "minutes"; vital and interpretation labels ("High", "Unknown") in `fhir_observation_extractor.dart:186,307-397`; raw codes for status, gender, `valueBoolean`; numbers use `toStringAsFixed`, never `NumberFormat`. German shows "Wert: 7.20 mmol/L", "Status: entered-in-error". Fix: `localizedName`, ARB maps for code sets, `NumberFormat.decimalPattern(locale)`.
- **B32.** `general_resource.dart:56` titles every unknown type "Resource" with no lines, and `toDto` writes `resourceType: ''`. A CarePlan "Diabetes self-management" shows as "Resource". Fix: use `title` when set; keep the type from the raw JSON.

---

## C. Low

| ID  | Issue                                                                                                                                                                                                                                                         | Area           | Decision |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------- |
| C1  | The reference range shows `range.text` as if it were the range type and repeats it as "Range notes"; only the first range is read, so sex- or age-specific ranges are ignored (`observation.dart:183,200,374,478,518,692`)                                       | Display        |          |
| C2  | Patient, Practitioner, Organization, RelatedPerson and PractitionerRole show "Inactive" when `active` is absent                                                                                                                                              | Display        |          |
| C3  | Names render as "Jane, Doe"; a name with only `text` falls back to "Practitioner" (`fhir_patient_extractor.dart:17-18`, pinned by a test)                                                                                                                      | Display        |          |
| C4  | Card and detail disagree: the related overlay prints `title` not `displayTitle` ("Condition: "); interpretation and status are both labelled "Status"; card and detail date formats differ; `additionalInfoForRegion` is a 300-line copy of `additionalInfo` | Display        |          |
| C5  | Changing a record's specialty refreshes the detail page's own bloc instead of the list (`record_detail_page.dart:462-467`)                                                                                                                                    | Record detail  |          |
| C6  | Filter sheet: Apply with an invalid range does nothing on the Filters tab; tapping a type badge or a Home category card silently clears the date filter                                                                                                      | Records screen |          |
| C7  | `debugPrint` in release logs attachment file names (e.g. `HIV_results.pdf`), record, source and subject ids (`record_attachments_bloc.dart:260-265`, `records_repository_impl.dart:433`, `attachment_detail_panel.dart:667`, `attachment_browse_bloc.dart:33`) | Data, detail   |          |
| C8  | No handler in `RecordsBloc`, `AttachmentBrowseBloc`, `RecordNotesBloc` or `RecordAttachmentsBloc` sets `transformer:`; IPS export can run twice with no progress state; a `RecordAttachmentsBloc` in `_EmptyAttachmentContent` is never closed; `setState` after `await` without `mounted`; `MediaFullscreenViewer` rebuilds its future in `build` | Presentation   |          |
| C9  | Dead or broken helpers: `getEncounterWithReferences` queries a missing `resource` column; `getPaginatedResourcesByType` orders by `updated_at`; unused count, type and related helpers; `LoadDemoData`, `ClearDemoData`, `RecordsSelectionCleared`, `initFilters`, `showAttachmentSuccessDialog`; `loadDemoData` inserts `unawaited` | Data, screen   |          |
| C10 | Conventions: raw `AlertDialog`/`ElevatedButton`/`TextButton`, `TextStyle(`, colour literals, numeric `EdgeInsets`, `Theme.of`; empty catches (9 in `repository_attachment_browse_service.dart`); the IPS share sheet anchored at (0,0,100,100) on iPad and macOS; the file-name sanitiser strips non-ASCII ("José" → "Jos") | All            |          |

## T. Test gaps

| ID  | Gap                                                                                                                                                                                                                                                     | Decision |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| T1  | `RecordsRepositoryImpl` and `FhirResourceDatasource` have no tests: paging, patient scoping, search, the blood-type lookup, IPS scope, notes CRUD. Test databases (including `app_data_reset_service_test.dart`) don't enable foreign keys, so A15 can't show. | |
| T2  | No BLoC tests for `RecordsBloc` beyond IPS export (paging, search, `RecordsInitialised`/`RecordsSourceChanged` ordering, specialty and date filters, deletion, selection), `AttachmentBrowseBloc`, `RecordNotesBloc` or `RecordAttachmentsBloc`.          |          |
| T3  | Entities: one test checks labels and that nothing throws; nothing checks values, statuses, line order or titles (A2–A4, A6, A8). No test for `ResourceInfoContent` or `resource_card.dart`; the region path's only test locks in A1; no test runs under a non-UTC time zone (A7). |          |
| T4  | Sync and files: the note id collision is pinned as "KNOWN ISSUE" only; nothing covers `ChangeWatcherService` on an unpaired phone (A18), `fixBrokenAttachmentUrls` matching (B3), `cacheFhirResources` replace behaviour (A14, B1), or file cleanup on delete (A16). |          |
| T5  | On a device: the scroll reset (A26), the preview race (A22), external opening of received files (A23), iPad export (B25), large attachments (B23), large text and screen readers (B18), and A18's prefs size after a scan.                                 |          |

## Known issues

Status of the backlog items (`mobile-stabilization.md`) the reviewers passed through:

| Backlog item                                          | Status                                                                                                                                         |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| D1 Fasten deletions stay                              | Still present (`sync_local_data_source.dart:182-194`)                                                                                         |
| D4 Received notes in `record_notes`                   | Fixed: served from `SharedNotesDatasource`                                                                                                     |
| D5 Same-name attachments overwrite                    | Still present (`record_attachments_bloc.dart:241-244`); deleting either one also deletes the shared file (`:435-446`), which feeds B3           |
| B1 IPS export failure not shown                       | Still present (`records_bloc.dart:403-405`); no progress state either (C8)                                                                     |
| B2 Empty catches                                      | Still present in this feature (C10)                                                                                                            |
| B3 Home counts capped at 20                           | Still present (`records_repository.dart:10`)                                                                                                   |
| B4 Records filters                                    | All five parts still present; A27 adds the endless spinner, duplicates and the reversed Home path, A10 the patient scope of search            |
| Hard deletes never set `deleted_at`                   | Still present for records, notes and attachments                                                                                               |
| LWW offline queue cleared on start                    | Still present; A18 explains why the queue grows so large                                                                                       |
| Section 4 display bugs pinned by skipped `BUG:` tests | All 9 still skipped                                                                                                                            |
