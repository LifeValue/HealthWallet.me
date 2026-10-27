---
title: 'Schema-specific structured output for on-device document extraction'
type: 'feature'
created: '2026-10-26'
status: 'done'
baseline_revision: '3f0cc8faf9a4f96abe583ea707ca65333fa9ac17'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/doc/architecture.md'
  - '{project-root}/tool/extraction_bench/README.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The equalised vision phase-2 prompt (2000 OCR chars + few-shot, every mode) may not fit the 2048-token vision context of smaller phones.
    evidence: |-
      Unverified. A too-long prompt is caught per batch and falls back to text. Settle by a vision run on a 6 GB phone, or by counting prompt + two image tokens against the vision context from DeviceCapabilityService.computeModelConfig.
    location: >-
      lib/features/processing/data/repository/ai_extraction_repository.dart (vision batch prompt)
    severity: medium (unverified)
  - summary: >-
      Vision accuracy with the equalised prompt and the schema modes was not measured: the simulator memory check sent 20-22 of 24 documents to the text fallback.
    evidence: |-
      2-4 vision generations per simulator vision run (README, Output-mode measurement). Settle with the iPhone run, BENCH_VISION=true, grammar vs schema, phone unlocked with the app in front.
    location: >-
      tool/extraction_bench/README.md
    severity: medium
  - summary: >-
      schemaDraft vision phase 1 and container-only have no repository tests.
    evidence: |-
      Only phase 2 (text and vision) and text phase 1 are tested in schemaDraft. Unreachable in the app today: not the default and nothing in lib/ writes aiOutputMode.
    location: >-
      test/features/processing/output_mode_repository_test.dart
    severity: low
  - summary: >-
      Cancelling during the last vision batch still runs the phase-2 text fallback.
    evidence: |-
      Pre-existing: the TEXT-ONLY FALLBACK block has no shouldCancelGeneration check, before and after this change; schemaDraft inherits it.
    location: >-
      lib/features/processing/data/repository/ai_extraction_repository.dart (TEXT-ONLY FALLBACK)
    severity: low
---

<intent-contract>

## Intent

**Problem:** The on-device pipeline constrains the model only to "a JSON array of objects" (`GbnfGrammars.jsonArray`), so a 2B model is free to emit wrong types, unparseable dates, labels from the wrong country, Conditions on lab reports and runaway lists that hit the token limit mid-JSON (iPhone benchmark: es-lab-001 truncated, German IDs labelled "CNP", vision F1 0.405 vs text 0.511 with 45% omissions). Research Recommendation 2 (research.md §D3) prescribes schema-specific constrained output, measured on the extraction benchmark before it becomes the default.

**Approach:** Add an output mode (`grammar` = today, `schema`, `schemaDraft`) read from a pref and passed like the other AI tuning prefs. In `schema` mode every generation passes a flat per-phase JSON schema as llamadart `responseFormat` instead of the grammar, and the object output is mapped back to the existing MappingResource JSON; `schemaDraft` adds an unconstrained draft pass before it. Fix the prompt defects the runs exposed in all modes, record `finishReason` in the benchmark, answer the `fhir_r4_validation` question with a package probe, then measure the three modes on the iOS simulator and set the default from the result.

## Boundaries & Constraints

**Always:** Keep the intermediate-schema-then-map design: schema output is converted to the same `resourceType`-tagged maps `MappingResource.fromJson` reads today, so `toFhirResource`, the review UI, sync and the DB are unchanged. Schemas are flat: no `$defs`/`$ref`, no `anyOf`, every property listed in `required` and in the order the prompt describes, enums for closed sets, dates as `pattern` `^(\d{4}(-\d{2}(-\d{2})?)?)?$`, `maxItems` on every array, `additionalProperties: false`. Every schema must convert with llamadart's own validator (`LlamaStructuredOutput.jsonValueSchema`) in a host test. The prompt still describes the output shape (llama.cpp does not inject the schema). `grammar` mode stays byte-for-byte the current request apart from the shared prompt fixes. The benchmark runner keeps mirroring production (same pref, same repository calls). Platform rules from AGENTS.md: fvm, Freezed models + `build_runner`, constructor injection in data/domain, fake repositories/data sources in tests, conventional commits without Co-Authored-By, local commits only.

