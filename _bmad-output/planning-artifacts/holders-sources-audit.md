# Wallet holders and sources audit

Audit of how the app decides who the people in the wallet are and which sources hold their records, for triage. Written 2026-11-02 against `develop` at `b079f4f5`.

**Scope.** Patient grouping and selection (`lib/features/user/domain/services/`, `PatientBloc`, the patient section of Preferences), the sources and their table (`lib/features/sync/` sources, `SourceTypeService`, `WalletPatientService`, `DefaultPatientService`), every path that brings a patient or a source in (Fasten sync, document scan and attach, demo data, set-up wallet, received shares, the mobile ↔ desktop sync of `sources`), and every screen that asks "whose records?" (Home, Records, wallet pass, IPS export). The problems already tracked in `mobile-stabilization.md` (D1, D3, B3) and `records-audit.md` (A10–A12, fixed) are not repeated; see "Known issues".

**Method.** One review of the core (grouping, selection, edit, Home's source handling) and three independent reviews (the scan and attach path; provider sync, onboarding, demo, shares and the desktop sync of sources; the screens and services that read the selected patient), merged and de-duplicated. _Verified_ means the exact code was re-read; _Traced_ means the flow was followed without confirming every step. A throwaway test against the real `PatientDeduplicationService` confirmed A1, A2, A3 and A4. The desktop runs the same `HomePage` (through `DashboardPage`) and `PatientBloc`, so everything here applies to both ends. Nothing was changed in the code.

## Summary

| Severity | Count |
| -------- | ----- |
| High     | 14    |
| Medium   | 13    |
| Low      | 4     |
| Test gap | 4     |

**What holds up.** New-patient scans are consistent: the Patient row, its `wallet-<uuid>` source and the records' `subject` all use the same id. A plain "link existing" scan never writes a provider or demo row. Deleting a source is one transaction that tombstones its records and notes, stamped in milliseconds so the delete reaches the desktop; re-creating a source clears its tombstone. `_rowIds` keeps records of different sources from replacing each other. Deterministic ids (`default_patient`, the demo ids) merge into one row across devices instead of duplicating. `recordsScope` shows nothing while patients load, so another patient's records never flash on Records. The LWW sync ignores unknown tables, drops unknown columns and updates only the columns the peer sent, so a new column on `sources` is safe with an older peer.

**Where it breaks.**

1. **Who is who is never stored.** Which Patient rows are the same person, and which sources belong to them, is worked out again on every load: by an exact match of all identifiers, a substring match on `subject.reference` over up to 10 000 records per Patient row, and the naming rule `wallet-<id>`. The guesses split one person into several (the default holder and the first sync, two providers, a corrected identifier) and leak or hide sources (A1–A4).
2. **"The current holder" has three owners.** `PatientBloc`, the `selected_patient_id` preference (written by three classes) and HomeBloc's selected source disagree, and Home, Records, the pass and IPS export each compute a different scope from them (A5, A6, B1, B2).
3. **Writes land on the wrong row.** A scan linked to an existing patient overwrites that patient, in a provider's source if that is where the row lives; attaching without AI files under the selected patient instead of the chosen one; blood type goes into the provider's source; wallet sources are named three ways (A7–A11).
4. **Sources can't be managed.** Renaming does nothing, every provider source is called "Fasten" and loses its user label and tombstone on each fetch, and any source can be deleted, a holder's own wallet source included (A12–A14).

## Agreed direction

Decided with the product owner on 2026-11-02:

- **Provider-agnostic.** Fasten is being phased out and other provider integrations will follow; one person can have several provider sources. Code asks only "wallet or provider?"; the integration's name stays in `platformName`. Stored `platform_type` values are kept as they are.
- **A stored holder, synced.** One nullable `holder_id` column on `sources` (schema v14), no new table. A holder is the set of sources sharing a `holder_id`. Each holder has exactly one wallet source and one wallet Patient, created with the holder (copied from the first provider patient when there is one). Order and the current selection stay per device. `sources` already syncs, and the desktop shows the same Home, so the links must reach it; an older peer drops the column and a source arriving without `holder_id` is linked on arrival.
- **One intake.** Every path that brings a patient (each provider integration's sync, a scan, demo data, a received share, a source from the desktop) goes through one linker that finds or asks for the holder and stores the link. Matching: national identifiers (SSN, CNP and the like) when present, otherwise name and birth date, MRN only within the same system. With a single holder in the wallet, a new patient attaches to it; when unsure, the app asks "you or someone else?". A provider source carries exactly one patient: an integration that returns several in one connection splits them into one source each.
- **Writes.** The holder's wallet Patient is the only editable row; provider rows are never written. A scan fills only empty fields of the wallet Patient and files its records in the holder's wallet source, with `subject` pointing at the wallet Patient. "New person" in a scan creates a holder.
- **Out of scope:** merging or splitting holders by hand, adding or deleting holders. The source filter on Home stays.

## Proposed order

| Step | Issues                               | Why                                                                                                                                                                                                                                                 |
| ---- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | T3, groundwork                       | Schema v14 (`holder_id TEXT NULL` on `sources`), migration test, and a one-off start-up backfill that links existing sources from today's grouping, logged. The last time the guessing code runs. Phone and desktop ship it together (backlog rule 4) |
| 2    | A1–A4, A10, B6, B8                   | The linker: one intake, the matching rules, the "you or someone else?" prompt, `wallet-<holderId>` for new wallet sources (existing ids stay; they are synced keys). Replaces `deduplicatePatients`, `enhancePatientGroupsWithSubjectId` and `WalletPatientService` |
| 3    | A5, A6, B1, B2, B7, C1               | One selection: a repository-backed stream of the selected holder and optional source filter that Home, Records, the pass, IPS export and attach read. Removes `PatientSourceUtils`, the direct preference writes and the fixed waits                 |
| 4    | A7–A9, A11                           | Writes go to the holder's wallet Patient and wallet source; the scan fills empty fields only; attach uses the chosen holder                                                                                                                         |
| 5    | A12–A14, B9–B11                      | Sources: rename, a delete rule, labels built at display time, provider labels from the integration, a source upsert that keeps the user's label and tombstone                                                                                       |
| 6    | B3–B5, B12, B13, C2–C4               | Onboarding and demo flows, silent failures, caps, widget logic, dead code                                                                                                                                                                           |
| 7    | T1–T4, alongside each step           | A failing test first for each fix (backlog rule 1); tests for the linker, selection and edit services and the patient paths of `PatientBloc` and `HomeBloc`                                                                                         |

## Status

On branch `feature/holders-and-sources` from `develop` at `b079f4f5`. Nothing has run on a device yet.

| Step | Status |
| ---- | ------ |
| 1    | Done. Schema v14 adds `sources.holder_id`; `cacheSources` keeps a source's holder when a provider fetch rewrites it. The start-up pass uses the new matching rules rather than today's grouping, so existing installs get A1 and A2 fixed too |
| 2    | Done. A1–A4, A10, B6 and B8 fixed; B7 fixed with it (the attach dialog preselects the matched person). A holder's wallet source is made the first time something is written for them, not with the holder; the wallet Patient follows in step 4. With one holder and two newcomers at once, both are asked about rather than joined |
| 3    | Done. A5, A6, B1 and B2 fixed (B7 was in step 2). HomeBloc and PatientBloc handlers set transformers; the 500 ms wait after a sync and the 300 and 200 ms waits of the demo flow are gone (the onboarding flows themselves are step 6). The patient card shows the person's own row whatever the source filter |
| 4    | Done. A7–A9 and A11 fixed. A scan linked to a person writes their wallet Patient (made as a copy of their row when they have none), and its records refer to that row; scanned details fill only empty fields, and are kept only when the review form carries them or the match is the unnamed default holder. Picking another person in the attach dialog drops the scanned details, as it says. Found on the way: a scanned patient without a gender failed to save (`AdministrativeGender('')`); fixed |
| 5–7  | Not started |

---

## A. High

| ID  | Issue                                                                                          | Area      | Severity | Confidence | Decision |
| --- | ---------------------------------------------------------------------------------------------- | --------- | -------- | ---------- | -------- |
| A1  | The default "Health Wallet Holder" never merges with the user's real patient                   | Grouping  | High     | Verified   |          |
| A2  | Patients group only when all their identifiers match                                           | Grouping  | High     | Verified   |          |
| A3  | A holder's sources are found by a substring match on `subject.reference`                       | Grouping  | High     | Verified   |          |
| A4  | `patientGroups` has an extra, narrower group for every non-representative Patient row          | Grouping  | High     | Verified   |          |
| A5  | Home uses a one-source scope on most reloads, and two reloads race on every patient change     | Selection | High     | Verified   |          |
| A6  | The wallet pass and IPS export read one source of the holder                                   | Selection | High     | Verified   |          |
| A7  | Choosing an existing patient in a scan overwrites that patient with the scan's details          | Scan      | High     | Verified   |          |
| A8  | Editing a matched patient in the review form rebuilds it from four fields                      | Scan      | High     | Verified   |          |
| A9  | Attaching without AI files documents under the selected patient, not the chosen one             | Scan      | High     | Verified   |          |
| A10 | Wallet source ids are formed three ways                                                        | Sources   | High     | Verified   |          |
| A11 | A blood type saved for a provider-only holder goes into the provider's source                  | Edit      | High     | Traced     |          |
| A12 | Renaming a source does nothing                                                                 | Sources   | High     | Verified   |          |
| A13 | Each provider fetch rewrites the source rows: every one is "Fasten", user labels and deletes are lost | Sources | High   | Verified   |          |
| A14 | Any source can be deleted, including a holder's own wallet source                              | Sources   | High     | Verified   |          |

### A1. The default "Health Wallet Holder" never merges with the user's real patient

- **Where:** `default_patient_service.dart:27-96` gives the default patient the identifier value `default_patient`; `SyncBloc._onSyncData` creates it before the first Fasten fetch (`sync_bloc.dart:108`), and `_onLoadDemoData` creates it before the demo data (`:241`). Nothing removes or merges it.
- **What happens:** after the first sync the user has two people, "Health Wallet Holder" and themselves; a failed sync still leaves the default one. Loading demo data also gives two. This is backlog D3, now confirmed: the probe groups the two into two people.
- **Fix:** the linker attaches the first provider patient to the only holder (step 2); the default holder's wallet Patient takes the provider's details where its own are empty.

### A2. Patients group only when all their identifiers match

- **Where:** `patient_deduplication_service.dart:92-112` joins every identifier, sorted, into one key.
- **What happens:** the same person at two hospitals, each with its own MRN and the same SSN, are two people (probe). Correcting the identifier of a provider patient creates a wallet copy whose identifiers differ (`patient_edit_service.dart:222`, `:349`; the replaced identifier gets the phone's country system), so the edited person splits from the provider row.
- **Fix:** the linker's matching rules (national identifier, then name and birth date, MRN only within a system), run once and stored (step 2).

### A3. A holder's sources are found by a substring match on `subject.reference`

- **Where:** `patient_deduplication_service.dart:214-259` loads up to 10 000 records per Patient row and keeps those whose reference `contains(patientId)`.
- **What happens:** patient `12` gets the sources of `Patient/123` (probe), so another person's provider shows in the source list and in Records' "All". Types linked by `patient` or `beneficiary` (AllergyIntolerance, Immunization, Coverage) are never matched.
- **Fix:** sources belong to a holder by `holder_id` (steps 1–2).

### A4. `patientGroups` has an extra, narrower group for every non-representative Patient row

- **Where:** `enhancePatientGroupsWithSubjectId` (`patient_deduplication_service.dart:172-212`) adds a one-row group under each Patient row id that isn't already a key, and adds subject matches only to each row's own group.
- **What happens:** a wallet row and a provider row of the same person give `{w: [wallet-w, src-f], f: [src-f]}` (probe). When the selected id is the provider row (after a scan, B1), Records, Home and the source list show only that provider, no card is expanded, and editing falls back to the first patient.
- **Fix:** removed with the grouping (step 2).

### A5. Home uses a one-source scope on most reloads, and two reloads race on every patient change

- **Where:** `getPatientSourceIds` (`home_data_handler.dart:29-75`) returns only the selected row's own source; `HomeRefreshPreservingOrder`, `HomeScanCompleted`, `HomeInitialised`, `HomeRecordsFiltersChanged` and `HomeSourceDeleted` pass no scope and get it. `home_page.dart:75-76` sends `HomeSourceChanged` (the group's sources) and `HomeRefreshPreservingOrder` (one source) together; HomeBloc has no `transformer:`, so the last to finish wins.
- **What happens:** a holder with a wallet row and a Fasten row: after any sync, desktop change, region change or scan, Home in "All" drops the Fasten counts and vitals while Records still lists them. Switching patients with a provider filter on can show the previous patient's provider under the label "All" (traced).
- **Fix:** one selection that Home reads (step 3).

### A6. The wallet pass and IPS export read one source of the holder

- **Where:** `emergency_card_builder.dart:50-55` and `records_repository_impl.dart:891-900` take the sources of the rows whose `id` equals the selected patient: one row, one source. In "All", `HomeState.patient` is the wallet copy (`patient_selection_service.dart:30-36`).
- **What happens:** the pass and the IPS PDF leave out the provider's allergies, conditions and medications. With a provider filter on, the pass is built from the provider row with serial `emergency_<provider id>` (`apple_pass_builder.dart:37`), so one person can have two passes in Wallet.
- **Fix:** both read the holder's sources (step 3). The pass serial stays on the holder's wallet Patient id, so passes already in Wallet keep updating.

### A7. Choosing an existing patient in a scan overwrites that patient with the scan's details

- **Where:** `processing_handler.dart:610-620` saves `draft.copyWith(id: existingPatient.id)` into `existingPatient.sourceId`. `AttachToEncounterPatientChanged` keeps the draft (`attach_to_encounter_bloc.dart:121-128`) after `patient_selector.dart:106-121` tells the user their changes will be discarded; `_swapPatient(linkExisting)` does the same (`resources_form.dart:666-680`).
- **What happens:** a scan of a family member's letter, assigned to the user, replaces the user's name, birth date, gender and identifier with the letter's. When the chosen patient came from Fasten or the demo, the write goes into that source: Fasten undoes it on the next sync (traced), the demo removes it with the demo data.
- **Fix:** the scan writes only the holder's wallet Patient, filling empty fields (step 4).

### A8. Editing a matched patient in the review form rebuilds it from four fields

- **Where:** `MappingPatient.fromFhirResource` (`mapping_patient.dart:60-90`) keeps name, birth date, gender and one identifier, and uses `extractPatientBirthDate(patient) ?? DateTime.now()`; `session_handler.dart:385-391` turns any edit into a draft that A7 then saves.
- **What happens:** address, telecom, emergency contact, extensions and other identifiers are lost. A patient with no birth date, such as the default holder, gets today's date. The identifier system is recomputed from the phone's region, which feeds A2.
- **Fix:** with A7 (step 4).

### A9. Attaching without AI files documents under the selected patient, not the chosen one

- **Where:** `document_handler.dart:79-98` and `:141-158` take the patient from `PatientBloc.selectedPatientId`, not from the dialog's `patient.existing`; with no patient they use `patient-default` (`:87`, `:149`). A new encounter's subject is `existingPatient.subjectId` (`:102`), which is empty for scanned and Fasten rows; its save is `unawaited` (`:105`).
- **What happens:** with A selected, picking B's encounter files the documents in `wallet-A` against `Patient/A`. A new encounter gets `subject: Patient/`. With no patient, a `wallet-patient-default` source appears with no Patient. A failed save is lost.
- **Fix:** attach takes the chosen holder (step 4); the logic moves out of the widget helper into the bloc.

### A10. Wallet source ids are formed three ways

- **Where:** scan and attach use `wallet-<Patient.id>` (`processing_handler.dart:602-605`, `document_handler.dart:89-95`); edit uses `wallet-<resourceId>` (`patient_edit_service.dart:160-161`) and gives the wallet copy the row id `wallet-<resourceId>_<uuid>` (`:210-211`).
- **What happens:** a scan linked to that wallet copy (which `findMatchingPatient` prefers) creates `wallet-wallet-<resourceId>_<uuid>`, a second wallet source for one person. A provider row with a composite id (`src/Patient/x`, from records audit A14) gives `wallet-src/Patient/x` and the subject `Patient/src/Patient/x`, which matches nothing. The default holder works only because both sides use `.id`.
- **Fix:** one wallet source per holder, `wallet-<holderId>` (step 2).

### A11. A blood type saved for a provider-only holder goes into the provider's source

- **Where:** `PatientBloc._onEditSaved` calls `updateBloodTypeObservation(currentPatient, …)` (`patient_bloc.dart:407`) with the provider row after `savePatientEdits` made a wallet copy; `patient_edit_service.dart:492` creates the Observation in `patient.sourceId`.
- **What happens:** the Observation lands in the read-only provider source against the provider row. The card then shows the new wallet copy (wallet preferred in "All"), which matches no observation, so the card and the pass show N/A right after the user saved a blood type.
- **Fix:** blood type is written to the holder's wallet source and Patient (step 4).

### A12. Renaming a source does nothing

- **Where:** `source_selector_widget.dart:245-246` ignores `newLabel` and calls `onSourceLabelEdit!(source)`; `home_dashboard_sections.dart:159-162` then sends `HomeSourceLabelUpdated(source.id, source.labelSource ?? '')`, the old label.
- **What happens:** the user renames "Fasten" to "City Hospital"; the dialog closes and the name stays.
- **Fix:** pass the new label (step 5).

### A13. Each provider fetch rewrites the source rows: every one is "Fasten", user labels and deletes are lost

- **Where:** `source_mapper.dart:14-18` sets `labelSource` to the platform name (default "Fasten") and drops the DTO's label and display; `cacheSources` writes with `insertOrReplace` (`sync_local_data_source.dart:125-142`) on every `getSources()` that reaches the backend (`sync_repository_impl.dart:63-94`).
- **What happens:** two hospitals show as two "Fasten" entries. A label the user set is overwritten, and a deleted provider source loses its tombstone and comes back with its records; each rewrite stamps a new `updated_at` that goes to the desktop.
- **Fix:** an upsert that keeps `label_source` and `deleted_at`; provider labels from the integration (step 5). Disconnecting a provider is a product decision (backlog section 8).

### A14. Any source can be deleted, including a holder's own wallet source

- **Where:** `source_list_dialog.dart:255` shows the trash icon for every source except "All"; `SourceTypeService.canDeleteSource` is never called. `softDeleteSource` tombstones every row of the source.
- **What happens:** deleting a holder's wallet source deletes their own Patient row, their scans and notes; the holder disappears or falls back to a provider row. Deleting `demo_data` from this list skips the demo cleanup, leaving `demo_medical_report.pdf` on disk.
- **Fix:** a delete rule used by the dialog: the holder's wallet source can't be deleted, demo data goes through its own removal (step 5).

## B. Medium

| ID  | Issue                                                                                                                                                                                                                                                                    | Area       | Confidence | Decision |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------- | ---------- | -------- |
| B1  | The selection has three owners. A scan writes `selected_patient_id` directly before the rest of its records are saved (`processing_handler.dart:508`); `_loadPatients` keeps a saved id only if it is a representative and otherwise picks the first patient (`patient_bloc.dart:177-211`); HomeBloc reads the key concurrently (`home_bloc.dart:358`). The scanned patient is not reliably selected | Selection  | Traced     |          |
| B2  | The patient card shows the row for Home's selected source (`unified_patient_card.dart:108-114`), the edit dialog the group's representative (`patient_card_details.dart:136-141`), so the dialog can show other details than the card                                     | Selection  | Verified   |          |
| B3  | "Set up wallet" assumes the default patient was created: `createAndSetAsMain` returns early when any Patient exists, but the placeholder still filters Home to `wallet-default_patient` and waits 3 s for a wallet patient (`sync_placeholder_widget.dart:450-529`)      | Onboarding | Verified   |          |
| B4  | The demo dialog can hang with no way out (`canPop: false`): it advances only on `hasDemoData && !hasSyncedData` (`:597`), so a failed load, a Fasten sync earlier in the session, or loading demo data a second time (`hasDemoData` never resets) leave it open        | Onboarding | Traced     |          |
| B5  | Demo records are written `unawaited` (`records_repository_impl.dart:567`, `:634`): `loadDemoData` returns before the rows exist, and a failed write never reaches the bloc                                                                                              | Demo       | Verified   |          |
| B6  | Scan matching is loose and uneven: `findMatchingPatient` compares identifier values without the system or a minimum length and matches on name alone when the stored patient has no birth date (`patient_deduplication_service.dart:279-365`); the OCR pre-match takes any 5-digit run in the text (`processing_handler.dart:304-315`); processing reads 1 000 raw rows, the attach dialog and `PatientBloc` 100 grouped ones | Scan       | Traced     |          |
| B7  | The attach dialog preselects `uniquePatients.first` when the matched patient is not a representative or is past row 100 (`attach_to_encounter_bloc.dart:63-66`), and Save keeps it                                                                                      | Scan       | Verified   |          |
| B8  | Scans matched to the demo patient go to `wallet-<demo id>`; removing the demo data deletes only `demo_data` (`records_repository_impl.dart:711-722`), leaving them with a subject that points at a deleted Patient                                                       | Demo       | Traced     |          |
| B9  | Source labels store English and the patient's name (`'Wallet - $patientName'`, `'Patient $patientId'`), sync them, and never update them when the holder is renamed; record attachments pass no name and create "Wallet - Patient &lt;uuid&gt;" (`record_attachments_bloc.dart:558`) | Sources    | Verified   |          |
| B10 | The legacy `wallet` migration (`app_database.dart:111-140`): with no Patient in `wallet` it deletes the source but leaves its records, which then come back as a read-only "fasten" source (`_getSourcePlatformType`); with several patients every record moves to the first one | Database   | Verified   |          |
| B11 | Fasten is assumed outside `ehrs/fasten/`: the `'fasten'` fallback in `_getSourcePlatformType` and `SourceTypeService`, Fasten's JSON keys in `FhirResourceDto` (also used by demo data and the default patient), Fasten's response envelope in `sync_remote_data_source.dart`, `SyncQrData` in `SyncRepository` and `SyncBloc`, single-provider preference keys (`sync_token`, `lastSyncTimestamp`), and generic source CRUD inside the Fasten repository binding | Sources    | Verified   |          |
| B12 | Silent failures: `createAndSetAsMain` catches and only logs, so its callers' error handling never runs (`default_patient_service.dart:131`); `SyncRepositoryImpl.getSources` swallows errors (`:98-100`); `SourceRemoteDataSource.getSources` returns `[]` on any error; `id_card_scan_mixin.dart:58,68,87` use `catch (_)` without logging | Errors     | Verified   |          |
| B13 | Each patient load parses up to 10 000 records per Patient row and calls `getSources()` (a network fetch and a source rewrite, A13) per row; it runs at start, on opening Preferences, after sync, scan, edit and source delete, and twice after a record delete (`app.dart:188`, `records_page.dart:389`). Only 100 Patient rows are read | Performance | Verified  |          |

## C. Low

| ID  | Issue                                                                                                                                                                                                                                                                   | Area     | Decision |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------- |
| C1  | Fixed waits stand in for state: 300, 200 and 350 ms in the demo flow, 500 ms after a sync (`app.dart:271-280`), about 3 s of `Future.delayed` animation in `_onPatientReorder`. No handler of `HomeBloc` (17) or `PatientBloc` (8) sets `transformer:`                     | Blocs    |          |
| C2  | Business logic in widgets: `UnifiedPatientCard._loadBloodType` calls `RecordsRepository` and checks `status.toString().contains('Success')`; `SourceSelectorWidget._getPatientSources` filters sources (and lists everyone's when groups are empty); the demo selection in `sync_placeholder_widget.dart`; the source delete handler in `home_dashboard_sections.dart:164-189`; `document_handler.dart` (A9) | Layers   |          |
| C3  | Dead code: `WalletPatientService.createWalletSourcesForAllFastenPatients` (assumes a `fasten-` prefix Fasten doesn't use), `getWalletSourcesForPatient`, `hasWalletSourceForPatient`, `getPrimaryWalletSourceForPatient`; `shouldCreateDefaultWalletHolder`; `SourceTypeService.getSourceType`, `canEditSource` (true on both branches), `canAddDataToSource`; `createWalletSource` and the `CreateWalletSource` event; `getSources({patientId})` (compares a source id to a patient id); `PatientDataUpdatedFromSync`; `PatientState.allPatientsAcrossSources`; `PatientEditSaved.sourceId`; `HomeSourceDeleted.patientSourceIds`; the identical branches at `home_bloc.dart:479-483`; `PatientDeduplicationService.hasMultipleSources` | Cleanup  |          |
| C4  | The source list strips the "Wallet - " prefix (`source_list_dialog.dart:332`), the single-source chip doesn't (`source_selector_widget.dart:126-135`)                                                                                                                    | Display  |          |

## T. Test gaps

| ID  | Gap                                                                                                                                                                                                                                         | Decision |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| T1  | No tests for `PatientDeduplicationService`, `PatientSelectionService`, `PatientEditService`, `DefaultPatientService`, `SourceTypeService` or `WalletPatientService` (the "Patient services" critical area, 16.4%)                               |          |
| T2  | No tests for `PatientBloc`, the patient and source paths of `HomeBloc`, the patient resolution in `processing_handler.dart` (`_persistPrimaryResources`) or `AttachToEncounterBloc`                                                            |          |
| T3  | The v14 migration, the backfill (one person with wallet and provider rows, two people, the default holder, the legacy `wallet` source) and an LWW round trip of `holder_id` with a peer that lacks the column                                |          |
| T4  | On devices: a first Fasten sync after "Set up wallet", a phone and a desktop on different app versions, a scan linked to a provider patient, a wallet pass already in Wallet after the change                                                |          |

## Known issues

Status of the backlog items (`mobile-stabilization.md`) this audit passed through:

| Backlog item                          | Status                                                                                                                                 |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| D1 Fasten deletions stay              | Still present (`sync_local_data_source.dart:233`); A13 adds that a source the user deleted comes back                                   |
| D3 Duplicate patient after first sync | Confirmed; it is A1                                                                                                                    |
| B3 Home counts capped at 20           | Still present (`home_data_handler.dart:99` passes no limit, `records_repository.dart:10` defaults to 20)                               |
| Section 5 `canEditSource`             | Still present; in C3 with the rest of the dead source and patient code                                                                 |
| Section 8 adding or deleting patients, disconnecting Fasten | Still product decisions; out of scope here                                                                       |
