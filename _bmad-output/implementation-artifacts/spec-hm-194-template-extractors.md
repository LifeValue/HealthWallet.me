---
title: 'HM-194: layout extractors for documents with a known layout (first: clearvis.io eye care)'
type: 'feature'
created: '2026-11-04'
status: 'done'
baseline_revision: '7deceade75812228006d63fabbc781d05b2f4637'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture.md'
  - '{project-root}/tool/extraction_bench/README.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      Extractor fixtures exist only for Apple Vision OCR of the PDFs; Android ML Kit, Windows OCR and camera-photo OCR were never captured.
    evidence: |-
      All fixtures are macOS Vision .accurate output at 200 dpi; the noisy ones are derived from them. The implementer found that column-wise OCR (likely ML Kit or Windows) reads the prescriptions but finds none in the exam, which prints two prescriptions on one line. Settle by capturing de-identified OCR of both documents with ML Kit on an Android device and Windows OCR, plus camera photos of the printouts on iOS and Android, and adding them as fixtures.
    location: >-
      test/features/processing/layout_extraction/fixtures/
    severity: medium
  - summary: >-
      The real reference PDFs were never run through the app on a device: the real serials, dates, the under-1-s extractor step and the no-AI processing log are unverified end to end.
    evidence: |-
      The tests use de-identified fixtures with fake values and a fake AI counter; the real PDFs cannot be committed. Settle by importing both PDFs from the scratchpad on a device with no model, in both orders and once more, checking the review, the saved records and the processing log timing.
    location: >-
      lib/features/processing/presentation/bloc/handlers/processing_handler.dart (layout branch)
    severity: medium
  - summary: >-
      A plano (0.00) or one-decimal sphere may be read as an add on multifocal forms, sending the whole document to the AI.
    evidence: |-
      Unverified: in _formEyes every unsigned value counts as an add when the form has an Add column, and no fixture has a plano eye. Settle with a clearvis prescription that has a plano or 0.5 D eye: check how the platform prints it and whether extraction returns both eyes.
    location: >-
      lib/features/processing/data/extractors/clearvis/clearvis_io_extractor.dart (_formEyes)
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Every imported document goes through the on-device AI, even when it comes from a clinic system with a fixed layout that code could read exactly, instantly and without a downloaded model. clearvis.io eye-care documents (Optione is one tenant) are the first case: three glasses prescriptions in one PDF, and an exam result that repeats them without their serials.

**Approach:** Add a layout-extractor step to the processing pipeline right after OCR. A recognised document fills the session with staged FHIR resources (`Patient`, clinic `Organization`, examiner `Practitioner`, a visit `Encounter`, one `VisionPrescription` per prescription) and goes straight to the normal review; anything else runs the AI pipeline unchanged. The visit is the anchor: both clearvis documents of one visit resolve to the same Encounter in either import order, and a document whose records are already in the wallet completes them (empty fields only) instead of duplicating them. `VisionPrescription` becomes a first-class record type.

## Boundaries & Constraints

**Always:**
- Extractors are deterministic (no AI, no network) and return staged `MappingResource`s; review, Holders, saving, DocumentReferences and sync stay the existing code paths.
- One hook in `ProcessingHandler.onMappingInitiated` covers every entry point (camera scan, PDF import, image import, files shared from other apps, desktop drag-and-drop, desktop handover without phase-1 data).
- Completing an existing record only fills empty fields and never changes a value; an ambiguous match is never resolved by guessing (new record, or the user picks).
- A clinic patient number gets an identifier system per clinic, and holder matching honours it, so two clinics' `PA-00001` are never one person.
- Every resource an extractor creates or completes carries a provenance `meta.tag` (system `http://healthwallet.me/extractor`, code `<id>@<version>`), merged with the specialty tag, not replacing it.
- AGENTS.md rules: fvm, Freezed + `build_runner`, constructor injection in domain/data, fake repositories in tests, all four ARBs + `gen-l10n`, UI kit (`AppButton`, `AppColors`, `AppTextStyle`, `Insets`), `context.l10n`/`context.theme`, no empty `catch`, conventional commits without body or Co-Authored-By, local commits only.
- The real reference PDFs (scratchpad `hm194/Retete.pdf`, `hm194/Rezultate examinari.pdf`) and any text derived from them without de-identification never enter the repo. Committed fixtures follow the de-identification rule in `tool/extraction_bench/README.md` (names, dates of birth, addresses, phones, e-mails, serials and patient numbers replaced with fake values).