**Never:** No full-FHIR grammar. No new UI or user-facing strings (the mode is a pref only, no l10n needed). No `fhir_r4` upgrade or `fhir_r4_validation` dependency in the app (0.14 needs `fhir_r4 ^0.14`; the app and `fhir_ips_export` are on 0.6). No LoRA, no model swap, no LiteRT-LM. Do not change desktop/mobile behaviour beyond the documented prompt fixes while the default stays `grammar`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Phase 1 schema | OCR of a German lab report, mode `schema` | One object → `MappingPatient` + `MappingDiagnosticReport` (documentCategory `lab_report`); dates ISO or empty | Unparseable output → same fallback as today (vision basic info) |
| Phase 2 lab report | `documentCategory: lab_report`, mode `schema` | Only Observation, Practitioner, Organization resources; Condition impossible | Truncated/invalid JSON → `_repairTruncatedJsonArray`-equivalent salvage of complete items, else empty list (no throw) |
| Phase 2 visit | `documentCategory: visit` | Condition, MedicationStatement, Procedure, AllergyIntolerance, vital-sign Observation, Practitioner, Organization | as above |
| Unknown category | `documentCategory` null/other | Union schema of all phase-2 types | as above |
| Draft mode | mode `schemaDraft` | Unconstrained draft call (same modality as the step), then constrained text call with draft + OCR in the prompt | Draft call fails → constrained call without draft |
| Mode pref missing/unknown | pref unset or junk | `grammar` (current behaviour) | — |
| Document country | OCR with "Geburtsdatum", phone locale RO | KVNR hints, not CNP | No marker matched → locale profile as today |
| Truncation | generation stops at maxTokens/context | record `finishReason: length`; report counts it | — |

</intent-contract>

## Code Map

- `lib/features/processing/data/model/grammar/gbnf_grammars.dart` -- legacy grammar; stays for `grammar` mode.
- `lib/features/processing/data/data_source/network/ai_inference_handler.dart` -- `runVisionPromptImpl` (~l.98) / `runTextPromptImpl` (~l.245) call `engine!.create(messages, params: GenerationParams(grammar:), enableThinking: false)`; `create` also takes `responseFormat` (llamadart `engine.dart:1635`). Final chunk carries `choices.first.finishReason` (`completion_chunk.dart:189`) and `usage`; `buildGenerationStats` builds stats.
- `lib/features/processing/data/data_source/network/ai_inference_data_source.dart` -- interface `runTextPrompt/runVisionPrompt({prompt, maxTokens, grammar})` + impl; add `responseFormat`.
- `lib/features/processing/data/model/generation_stats.dart` -- Freezed; add `finishReason`.
- `lib/features/processing/data/repository/ai_extraction_repository.dart` -- `processMapBasicInfo` (l.196), `mapContainerOnly` (l.236), `_tryTextOnlyBasicInfo` (l.301), `_visionBasicInfo`, `processMapRemainingResources` (vision batches, `_visionOcrMaxLength = 800`, `includeFewShot: false`; text fallback 2000 chars + few-shot), `_parseBasicInfoResponse`, `_parseResourcesFromResponse` (dedupe, `_shouldSkipResource`, `populateConfidence`, `isValid`), `_repairTruncatedJsonArray`.
- `lib/features/processing/data/model/prompt_template/{basic_info_prompt,basic_info_vision_prompt,remaining_resources_vision_prompt,correction_template_loader}.dart` -- prompts; few-shot examples are legacy arrays (`_formatExample`).
- `lib/core/config/constants/country_identifier.dart` -- `_profiles` (RO, DE, AT, ES, FR, IT, NL, PL, SE, CH, GB, US), `forCurrentLocale()` used by both basic-info prompts.
- `lib/features/processing/domain/repository/processing_repository.dart`, `.../data/repository/processing_repository_impl.dart`, `.../presentation/bloc/handlers/processing_handler.dart` (l.~100 container-only, l.~146 basic info, l.~281 remaining: prefs read with `isDesktop ? null : prefs.get…`) -- thread the mode through like `maxTokens`.
- `lib/core/config/constants/shared_prefs_constants.dart` -- add `aiOutputMode`.
- `lib/core/config/constants/app_constants.dart` -- `defaultMaxTokens 4096`, `visionMaxTokens 512` (mobile), `desktopVisionMaxTokens 1024`.
- Benchmark: `integration_test/extraction_bench_test.dart` (defines, pref set/restore pattern for `aiSelectedModel`), `integration_test/extraction_bench/{recording_data_source,run_record,document_runner}.dart`, `tool/extraction_bench/src/{dataset,report}.dart`, `tool/extraction_bench/README.md`, tests in `test/extraction_bench/` and `test/features/processing/`.
- llamadart 0.15.6 schema support: `pattern`, `enum`, `maxItems`, `format` in `lib/src/core/grammar/json_schema_converter.dart`; root may be an object (`jsonValueSchema` validates any root).

## Tasks & Acceptance

**Execution:**
- `lib/features/processing/data/model/structured_output/extraction_schemas.dart` (new) -- `ExtractionOutputMode {grammar, schema, schemaDraft}` with `fromPref`; schema builders for phase 1 (flat: patient fields, documentTitle, documentDate, conclusion, documentCategory enum), container-only (document fields only) and phase 2 per category (lab_report / visit / union; arrays `observations`, `vitalSigns`, `conditions`, `medications`, `procedures`, `allergies`, `practitioners`, `organizations` with maxItems); `responseFormat(schema)`; prompt-format text describing each shape; mappers from schema output to legacy `resourceType` maps, salvaging complete array items from truncated output.
- `ai_inference_data_source.dart`, `ai_inference_handler.dart`, `generation_stats.dart` -- add optional `responseFormat` to both run methods and pass it to `engine.create`; capture `finishReason` into `GenerationStats`; run `build_runner`.
- `ai_extraction_repository.dart` + prompt templates -- take `outputMode` on the four entry points; in schema modes use the schemas and object-shape prompt text and the mappers before the existing dedupe/skip/confidence path; `schemaDraft` adds the draft pass (draft ≤384 tokens; constrained pass text-only with draft + OCR; text ctx ≥4096 in this mode). In all modes: vision phase 2 gets the same OCR length (2000) and few-shot as the text fallback; lab-report prompts no longer offer Condition (prompt only in `grammar` mode).
- `country_identifier.dart` -- `forDocument(String ocrText)`: score profile markers in the text, use the best unique hit, else `forCurrentLocale()`; both basic-info prompts use it.
- `processing_repository.dart`, `processing_repository_impl.dart`, `processing_handler.dart`, `shared_prefs_constants.dart` -- thread `outputMode` from pref `aiOutputMode` (all platforms).
- Benchmark -- `BENCH_OUTPUT=grammar|schema|schemaDraft` sets/restores the pref; `outputMode` in the run record and report runs header; `finishReason` per generation and a truncated-generation rate in the report; README.
- Tests -- schema conversion via llamadart validator, mapper golden cases incl. truncated output, mode pref parsing, country detection, repository behaviour per mode with a fake data source (schema passed, no Condition on lab reports, draft call order, draft failure), report fields.
- `fhir_r4_validation` probe -- throwaway Dart project in the scratchpad depending on `fhir_r4_validation` 0.14 validating `toFhirResource` JSON samples of every type, offline; record the result in Design Notes and `doc/architecture.md`; no app dependency.
- Measurement -- generate `--seed 7 --per-cell 3` (24 docs); iOS simulator, Qwen, `BENCH_VISION=false` and `true` × `grammar|schema|schemaDraft`; `bench compare` schema vs grammar and draft vs schema; set the code default by the rule in Design Notes; record numbers in Design Notes and the README.