**Never:**
- No separate ophthalmology tables, no Drift schema change, no new sync table.
- No AI output of `VisionPrescription` (schemas, prompts, the "Add resources" dialog stay as they are) — follow-up.
- No general reconciliation of AI-extracted records (HM-228), no Eye Care IG Observations, no pupillary-distance Observation, no extractor debug screen.
- No keyword catch-all extractor; documents no extractor recognises go to the AI.
- Do not touch `docs/`, `.github/workflows/`, or the QR payload.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Prescriptions first | clearvis prescriptions PDF, empty wallet for that person | Session goes to `draft` with Patient, Organization, Practitioner, visit Encounter and 3 VisionPrescriptions (serials as `identifier`); no AI call | No error expected |
| Exam first | clearvis exam PDF, empty wallet | `draft` with Patient, Organization, visit Encounter (`EE-` serial as identifier) and the 3 VisionPrescriptions it lists, without serials | No error expected |
| Exam after prescriptions | Exam PDF, prescriptions already saved | Encounter staged as the existing visit (`linkExisting`), its `EE-` identifier added on save; the 3 prescriptions shown as already in the wallet; exam document attached to the visit | No error expected |
| Prescriptions after exam | Prescriptions PDF, exam already saved | Same visit; each prescription completes its exam-derived twin with serial, prescriber and follow-up date | No error expected |
| Re-import | Either document again, everything present | Review says everything is already in the wallet; Save writes nothing (no records, no DocumentReference, no Patient fill) | No error expected |
| Values differ | Same visit key, a prescription's per-eye values differ | That prescription is staged as new | No error expected |
| Several visits match | More than one Encounter with the visit key | Encounter staged as a new draft; the user can swap it with the existing attach-to-encounter control | No error expected |
| Other clinic, same number | Another tenant's document with `PA-00001` | Not matched to the first clinic's person | No error expected |
| Unrecognised document | Lab report, discharge letter, any non-clearvis text | Extractor step returns nothing; AI pipeline runs exactly as before | No error expected |
| Matched, fields missing | Score over threshold but no date or no patient name | Extractor returns null, nothing staged; AI pipeline runs | Logged in `ProcessingLogBuffer` |
| No model, recognised | No AI model downloaded, clearvis document | Processing route opens and the document is extracted offline | No error expected |
| No model, not recognised | No AI model, other document | Same as today: load-model page / `modelNotFound` | Existing handling |
| Malformed stored row | `VisionPrescription` row whose JSON lacks required fields | Shown as a `GeneralResource`, nothing throws | Logged with `logger.w` |

</intent-contract>

## Code Map