**Acceptance Criteria:**
- Given mode `schema` and a lab report, when phase 2 runs, then the generation request carries a `json_schema` `responseFormat` with no Condition property and no `grammar`, and the session receives the mapped resources.
- Given mode `grammar`, when any phase runs, then the request carries `GbnfGrammars.jsonArray` and no `responseFormat`.
- Given every schema the code can emit, when validated by `LlamaStructuredOutput.jsonValueSchema`, then none throws.
- Given a benchmark run, when scored, then each generation shows `finishReason` and the report shows output mode and the truncated rate.
- Given the measurement, when finished, then the spec records per-mode F1 with CIs and the chosen default, and `fvm flutter analyze` adds no warnings and `fvm flutter test` passes.

## Spec Change Log

- 2026-10-26: date pattern written `^([0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?)?$`. llamadart 0.15.6's pattern subset has no `\d` (the validator rejects it as outside the compiled subset); the class is equivalent.
- 2026-10-26: the `ExtractionOutputMode` enum lives in `lib/features/processing/domain/entity/extraction_output_mode.dart` and is re-exported by `extraction_schemas.dart`, so the domain `ProcessingRepository` interface does not import the data layer.
- 2026-10-26: after the measurement the code default is `schema`, so an unset or unknown pref now means `schema`, not `grammar` (the I/O matrix row described the pre-measurement default).

## Review Triage Log