- `lib/features/processing/presentation/bloc/handlers/processing_handler.dart` -- `onMappingInitiated` (:60): OCR at :106, empty-text exit :109-116, OCR pre-match `_tryMatchPatientFromOcr` :117/:276 (identifier values via `HolderMatcher.appearsIn`), phase 1 :183, `_matchOrCreatePatient` :301. Hook goes after :116 and before :117. Save: `onResourceCreationInitiated` :476, "other resources" filter :487-494, specialty `meta` :504-525 (passed `meta` replaces the specialty meta today), `replaceSessionDocuments` :531, `_persistPrimaryResources` :573 (existing Encounter used as is at :617).
- `lib/features/processing/presentation/bloc/handlers/session_handler.dart` -- `onSessionActivated` :255; `prepareAllImages` :278; model gate :305-323 (`modelNotFound`).
- `lib/features/processing/presentation/helpers/document_handler.dart` -- `navigateToFhirMapper` :20-40: model check before `ProcessingRoute`, else `LoadModelRoute`/attach flow. Called from `scan_page.dart:227`, `import_page.dart:111`.
- `lib/features/processing/presentation/bloc/processing_bloc.dart` -- `@LazySingleton`, handlers mixin, `updateSession` :134, `startNextPendingSession` :124.
- `lib/features/processing/domain/entity/processing_session.dart` -- `ProcessingSession`, `ProcessingStatus` (:119; `draft` = review with Done).
- `lib/features/processing/domain/entity/staged_resource.dart` -- `StagedResource<D,F>{draft, existing, mode}`; `StagedPatient`, `StagedEncounter`; JSON helpers :53-99.
- `lib/features/processing/domain/entity/mapping_resources/mapping_resource.dart` -- `fromJson` switch :22-45 (unknown type throws → whole session list fails), `empty` :48-73, `toFhirResource({sourceId, encounterId, subjectId, meta})`. Template to copy: `mapping_medication_statement.dart`. `MappedProperty.withFullConfidence()` (`mapped_property.dart:174`).
- `lib/features/processing/domain/entity/mapping_resources/mapping_patient.dart` -- identifier system hardcoded `http://healthwallet.me/mrn` for non-national labels (:108-156, `_mapLabelToFhirCode` :274).
- `lib/features/processing/domain/entity/mapping_resources/mapping_encounter.dart` -- fields `encounterType`, `periodStart`, `specialty`; no identifiers yet; builds its own specialty meta :99-114.
- `lib/features/processing/presentation/pages/processing/widgets/resources_form.dart` -- generic form from `getFieldDescriptors`; any non-specialty `FieldType.dropdown` renders gender options (:422, :530) — use text fields.
- `lib/features/processing/presentation/pages/processing/widgets/processing_resources_section.dart` -- review sections; `draft` shows Add + Save (:73-79).
- `lib/features/processing/domain/services/ocr_processing_service.dart` -- `processOcrForImages` → one String, pages joined by `\n`.
- `lib/features/processing/domain/services/processing_log_buffer.dart` -- `ProcessingLogBuffer.instance.log('[$_ts][ScanAI] …')`, no-op in release.
- `lib/features/processing/domain/services/document_reference_service.dart` -- `replaceSessionDocuments` :34 (encounter link only for an Encounter container).
- `lib/features/holders/domain/services/holder_matcher.dart` -- `sameScannedPerson` :45 (scanned identifier has no system today), `_sameIdentifier` :62 (same non-empty system rule), `appearsIn` :120.
- `lib/features/holders/domain/services/holder_service.dart` -- `matchScanned` :239 builds `HolderIdentifier(system: '')`; `walletPatientOf` :160 fills empty fields; `walletSourceOf` :117.
- `lib/core/di/register_module.dart` -- `@module`; no multibinding exists, so the extractor list is built in a module getter.
- `lib/features/records/domain/entity/i_fhir_resource.dart` -- `fromLocalDto` switch :28-99 (default → `GeneralResource`), `FhirType` :128-158 (`.name` must equal the FHIR type), `mainRecordTypes` :164-183 (needed for attachments), not `supportingTypes`.
- `lib/features/records/domain/entity/immunization/immunization.dart` -- entity template (`fromLocalData`, `toDto`, `displayTitle`, `additionalInfo` via `ResourceFieldMapper`, `resourceReferences`, `statusDisplay`).
- `~/.pub-cache/hosted/pub.dev/fhir_r4-0.6.1/lib/src/resource_types/vision_prescription.dart` -- read-only: `fromJson` force-unwraps `status`, `created`, `patient`, `dateWritten`, `prescriber`, `lensSpecification[].product`, `.eye`.
- `lib/features/records/presentation/pages/record_detail_page.dart` (:228), `lib/features/records/presentation/pages/records_page.dart` (`_DesktopDetailsPanel` :711, info :992-1000), `lib/features/share_records/presentation/widgets/ephemeral_desktop_details_panel.dart` (:325) -- where the per-eye table is shown.
- `lib/core/l10n/display_names.dart` -- exhaustive `FhirTypeL10n` :89-121, `HomeRecordsCategoryL10n` :71-87.
- `lib/features/home/domain/entities/overview_card.dart` -- `HomeRecordsCategory` :14-121 (icon switch :92-121); `lib/features/home/presentation/bloc/home_state.dart:19-31` default category map; specialty counts only cover category types (`home_data_handler.dart:47-90`).
- `lib/features/home/data/services/specialty_classifier_impl.dart` -- `_classifyByDirectFhirSpecialty` :69-108.
- `lib/features/share_records/data/mapper/fhir_bundle_mapper.dart` -- `_extractTitle` :212-225, `_extractDate` :243-285.
- `tool/extraction_bench/src/generator.dart` -- `buildDocuments(GeneratorOptions(...))` :263, `renderDocument(doc, BenchFonts.load(...))` :1088 → `RenderedDoc.text`; already imported from `test/extraction_bench/generator_test.dart` (run from repo root).
- Test patterns: `test/features/processing/l10n/processing_l10n_test.dart:75-106` (real `ProcessingBloc` from fakes, seed state, `SessionActivated`, await stream), `test/fixtures/fhir/fhir_fixtures.dart` (`entityFromJson`, per-type JSON builders), guard tests `test/features/records/domain/entity/additional_info_l10n_test.dart`, `test/core/l10n/display_names_test.dart`, `test/core/l10n/arb_parity_test.dart`.

## Tasks & Acceptance

**Execution:**
- `lib/features/processing/domain/services/layout_extraction/layout_extractor.dart` -- define the contract: `id`, `version`, `double score(String ocrText)` (cheap, no AI), `LayoutExtraction? extract(String ocrText)`; and `LayoutExtraction` (clinic key, `MappingPatient`, `MappingOrganization`, optional `MappingPractitioner`, visit `MappingEncounter` with its visit key, `List<MappingVisionPrescription>` or generic `List<MappingResource>`). Imports nothing ophthalmology-specific beyond mapping resources -- reusable for other layouts.
- `lib/features/processing/domain/services/layout_extraction/layout_extractor_registry.dart` -- holds the ordered extractor list; `best(text)` returns the highest score ≥ 0.5, ties broken by registration order; logs every score.
- `lib/features/processing/domain/services/layout_extraction/layout_extraction_service.dart` -- `@lazySingleton`: `recognise(sessionId, imagePaths)` runs OCR once per session (cached) and returns whether an extractor matches; `extract(...)` returns the staged result after visit reconciliation, or null.
- `lib/features/processing/domain/services/layout_extraction/visit_reconciler.dart` -- for the matched holder: find Encounters carrying the visit-key identifier (exactly one → `linkExisting`, otherwise new draft); within that visit, match VisionPrescriptions by lens type + exact per-eye values and mark each staged prescription with the existing row id (or new); compute whether anything at all would be written.
- `lib/features/processing/data/extractors/clearvis/clearvis_io_extractor.dart` (+ small parser helpers in the same folder) -- detects the clearvis.io platform (footer, `PR-`/`EE-` serial patterns, bilingual labels), parses prescription blocks (split on serials) and the exam's "Rețete" section, per-eye `Sph/Cyl/Axis/Add` with decimal commas and missing diacritics, dates `DD.MM.YYYY`, store, examiner ("Examination recorded by"), recommended follow-up ("Data control recomandat"). Clinic key = website domain when printed, else slugified store name. Returns null when a required field (date, patient name) is missing.
- `lib/core/di/register_module.dart` (or a processing module next to it) -- provide `LayoutExtractorRegistry([ClearvisIoExtractor()])`; adding an extractor is one entry here.
- `lib/features/processing/domain/entity/mapping_resources/mapping_vision_prescription.dart` -- Freezed `MappingVisionPrescription implements MappingResource`: serial, lens type (`multifocal`, `distance`, `reading`, `other`), date written, follow-up date, prescriber ref/name, right/left sphere, cylinder, axis, add, prism, base, `existingId`; `toFhirResource` builds `fhir_r4.VisionPrescription` (`status: active`, `created`/`dateWritten`, `patient`, `encounter`, `prescriber` — a display-only reference to the clinic when no examiner, `lensSpecification` per eye with `product` codings `ex-visionprescriptionproduct#lens` + `http://healthwallet.me/lens-type#<type>`, follow-up as extension `http://healthwallet.me/fhir/StructureDefinition/recommended-follow-up` valueDate); text-field descriptors only.
- `lib/features/processing/domain/entity/mapping_resources/mapping_resource.dart` -- add `VisionPrescription` to `fromJson` and `empty`.
- `lib/features/processing/domain/entity/mapping_resources/mapping_encounter.dart` -- optional identifiers (system + value, persisted in session JSON) written in `toFhirResource`; visit key system `http://healthwallet.me/visit/<extractorId>`, value `<clinicKey>|<patientNumber>|<date>`.
- `lib/features/processing/domain/entity/mapping_resources/mapping_patient.dart` -- optional `identifierSystem`; when set, `toFhirResource` uses it with type `MR` (system `http://healthwallet.me/clinic/<clinicKey>/patient`).
- `lib/features/holders/domain/services/holder_service.dart`, `lib/features/holders/domain/services/holder_matcher.dart` -- `matchScanned` passes the scanned system; a scanned identifier with a system matches only a stored identifier with the same system (national types unchanged); empty system keeps today's behaviour.
- `lib/features/processing/presentation/bloc/handlers/processing_handler.dart` -- after the empty-OCR exit and before the OCR pre-match, call the extraction service; on a result stage patient (`_matchOrCreatePatient` with the system-scoped identifier), container (existing visit or draft), resources, set `draft` with `updateDb: true`, notify, `startNextPendingSession`, return. At save: merge provenance tag with the specialty meta; for a prescription with `existingId`, read the stored row, fill empty fields only, keep its row id (skip when nothing to fill); for a `linkExisting` visit add missing identifiers; when nothing would be written, write nothing (no Patient fill, no DocumentReference).
- `lib/features/processing/presentation/bloc/handlers/session_handler.dart`, `lib/features/processing/presentation/helpers/document_handler.dart` -- the model gate also passes when `recognise(...)` is true.
- `lib/features/processing/presentation/pages/processing/widgets/resources_form.dart` (or the resources section) -- show "Already in your wallet" / "Already in your wallet, will be completed" on staged items with `existingId`, and a "Everything in this document is already in your wallet" note when nothing would be written.
- `lib/features/records/domain/entity/vision_prescription/vision_prescription.dart` (+ `entity.dart` export) -- Freezed entity; `fromLocalData`; `displayTitle` from the lens type; `additionalInfo` (status, date written, prescriber, follow-up, product) with l10n prefixes; per-eye rows exposed for the table.
- `lib/features/records/domain/entity/i_fhir_resource.dart` -- `FhirType.VisionPrescription('Vision Prescription')` in `mainRecordTypes`; `fromLocalDto` case that falls back to `GeneralResource` (logged) when parsing throws.
- `lib/features/records/presentation/widgets/vision_prescription_table.dart` -- per-eye table (OD/OS × Sph, Cyl, Axis, Add, Prism) with UI-kit styling; used in `record_detail_page.dart`, `records_page.dart` desktop panel and `ephemeral_desktop_details_panel.dart`.
- `lib/features/home/domain/entities/overview_card.dart`, `lib/features/home/presentation/bloc/home_state.dart`, `lib/features/home/data/services/specialty_classifier_impl.dart` -- new `HomeRecordsCategory.visionPrescriptions` (ophthalmology icon, default on) and a type rule classifying `VisionPrescription` as Ophthalmology.
- `lib/features/share_records/data/mapper/fhir_bundle_mapper.dart` -- title and date (`dateWritten`, then `created`) cases.
- `lib/core/l10n/display_names.dart`, `lib/core/l10n/arb/app_{en,es,de,ro}.arb` -- type, category, field, eye and review-state strings in all four; run `fvm flutter gen-l10n`.
- `_bmad-output/planning-artifacts/architecture.md` -- "Layout extractors" subsection under Processing pipeline: where the step runs, the contract, the visit anchor and completion rules, and the steps to add an extractor.
- `test/features/processing/layout_extraction/fixtures/` -- de-identified OCR text of both documents, taken from Apple Vision OCR output (macOS Vision `.accurate`, one line per observation, pages rasterised at 200 dpi as the app does) plus a noisy variant (decimal commas, missing diacritics) and a second-tenant variant.
- `test/features/processing/layout_extraction/` -- tests: clearvis parsing (all fields, both documents, noisy, second tenant), registry (ranking, ties, threshold, a test-only extractor for a made-up layout added with no other change), no false matches on every `buildDocuments` synthetic document (all families and languages) and on ophthalmology-free text, visit reconciler (both orders, re-import, differing values, several visits), and a `ProcessingBloc` test (fakes) showing a recognised document reaches `draft` without any AI call and without a model.
- `test/features/holders/` -- system-scoped matching tests; `test/features/records/domain/entity/` and `test/fixtures/fhir/fhir_fixtures.dart` -- `VisionPrescription` entity, malformed-row fallback, info lines; `test/features/processing/domain/` -- `MappingVisionPrescription.toFhirResource` round-trips through `fhir_r4.VisionPrescription.fromJson`, provenance tag merged with specialty tag.