### 2026-10-26 — Review pass
- verdicts: 38 findings — high 0, medium 6, low 27, false 3, maybe-false 2
- findings:
  - `medium` `patch` [blind] PatientPostProcessor still relabels an empty-ID `MRN` with the phone locale's label, undoing forDocument (German doc on RO phone → CNP) — confirmed at patient_post_processor.dart:24; both postProcess calls now pass `regionDefaultLabel: CountryIdentifier.forDocument(ocrText).identifierLabel`, with a repository test.
  - `low` `patch` [blind] schemaDraft joins every vision batch's draft uncapped and can overflow the 4096 text context (constrained pass rethrows "prompt too long") — DraftPrompt.section now caps the draft text, with a test.
  - `low` `reject` [blind] schemaDraft phase-1 vision fallback runs the constrained call text-only, so the image never reaches it — spec-mandated design (constrained pass text-only with draft + OCR); schemaDraft is not the default and nothing in the app writes the pref; the fix adds a branch.
  - `maybe-false` `defer` [blind] vision phase 2 now gets 2000 OCR chars + few-shot in every mode and may not fit the 2048 vision context of smaller phones — needs a phone run (or token count of the prompt + two images vs ctx) on a 6 GB device; a too-long prompt is caught per batch and falls back to text.
  - `low` `reject` [blind] the visit schema has no `observations` array, so lab values in discharge letters can only go to vitalSigns — the intent prescribes "vital-sign observations" for visit, and the old visit prompt also offered only "Observation (vital signs, measurements)".
  - `low` `reject` [blind] the visit few-shot can show a lab Observation under `vitalSigns` — structure reference only; fixing needs lab-vs-vital classification of template rows.
  - `low` `reject` [blind] truncated phase-1 output can't be salvaged and `conclusion` precedes `documentCategory` — the object is ~150 tokens against maxTokens ≥ 512, unlikely in practice; reordering changes the measured prompt.
  - `low` `reject` [blind] the default flips to `schema` everywhere with no UI to switch back — the intent authorizes the flip after measuring; the spec forbids new UI; the schema is compiled to the same llama.cpp grammar mechanism as the GBNF it replaces.
  - `low` `reject` [blind] short acronym markers (CIP, NHS…) can misfire and shared German labels pull AT/CH documents to DE — a tie falls back to the phone locale (the old behaviour); sharing DE's weak labels with AT/CH would tie every plain German document and break the main fix.
  - `low` `reject` [blind] report latency stats still pool draft calls — bench-only; drafts are real generations whose latency belongs in the run's totals.
  - `low` `reject` [blind] maxItems caps end an array silently — fix adds new logging; noted as a residual risk (observations cap 40).
  - `low` `patch` [blind] `ExtractionSchemas.identifierLabels` duplicates `PatientPostProcessor._knownLabels` — the schema enum is now derived from the post-processor's public set.
  - `low` `patch` [blind] list of changed paths without tests — grouped with the verification-gap rows below (patched or deferred there); ProcessingHandler pref reading stays a one-liner without a test.
  - `low` `patch` [blind] bench/doc inconsistencies: pref set before the try that restores it; architecture.md claims few-shot on every vision phase-2 call; RunRecord.outputMode defaults to grammar — pref set moved inside the try, doc reworded; the RunRecord default is never used (the runner always passes the mode), left as is.
  - `low` `reject` [intent] the grammar baseline is the post-change pipeline, so the prompt fixes' own effect isn't isolated — the pre-change iPhone runs (text 0.511, vision 0.405) are the reference; the iPhone confirmation run is left to the user.
  - `medium` `defer` [intent] vision accuracy with the equalised prompt was not actually measured (2–4 vision generations per simulator run) — needs the iPhone run with BENCH_VISION=true.
  - `low` `reject` [intent] schemaDraft vision changes the constrained call's modality to text — spec-mandated.
  - `low` `reject` [intent] the default flip rests on the simulator text run only — same as the blind default-flip row; the intent calls the simulator valid for accuracy.
  - `medium` `patch` [intent] tests sit below the engine surface (`engine.create` never sees `responseFormat` in a test) — grouped with the verification-gap engine row; fake-engine test added.
  - `low` `reject` [intent] item (5) is a probe recorded in prose, not a committed package test — the question is answered; a committed test would need `fhir_r4 ^0.14`, which conflicts with the app's 0.6.
  - `false` `reject` [intent] phase 1 has no container object, only flat document fields — compatible with the intent ("container (Encounter or DiagnosticReport)" is produced by containerToLegacy), and the reviewer says so.
  - `medium` `patch` [verification-gap] no test that the handler forwards `responseFormat` to `engine.create` and captures `finishReason` — fake LlamaEngine test added in generation_stats_test.dart.
  - `medium` `patch` [verification-gap] the vision few-shot/2000-char test can't detect a revert — OCR > 800 chars with a late marker, `EXAMPLE OUTPUT` and a schema-shape variant asserted.
  - `low` `patch` [verification-gap] the lab-report Condition exclusion in getBestExample is never exercised — histopathology-OCR grammar test added.
  - `low` `patch` [verification-gap] vision phase-1 forDocument hints untested — KVNR assertion added to the vision fallback test.
  - `medium` `patch` [verification-gap] the recorder's `schema`/`grammar` constraint label and `responseFormat` pass-through untested — runner_test extended.
  - `low` `defer` [verification-gap] schemaDraft vision phase 1 and container-only have no tests — unreachable in the app (no pref writer, not the default).
  - `low` `reject` [verification-gap] histopathology reports classified lab_report lose their diagnoses as Conditions — the intent says lab_report has NO Condition; the DiagnosticReport conclusion keeps the text.
  - `false` `reject` [verification-gap] nothing in the app writes `aiOutputMode` — by design: the intent asks for a switch to A/B test, the spec forbids UI; the bench sets it.
  - `low` `reject` [edge] schemaDraft vision phase 2 with no draft and empty OCR runs the constrained pass on the few-shot only — schemaDraft-only and unreachable in the app; the guard adds a branch.
  - `low` `reject` [edge] with no vision draft, schemaDraft vision phase 2 doesn't try a text draft — same reachability; adds a branch.
  - `low` `defer` [edge] cancelling during the last vision batch still runs the text fallback — pre-existing: the fallback had no cancel check before this change either.
  - `low` `reject` [edge] schemaDraft phase-1 vision constrained call has no document content when OCR < 200 and the draft is null — grouped with the blind schemaDraft phase-1 row.
  - `maybe-false` `defer` [edge] the longer vision prompt can exceed small vision contexts — grouped with the blind vision-context row.
  - `low` `patch` [edge] bench pref set before the try — grouped with the blind bench/doc row; fixed there.
  - `false` `reject` [edge] few-shot objects can exceed maxItems (> 4 practitioners / > 3 organizations) — checked every template in assets/correction_templates: none exceeds any section limit among the resources taken.
  - `low` `reject` [edge] NFD-decomposed diacritics defeat marker matching — Apple Vision and ML Kit return NFC text; a miss falls back to the phone locale.
  - `low` `patch` [edge] architecture.md says every vision phase-2 call gets the few-shot — grouped with the blind bench/doc row; reworded.