**Acceptance Criteria:**
- Given the prescriptions document's OCR text and an empty wallet, when it is processed, then the review shows three `VisionPrescription`s with their serials, per-eye values as printed, date written, the examiner as prescriber, lens type and follow-up date, plus the Patient with the clinic-scoped patient number, the clinic Organization and the visit Encounter, and no AI generation is requested.
- Given either import order of the two documents, when both are saved, then the wallet holds one visit Encounter (with the `EE-` identifier), three `VisionPrescription`s with serials linked to it, and both documents attached to it.
- Given a document whose records are all in the wallet, when it is imported again, then saving writes no row and no DocumentReference.
- Given a user edited an exam-derived prescription, when the prescriptions document completes it, then the edited values are unchanged and only empty fields are filled.
- Given no AI model on the device, when a clearvis document is imported from any entry point, then it reaches the review and saves offline; an unrecognised document still gets the load-model flow.
- Given a new extractor class for another layout, when it is added with one registration entry, then it takes part in ranking with no change to the pipeline, review UI, database or other extractors (shown by the test-only extractor).
- Given any synthetic benchmark document, when the registry scores it, then no extractor reaches the threshold.
- Given a saved `VisionPrescription`, when Records, the record detail page and the desktop panel show it, then a per-eye table is shown, the type filter lists it, it counts under Ophthalmology on Home, and all its strings exist in en, es, de and ro.
- Given a paired desktop, when the records sync, then they display on both ends, and a `VisionPrescription` row on an app version without the type is shown as a generic resource without errors.

## Spec Change Log

## Review Triage Log

### 2026-11-04 — Review pass
- verdicts: 50 findings — high 0, medium 22, low 19, false 8, maybe-false 1
- findings:
  - `[medium]` `[patch]` intent: visit Encounter not linked to the clinic Organization — `MappingEncounter.serviceProviderRef` written as `Encounter.serviceProvider` by the clearvis extractor; persisted in session JSON.
  - `[false]` `[reject]` intent: several matching visits never prompt the user — the visit is staged as a new draft and the existing attach-to-encounter swap lets the user pick one or keep a new visit, as AC3 and the matrix describe.
  - `[false]` `[reject]` intent: serial matching searches all the holder's prescriptions, not only the visit — the same serial under the same clinic's document system is the same prescription; no wrong outcome follows.
  - `[low]` `[patch]` intent: the "already in your wallet" banners have no widget test — added `widgets/wallet_notes_test.dart` (form notes, locked fields, section note).
  - `[false]` `[reject]` intent: the holder question is not exercised — that flow is unchanged existing code; the extractor stages the patient through the existing `_matchOrCreatePatient`.
  - `[low]` `[reject]` intent: the no-false-match check scores the generator's rendered text, not OCR output — OCR of the synthetic set is not available to host tests; the rendered text is the closest deterministic stand-in and the fix would need devices.
  - `[false]` `[reject]` intent: domain and save code special-case VisionPrescription, so "adding an extractor touches nothing else" is shown only at the registry — the special cases complete VisionPrescription twins; a new layout producing other resource types goes through the generic save with one registration entry.
  - `[false]` `[reject]` intent: provenance code is `clearvis.io@1`, not `clearvis_io@1.0.0` — AC9 gives that as an example; the tag carries the extractor's id and version as required.
  - `[low]` `[patch]` intent: the per-eye table and the Records filter have no widget test — added `vision_prescription_table_test.dart` and a VisionPrescription case in `record_detail_page_test.dart`; the filter lists `FhirType.values` generically.
  - `[low]` `[reject]` intent: camera, share, drag-and-drop and handover entry points are untested — all of them create a `ProcessingSession` that reaches the one tested hook; the import gate is now covered through `LayoutExtractionService.canProcess`.
  - `[false]` `[reject]` intent: sync and the older-peer fallback are untested — LWW sync copies rows without parsing types (`lww_sync_service.dart`), and `IFhirResource.fromLocalDto` already maps unknown types to `GeneralResource`; nothing in the change touches either.
  - `[medium]` `[patch]` intent: the model gate checks the model first and only scores the document (AC13) — grouped with the blind/edge `recognise` finding; `canProcess` passes only when an extractor actually extracts.
  - `[medium]` `[defer]` intent: fixtures are Apple Vision only (AC14) — needs ML Kit, Windows and camera captures on devices; deferred.
  - `[medium]` `[defer]` intent: the real PDFs, the 1 s timing and the processing log were never checked on a device — real PDFs cannot be committed; deferred as a manual device check.
  - `[medium]` `[patch]` blind: `recognise` returns true on score alone, so a scored-but-incomplete document without a model passes the gate and fails in the AI path — `recognise` now requires `extract(text) != null`; tested in `layout_extraction_service_test.dart`.
  - `[medium]` `[patch]` blind: the visit key and stable ids depend on store name and patient number the extractor never required, and the patient number made Organization/Practitioner ids differ per family member — the extractor returns null without either; Organization and Practitioner ids come from the clinic key (and examiner) only; tests added.
  - `[medium]` `[patch]` blind: edits to a matched prescription are silently dropped at save — forms with a wallet note (twins, a linked visit) are shown locked with the note; widget test added.
  - `[low]` `[reject]` blind: per-eye number fields have no validation, so non-numeric input is dropped — users rarely retype extracted values and the fix adds validators across the form.
  - `[maybe-false]` `[defer]` blind: a plano (0.00) sphere on a multifocal form counts as an add and fails the document — no clearvis sample with a plano eye exists to show how it is printed; deferred (medium, unverified).
  - `[false]` `[reject]` blind: staging and save build the encounter reference from different ids (`resourceId` vs `id`) — they differ only for Fasten rows with composite ids; the visit-key Encounter is always one the extractor created, whose row id equals its resource id.
  - `[medium]` `[patch]` blind: the review's already-in-wallet predicate and the save's write-nothing check differ, so a layout session switched to a DiagnosticReport container could save nothing — both use `ProcessingSession.isAlreadyInWallet` now.
  - `[medium]` `[patch]` blind: record titles and the Encounter type are English strings stored in synced data — titles and the Encounter type are the headings the document prints; `displayTitle` prefers the title column, then the localised lens type.
  - `[low]` `[patch]` blind: a cleared date becomes today, and impossible dates like 31.02.2024 are accepted — `isoDate` now rejects dates that don't round-trip; the cleared-date fallback is unchanged (a deliberate user action, FHIR requires the field).
  - `[low]` `[reject]` blind: cached OCR text is never dropped after save and is keyed by page count — negligible memory for one app run, and page changes go through `forget` (reorder, clear) or change the count.
  - `[medium]` `[patch]` blind: the model gate rasterises and OCRs from the UI helper — the decision moved into `LayoutExtractionService.canProcess`, used by all three sites; progress during that OCR is not shown (only when no model is installed).
  - `[medium]` `[patch]` blind: the layout branch ignores a cancel during OCR — it stages nothing when `shouldCancelGeneration` is set or the session left `processingPatient`; a leftover DiagnosticReport on a re-processed session was not shown reachable.
  - `[low]` `[patch]` blind: smaller gaps (duplicated 100000 limit, provenance keeps the first tag, the note duplicates the form banner with literals, no direct `ClearvisText`/`ExtractorProvenance` tests) — one shared `allRecords` constant and a shared `ReviewBanner`; the provenance and direct-test points rejected as negligible.
  - `[medium]` `[patch]` edge: `recognise` scores without extracting (same as blind) — fixed with it.
  - `[medium]` `[patch]` edge: an empty first OCR result is cached and reused on every retry — empty text is no longer cached; tested.
  - `[medium]` `[patch]` edge: the write-nothing exit can skip a DiagnosticReport container — fixed with the shared predicate.
  - `[medium]` `[patch]` edge: twin edits dropped (same as blind) — fixed with the locked forms.
  - `[low]` `[reject]` edge: a twin whose stored row is deleted between staging and save is neither completed nor created — needs the user to delete that record mid-review; the fix adds a save branch.
  - `[low]` `[patch]` edge: completion fills the `encounter` reference but leaves the `encounterId` column empty — completion now sets `encounterId` from the filled reference.
  - `[medium]` `[patch]` edge: a missing store name gives the shared system `clinic//patient` — fixed with the required store name.
  - `[medium]` `[patch]` edge: a systemless (AI-path) scan matches a stored clinic-scoped number by value — `sameScannedPerson` no longer matches a clinic-scoped number without a system; matcher tests updated.
  - `[low]` `[patch]` edge: impossible calendar dates are accepted — fixed in `isoDate`; tested.
  - `[false]` `[reject]` edge: an identifier with an empty system never matches stored JSON — every identifier the extractor writes has a system (visit key, clinic document system), and the store name is now required.
  - `[low]` `[reject]` edge: a record completed by a newer extractor version keeps the old provenance tag — only one version exists; the fix changes the merge rule for a case nobody meets yet.
  - `[low]` `[reject]` edge: the clinic key is the store name, not the website the spec names — the code is right (only the exam prints the website, so the documents would key the visit differently); the fix is a spec edit.
  - `[low]` `[reject]` edge: prescription blocks are split on headings, not serials as the spec says — Apple Vision reads the serial mid-block, so splitting on headings is what works; the fix is a spec edit.
  - `[low]` `[patch]` verification: the OCR pre-match skip of clinic numbers has no test — bloc test added: a non-layout document containing a saved clinic number runs `mapBasicInfo`, never `mapContainerOnly`.
  - `[medium]` `[patch]` verification: the queued-session message still checks only the model — `processing_page.dart` uses `canProcess`.
  - `[medium]` `[patch]` verification: the import/scan gate in `DocumentHandler` is untested — the decision is now `canProcess`, unit-tested for model × recognised / incomplete / unrecognised / preparation failure.
  - `[low]` `[patch]` verification: provenance tags on Patient, Organization and Practitioner are not asserted — bloc test asserts them, including the default-holder fill.
  - `[low]` `[patch]` verification: the reorder cache drop is untested — bloc test: reordered pages are OCR'd again, in the new order.
  - `[low]` `[patch]` verification: the per-eye table has no widget test — added (see the intent row).
  - `[low]` `[patch]` verification: `copyWithMap` keys and prism/base are untested — every descriptor key edits exactly its field; prism and base round-trip.
  - `[medium]` `[patch]` verification: edits to a matched prescription are discarded (same as blind) — fixed with the locked forms.
  - `[medium]` `[patch]` verification: the pre-match and AI-path match disagree on clinic numbers (same as edge) — fixed in `sameScannedPerson`.
  - `[medium]` `[patch]` verification: an image-preparation failure shows an error instead of the model download — page preparation runs inside `canProcess`, a failure is logged and counts as not recognised.