## Design Notes

Default rule (decided before measuring): `schema` becomes the code default if, on the 24-doc simulator text run, mean ΔF1(schema − grammar) ≥ 0 and its strict-JSON rate is not lower; otherwise `grammar` stays. `schemaDraft` becomes the default only if the lower CI bound of ΔF1(schemaDraft − schema) > 0. Vision runs inform but do not decide (phones default to text-only).

Measurement (2026-10-26, 24 docs `--seed 7 --per-cell 3`, Qwen3-VL-2B, iPhone 17 Pro simulator, `compare --seed 1234`):

| Run | F1 [95% CI] | Strict JSON | Truncated |
|---|---|---:|---:|
| text grammar | 0.564 [0.524, 0.603] | 95.8% | 4.2% |
| text schema | 0.602 [0.573, 0.631] | 100.0% | 0.0% |
| text schemaDraft | 0.606 [0.581, 0.633] | 100.0% | 0.0% |
| vision grammar | 0.558 [0.516, 0.599] | 93.8% | 6.3% |
| vision schema | 0.599 [0.570, 0.629] | 97.9% | 2.1% |
| vision schemaDraft | 0.597 [0.571, 0.622] | 100.0% | 0.0% |

Text ΔF1 schema − grammar +0.038 [0.006, 0.072] (P ≤ 0: 0.011); schemaDraft − schema +0.004 [−0.012, 0.020] (P ≤ 0: 0.303). Vision: +0.041 [0.006, 0.077] and −0.003 [−0.016, 0.011]. Chosen default: `schema` (ΔF1 ≥ 0 and strict JSON not lower; schemaDraft's lower bound ≤ 0). Caveat: in the simulator the iOS memory check stopped the vision batch on 20–22 of 24 documents, so the vision runs mostly exercised the text fallback.

`fhir_r4_validation` probe (scratchpad project, offline, 40 `toFhirResource` samples, 4 per type from benchmark runs): unusable as is. 0.14 needs `fhir_r4 ^0.14` and models R4B; it ships no definitions, so with its default cache every resource fails "No StructureDefinition found". With the HL7 R4/R4B `definitions.json` loaded it still needed a cache wrapper (complex types looked up by bare name; a missing terminology.hl7.org value set throws and aborts), then 32/40 failed on validator-internal errors (Reference, Period, Quantity, ContactPoint), 6 were valid, and 2 Patients showed the one real defect: `gender: "Female"`, rejected by the required binding and ruled out by the schema's gender enum. Recorded in `doc/architecture.md`.

Schema output → legacy maps: phase 1 `{familyName,…,documentTitle,documentDate,conclusion,documentCategory}` → `[{"resourceType":"Patient",…,"documentCategory":c}, c=="lab_report" ? {"resourceType":"DiagnosticReport","reportName":title,"issuedDate":date,"conclusion":…} : {"resourceType":"Encounter","encounterType":title,"periodStart":date}]`, so `_parseBasicInfoResponse` stays the single parser. Phase 2 `{"observations":[{…}],…}` → flat list with `resourceType` added per array.

## Verification

**Commands:**
- `fvm dart run build_runner build` -- expected: success
- `fvm flutter analyze` -- expected: no new issues vs baseline
- `fvm flutter test` -- expected: all pass
- `fvm flutter test integration_test/extraction_bench_test.dart -d <iPhone 17 Pro simulator> --no-uninstall --dart-define=BENCH_MODEL=qwen --dart-define=BENCH_OUTPUT=schema --dart-define=BENCH_VISION=false` -- expected: 24 records, no errors

## Auto Run Result

**Summary.** Added an `ExtractionOutputMode` (`grammar` | `schema` | `schemaDraft`, pref `aiOutputMode`, all platforms) threaded through every extraction entry point. `schema` sends a flat per-phase JSON schema as llamadart `responseFormat` (phase 1, container-only, phase 2 per category with no Condition on lab reports) and maps the object back to the legacy `resourceType` maps, salvaging truncated phase-2 output. `schemaDraft` adds an unconstrained ≤ 384-token draft before a text-only constrained pass. Prompt fixes in all modes: country hints and the post-processor's default ID label from the document (`CountryIdentifier.forDocument`), vision phase 2 with 2000 OCR chars + few-shot, lab-report prompts without Condition. `finishReason` is recorded per generation; the benchmark gained `BENCH_OUTPUT`, `outputMode`, a constraint label and a truncated rate. Measured on 24 documents in the iOS simulator: text F1 grammar 0.564 → schema 0.602 (ΔF1 +0.038 [0.006, 0.072]), schemaDraft +0.004 over schema (CI crosses 0), so the code default is now `schema`. `fhir_r4_validation` probed and not adopted.

**Files changed.**
- `lib/features/processing/domain/entity/extraction_output_mode.dart` (new) — the mode enum, `fromPref`, default `schema`.
- `lib/features/processing/data/model/structured_output/extraction_schemas.dart` (new) — schemas, prompt shapes, salvage and mappers.
- `lib/features/processing/data/model/prompt_template/draft_prompt.dart` (new) — draft prompts and the capped draft section.
- `lib/features/processing/data/repository/ai_extraction_repository.dart` — modes, draft pass, equalised vision prompt, document-based default ID label.
- `lib/features/processing/data/model/prompt_template/{basic_info_prompt,basic_info_vision_prompt,remaining_resources_vision_prompt,correction_template_loader}.dart` — schema-shape prompts, forDocument hints, no Condition on lab reports, object-shape few-shot.
- `lib/features/processing/data/data_source/network/{ai_inference_data_source,ai_inference_handler}.dart`, `lib/features/processing/data/model/generation_stats.dart` — `responseFormat` to `engine.create`, `finishReason` captured.
- `lib/features/processing/data/utils/patient_post_processor.dart` — `knownLabels` public, the schema enum's source.
- `lib/core/config/constants/{country_identifier,shared_prefs_constants}.dart` — document country detection, `aiOutputMode` key.
- `lib/features/processing/{domain/repository/processing_repository,data/repository/processing_repository_impl,presentation/bloc/handlers/processing_handler}.dart` — mode threaded from the pref.
- `integration_test/extraction_bench_test.dart`, `integration_test/extraction_bench/{document_runner,recording_data_source,run_record}.dart` — `BENCH_OUTPUT`, pref set/restore inside the try, constraint and finishReason recorded.
- `tool/extraction_bench/src/{dataset,report}.dart`, `tool/extraction_bench/README.md` — output modes, truncated rate, drafts out of the JSON rates, measurement section.
- `doc/architecture.md` — output modes, shared prompt fixes, fhir_r4_validation probe result.
- Tests: `test/features/processing/{extraction_schemas_test,output_mode_repository_test}.dart` (new), `test/features/processing/remaining_resources_fallback_test.dart`, `test/extraction_bench/{generation_stats_test,report_test,runner_test}.dart`.

**Review findings.** 38 findings (high 0, medium 6, low 27, false 3, maybe-false 2).
- Patched (10 fixes, covering 4 medium and 8 low triage rows): post-processor default label from the document (medium); fake-engine test for `responseFormat`/`finishReason` (medium); vision few-shot/2000-char test that detects a revert (medium); recorder constraint-label and pass-through test (medium); lab-report Condition exclusion test; vision phase-1 KVNR assertion; draft section capped at 1600 chars; bench pref set moved inside the restoring try; architecture.md wording on schemaDraft's vision draft; schema identifier enum derived from `PatientPostProcessor.knownLabels`.
- Deferred (4): vision context fit of the longer vision prompt on small phones (medium, unverified); vision accuracy unmeasured in the simulator (medium); schemaDraft vision phase-1 / container-only tests (low); cancel during the last vision batch still runs the text fallback (low, pre-existing).
- Rejected (24), with reasons in the triage log: schemaDraft text-only constrained pass in vision (spec-mandated, unreachable in the app); visit has no lab-observation array (intent prescribes vital signs; old prompt the same); visit few-shot Observation under vitalSigns (structure reference only); phase-1 truncation salvage (unlikely at ≥ 512 tokens); default flip without UI (intent authorizes, spec forbids UI); country marker misfires (ties fall back to the old locale behaviour); report latency pools drafts (bench-only); silent maxItems caps (new logging; residual risk); RunRecord default (never used); grammar baseline is post-change (iPhone pre-change runs are the reference); draft modality, default flip on simulator only (duplicates/spec); fhir_r4_validation as prose (version conflict); histopathology lab reports lose Conditions (intent: no Condition on lab_report); no pref writer (by design); schemaDraft empty-draft cases ×2 and the phase-1 vision duplicate (unreachable in the app); NFD diacritics (OCR returns NFC); false: container modelling, maxItems in few-shot (checked every template), no pref writer.

**Follow-up review recommended: true** (first pass, 4 medium entries patched; patched counts: high 0, medium 4, low 8 rows). Named risk: the document-based default ID label now changes every phase-1 result whose ID is empty, in all modes, and was not re-run on the 24-document benchmark (only unit tests and a 1-document simulator smoke run).

**Verification.**
- `fvm dart run build_runner build` — success.
- `fvm flutter analyze` — 0 errors, 484 issues, identical to the baseline list (one new info from the patches fixed).
- `fvm flutter test` — 162 passed.
- Simulator bench (iPhone 17 Pro, Qwen, `BENCH_OUTPUT=schema`, `BENCH_VISION=false`): the six 24-document measurement runs (text and vision × three modes), 24 records each, no errors; after the review patches a 1-document smoke run (`review-smoke`, de-dis-001): 2 schema generations, strict JSON, finishReason `stop`, 14 resources.
- I/O matrix: every row covered by a passing test; the "pref missing → grammar" row describes the pre-measurement default, and the code follows the contract's Approach ("set the default from the result"), as recorded in the Spec Change Log.

**Residual risks.**
- Vision is unmeasured on a phone; the longer vision prompt may push small-context phones to the text fallback more often.
- `observations` is capped at 40 items; a larger lab panel loses the rest silently.
- Histopathology reports classified `lab_report` keep their diagnosis only in the conclusion.
- Desktop now defaults to `schema` too, unmeasured there.
- An Austrian or Swiss document without its ID name can get German hints.