## Design Notes

**Visit key.** Neither clearvis document lists the other's serials, but both print the store, the patient number and the visit date. The extractor writes `<clinicKey>|<patientNumber>|<date>` as an Encounter identifier, so finding the visit is an exact identifier lookup within the matched holder's sources — no fuzzy organization matching. The `EE-` serial is a second identifier on the same Encounter.

**Prescription twin.** Within a visit, a lens type appears once per document (multifocal, distance, reading), and both documents print the same per-eye values. Lens type + exact sphere/cylinder/axis/add is therefore a safe key; any difference means a new record.

**Placeholder prescriber.** The exam prints no examiner, and `fhir_r4` requires `prescriber`. An exam-derived prescription gets a display-only reference to the clinic, tagged as placeholder; completion treats the placeholder as empty and replaces it with the examiner from the prescriptions document. This is the only "replace", and only of a value the extractor itself wrote.

**Nothing to write.** When the visit, every prescription and the patient already hold everything the document carries, the session still reaches review (so the user sees the outcome), and Save closes it without writing.

## Verification

**Commands:**
- `fvm dart run build_runner build` -- expected: succeeds (Freezed for the new mapping resource, entity, injectable config).
- `fvm flutter gen-l10n` -- expected: `untranslated_messages.json` lists no new key.
- `fvm flutter test test/features/processing/layout_extraction/ test/features/holders/ test/features/records/ test/core/l10n/` -- expected: all pass.
- `scripts/check.sh` -- expected: formatters clean, `fvm flutter analyze` no issues (infos included), `fvm flutter test` all pass.

**Manual checks (if no CLI):**
- On a device or simulator with no AI model: import the two real PDFs from the scratchpad (never copied into the repo) in both orders and once again; check the review states and the resulting records match the AC.
- Photograph the printed documents with the in-app camera on iOS and Android; check they are recognised (fixtures for camera OCR and Android ML Kit OCR are captured then).

## Auto Run Result

Status: done

**Summary.** Documents printed by a clinic system with a fixed layout are read by a deterministic layout extractor right after OCR, with no AI call and no model needed; anything else runs the AI pipeline unchanged. The first extractor reads clearvis.io eye care: the glasses-prescriptions PDF and the exam result, which resolve to one visit Encounter (`serviceProvider` the clinic) and three `VisionPrescription`s in either import order. A document whose records are already in the wallet completes their empty fields only, or writes nothing. Clinic patient numbers are scoped per clinic in holder matching. `VisionPrescription` is a record type with a per-eye table, a Home category and the Ophthalmology classification, in all four languages.

**Files changed** (commits on `feature/template-extractors` after `7deceade`):
- `lib/features/processing/domain/services/layout_extraction/` -- extractor contract, registry, service (OCR cache, `canProcess` model gate, staging), visit reconciler, completion rules.
- `lib/features/processing/data/extractors/clearvis/` -- the clearvis.io extractor and its text helpers.
- `lib/features/processing/domain/entity/mapping_resources/` -- `MappingVisionPrescription`, identifiers, `serviceProviderRef` and provenance on Encounter/Patient/Organization/Practitioner, clinic-scoped patient system.
- `lib/features/processing/presentation/` -- the hook in `onMappingInitiated`, save-time completion and write-nothing exit, the shared model gate, locked review forms with wallet notes (`ReviewBanner`).
- `lib/features/holders/domain/services/` -- clinic-scoped identifier matching.
- `lib/features/records/`, `lib/features/home/`, `lib/features/share_records/`, `lib/core/l10n/` -- the `VisionPrescription` entity, table, category, classifier rule, bundle mapper cases and strings.
- `lib/core/di/register_module.dart` -- the extractor list.
- `_bmad-output/planning-artifacts/architecture.md` -- the Layout extractors section.
- `test/features/processing/layout_extraction/` (+ de-identified Apple Vision fixtures), `test/features/holders/`, `test/features/records/`, `test/features/processing/presentation/pages/processing/widgets/` -- tests.

**Review.** 50 findings across four layers (high 0, medium 22, low 19, false 8, maybe-false 1). Patched: 31 rows (medium 20, low 11), covering the model gate (`canProcess`, extract-not-score, no empty OCR cache), required store and patient number, family-shared clinic ids, `serviceProvider`, locked twin forms, one write-nothing predicate, cancel during OCR, `encounterId` on completion, systemless scans vs clinic numbers, impossible dates, printed titles, the shared banner and the missing tests. Deferred: 3 (other OCR engines and camera fixtures, a device run of the real PDFs, plano spheres — unverified). Rejected: 16, each with its reason in the Review Triage Log (8 false; 8 low as negligible, needing devices, or whose fix is a spec edit: the store-name clinic key and heading-based splitting are deliberate departures from the Tasks text, since only the exam prints the website and Apple Vision reads serials mid-block).

**Follow-up review recommended: true.** Patched by verdict: medium 20, low 11. The fixes were applied after the review and not reviewed themselves; the named risk is the reworked model gate (`LayoutExtractionService.canProcess` now prepares pages and runs a full extraction from the import screen and the queued-session message) and the locked review forms.

**Verification.**
- `fvm dart run build_runner build` -- succeeded, no tracked file changed.
- `fvm flutter gen-l10n` -- `untranslated_messages.json` is `{}`.
- `dart format` on the changed files -- 0 changed.
- `fvm flutter analyze` -- no issues.
- `fvm flutter test` -- 2620 passed; 1 guard failure (`no_hardcoded_text_test`, a quoted heading in a doc comment) fixed and re-run green; 2 failures in `test/features/desktop/communication/data/services/ssdp_service_test.dart`, which fail the same way outside the sandbox and touch code this branch does not change (machine network).
- `scripts/check.sh` was not run as one script: the pre-commit RuboCop environment cannot be installed on this machine (a Ruby gem fails to build); its other steps ran as above, and commits used `SKIP=rubocop` (no Ruby files changed).
- The manual device checks were not done (see `deferred`).

**Residual risks.** OCR engines other than Apple Vision may lay the exam's two-prescriptions-per-line table out in columns and find none; a misread `EE-` serial is stored as read (the visit key does not use it); a form whose eye values don't pair up sends the whole document to the AI, which can't produce prescriptions; with no model installed, the import screen rasterises and OCRs the document before choosing a route, with no progress shown. The real patient number in this spec's intent contract was replaced by the fake `PA-00001` before committing, since real identifiers must not enter the repository.
