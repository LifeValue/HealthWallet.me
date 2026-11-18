---
title: 'On-device document→FHIR extraction benchmark harness'
type: 'feature'
created: '2026-10-22'
status: 'done'
baseline_revision: '52505362fc7701e9b47f5accf44ed3b43c0c4814'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/research/technical-on-device-document-to-fhir-extraction-2026-10-22/research.md'
  - '{project-root}/doc/architecture.md'
warnings: [multiple-goals, oversized]
deferred:
  - summary: >-
      The app codes the orthopedics encounter specialty as SNOMED 394609007 (General surgery) instead of 394801008 (Trauma and orthopedics).
    evidence: |-
      lib/features/home/domain/entities/medical_specialty.dart:98 sets snomedSpecialtyCode '394609007' for orthopedics; the benchmark gold uses 394801008, so a correct extraction cannot earn the code tier. Pre-existing app bug surfaced by the benchmark.
    location: >-
      lib/features/home/domain/entities/medical_specialty.dart:98
    severity: medium
  - summary: >-
      A generation that never returns blocks the whole benchmark run (testWidgets uses Timeout.none, no per-document limit).
    evidence: |-
      Unverified: no hang has been observed. Settle by running long device benchmarks; if a native stall occurs, wrap runBenchDocument in a per-document timeout that records an error.
    location: >-
      integration_test/extraction_bench_test.dart
    severity: medium (unverified)
  - summary: >-
      mtmd log records may reach the Dart handler after the generation's finally clears the current log, losing imageEncodeMs.
    evidence: |-
      Unverified: encode lines are emitted during prefill, seconds before completion, so ordering is probably fine. Settle with a real vision run and check imageEncodeMs is non-null.
    location: >-
      integration_test/extraction_bench/recording_data_source.dart
    severity: medium (unverified)
  - summary: >-
      llama.cpp's mtmd helper may print its timing lines with fprintf instead of the llama log callback, so LlamaLogging never forwards them.
    evidence: |-
      Unverified: the regexes are tested only on hand-written strings. Settle with one real vision run under llamadart 0.15.6; if imageEncodeMs stays null, the report shows n/a (never wrong numbers).
    location: >-
      integration_test/extraction_bench/recording_data_source.dart
    severity: medium (unverified)
  - summary: >-
      Peak RSS may not include Metal/GPU or unified-memory allocations, understating peak RAM on Apple and GPU devices.
    evidence: |-
      Unverified. Settle by comparing ProcessInfo.currentRss against Xcode memory gauge / Instruments during a vision run on iOS and macOS.
    location: >-
      integration_test/extraction_bench/document_runner.dart
    severity: medium (unverified)
  - summary: >-
      The runner has not been executed end to end with a model (acceptance criterion 5); only its fail-fast path ran.
    evidence: |-
      No GGUF model is present on the build machine and its disk is 97% full. Settle by downloading Qwen3-VL-2B into the app container and running the BENCH_LIMIT=2 command from the Verification section.
    location: >-
      integration_test/extraction_bench_test.dart
    severity: medium (unverified)
  - summary: >-
      Table cells on generated pages are placed at fixed column offsets without a width check, so a long value could overlap the next column.
    evidence: |-
      Unverified: rendered de-lab-001 and es-dis-001 pages show no overlap. Settle by asserting each cell's text width against its column gap across a large seed range.
    location: >-
      tool/extraction_bench/src/generator.dart
    severity: medium (unverified)
  - summary: >-
      getPerformanceContext() is awaited after every production generation without a timeout; a busy worker could delay returning the result.
    evidence: |-
      Unverified: the worker is idle after the stream ends. Settle by checking llamadart's getPerformanceContext path for blocking, or add a short timeout.
    location: >-
      lib/features/processing/data/data_source/network/ai_inference_handler.dart
    severity: high (unverified)
---

<intent-contract>

## Intent

**Problem:** We cannot measure how accurately the on-device pipeline (native OCR → llamadart vision/text phases → `MappingResource.toFhirResource`) turns medical documents into FHIR R4, so every model, runtime, schema or LoRA decision in the research (Rec 3, §D4) is unmeasurable.

**Approach:** One CLI `fvm dart run tool/extraction_bench/bench.dart` with `generate`, `score` and `compare` subcommands (pure Dart, no Flutter imports), plus a Flutter `integration_test` runner that executes the real production pipeline on a desktop or device and writes one prediction record per document. Ground truth is a FHIR R4 Bundle per document; scoring is ExtractBench-style Hungarian matching with FHIR-aware comparators and document-level bootstrap statistics.

## Boundaries & Constraints

**Always:**
- The runner uses the production classes unchanged in behaviour: `AiInferenceDataSourceImpl`, `ProcessingRepositoryImpl.mapBasicInfo` / `mapRemainingResources`, the native OCR channel, `PdfConversionMixin.convertPdfToImages`. It mirrors `ProcessingHandler`'s sequencing: phase 1, then `docCategory` = `lab_report` if the container is a `MappingDiagnosticReport` else `visit`, then phase 2 with `useVision` from the `BENCH_VISION` define (default `true`). Predicted FHIR = `toFhirResource(subjectId: 'bench-patient', encounterId: 'bench-container').rawResource` for the patient, the container and every phase-2 resource.
- Dataset and results live under `<applicationDocumentsDirectory>/extraction_bench/` on every platform (`dataset/` in, `results/<runId>/predictions.jsonl` out); the macOS debug build is sandboxed, so host paths are not readable.
- Generator output is deterministic for a given `--seed`: byte-identical `gold.json` and `meta.json`, identical rendered text.
- Every scored gold value is printed on its document in that document's language and local formatting (decimal comma for es/de/ro, localized date formats and section labels).
- Statistics: per-document micro-F1, then the mean across documents; 95% percentile bootstrap CIs over documents (B=10000, `--seed`, default 1234); paired over shared docIds for `compare`.
- A document that is in the dataset but missing from predictions, or whose pipeline threw, scores with empty predictions and is counted in an `errors` / `missing` tally; it is never dropped.
- Image-encode time comes only from llama.cpp's native mtmd log lines; when none are seen the value is `null` and the report shows "n/a". Never estimate it.
- New strings are developer-facing CLI/report text only (no ARB changes). Benchmark code stays out of `lib/` except the stats seam below.

**Never:**
- Commit dataset, results, models or any real document; the real hold-out lives outside the repo (or under gitignored `build/`).
- Mocks, network calls, LLM-as-judge, Python or Synthea dependencies; the FHIR validator pass (`fhir_r4_validation`, R4B) is out of scope.
- Changes to prompts, grammars, model configs or pipeline behaviour (the schema work is Rec 2, a separate spec).
- Production logging changes: only the runner calls `LlamaLogging.configure`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Exact match | pred field == gold field | TP +1 | — |
| Correct null | field absent in both, on a matched pair | TP +1 (credit) | — |
| Hallucinated field/record | pred value, gold null; or unmatched pred record | FP per non-null pred field | — |
| Omitted field/record | gold value, pred null; or unmatched gold record | FN per non-null gold field | — |
| Partial score s∈(0,1) | e.g. date at coarser precision | TP +s, FP +(1−s), FN +(1−s) | — |
| Convertible units | gold 13.5 g/dL, pred 135 g/L | score 1 | — |
| Unknown unit pair | gold 5 mmol/L, pred 90 mg/dL | 1 only if value and normalized unit text both equal, else 0 | — |
| Unparseable model output | raw output not strict JSON | generation `strictJsonValid=false`; doc scored on what the pipeline salvaged | — |
| Pipeline throws | exception during a doc | record with `error`, empty predictions | runner continues with the next doc |
| Missing model files | `BENCH_MODEL` files absent | runner fails before the first doc, naming the expected paths | test fails |
| Missing glyph | font lacks a char the generator needs | generator exits non-zero naming the char | no partial dataset written |

</intent-contract>

## Code Map

- `lib/features/processing/data/repository/ai_extraction_repository.dart` -- `processMapBasicInfo` :196 (OCR, text fast path ≥200 chars, vision fallback), `processMapRemainingResources` :369 (vision batches of 2, text fallback :452, `ObservationOcrValidator` :491). Read-only.
- `lib/features/processing/data/repository/processing_repository_impl.dart` -- `mapBasicInfo` :383, `mapRemainingResources` :400; constructor `(AiInferenceDataSource, ProcessingLocalDataSource, TextRecognitionService, PathResolver)` (DI: `lib/core/di/injection.config.dart:398`).
- `lib/features/processing/data/data_source/network/ai_inference_data_source.dart` -- interface + `AiInferenceDataSourceImpl(SharedPreferences)`; model paths `<docs>/ai_models/<modelId>` :248-267; `initModel`, `checkMemoryHealth`.
- `lib/features/processing/data/data_source/network/ai_inference_handler.dart` -- `runVisionPromptImpl` / `runTextPromptImpl` stream `engine.create`; the final chunk carries `usage` (`LlamaGenerationUsage{promptTokens, completionTokens, timeToFirstToken, duration}`, llamadart `completion_chunk.dart:129`); `engine.getPerformanceContext()` gives `promptEvalMs`, `evalMs`.
- `lib/core/config/constants/ai_model_config.dart` -- variants `qwen`, `medGemma`, `qwen7b`; selected via prefs key `SharedPrefsConstants.aiSelectedModel`.
- `lib/features/processing/domain/entity/mapping_resources/*.dart` -- `toFhirResource` per type. Only Patient identifier, Encounter specialty and vital-sign Observations carry codes; the rest are text-only `CodeableConcept`s, so the text tier of code credit matters most.
- `lib/features/processing/data/services/pdf_conversion_mixin.dart` -- `convertPdfToImages` (Printing.raster, 200 dpi).
- llamadart `lib/src/core/llama_logging.dart` -- `LlamaLogging.configure(level:, nativeLevel:, handler:)` forwards native llama.cpp lines (mtmd: `image slice encoded in N ms`, `image decoded (batch i/n) in N ms`).
- `test/widget_test.dart` -- fake pattern (`extends Fake implements X`, `SharedPreferences.setMockInitialValues`).
- `assets/font/matter-font/Matter-Regular.ttf` / `Matter-Bold.ttf` -- generator fonts; verified to cover ș ț ă î â ä ö ü ß ñ á é í ó ú ¿ ¡ µ ° ≤ ≥ ± ×.

## Tasks & Acceptance

**Execution:**
- `lib/features/processing/data/model/generation_stats.dart` + `ai_inference_handler.dart` + `ai_inference_data_source.dart` -- add a Freezed `GenerationStats{mode, promptTokens, completionTokens, timeToFirstTokenMs, promptEvalMs, durationMs}`, filled from the final chunk's `usage` and the perf context, and expose `GenerationStats? get lastGenerationStats` on the interface (reset at the start of each call). This is the only production seam; behaviour is otherwise unchanged.
- `tool/extraction_bench/src/codes.dart` -- curated tables with displays in en/es/de/ro: ~20 LOINC labs (UCUM unit, plausible range), ~15 conditions (SNOMED + ICD-10), ~15 medications (ATC + RxNorm ingredient, dosage patterns), allergens, procedures, synthetic name pools and identifier schemes (MRN / DNI / Versichertennummer / CNP).
- `tool/extraction_bench/src/generator.dart` -- seeded families `lab_report` (Patient, DiagnosticReport, 6–12 Observations, Practitioner, Organization) and `discharge_letter` (Patient, Encounter, 1–3 Conditions with full or partial onset dates, 2–4 MedicationStatements, 0–2 AllergyIntolerances, 0–1 Procedure, 2–4 vital Observations, Practitioner, Organization). Exposes each doc's rendered lines through its library API (used by the gold-on-document test). Writes `<out>/synthetic/<docId>/{document.pdf, gold.json (Bundle type collection), meta.json{docId, split, lang, family, degradation ∈ clean|scan|photo, seed, generatorVersion}}` and `<out>/manifest.json`. Fails fast on a missing glyph.
- `tool/extraction_bench/src/fields.dart` + `comparators.dart` -- per-type field spec (candidate JSON paths + comparator): text (case/diacritic/whitespace fold; equal → 1, token Jaccard ≥0.5 → Jaccard, else 0), exact, identifier (strip spaces and dashes), date (same precision and equal → 1; one a prefix of the other → 0.5), quantity (UCUM normalization: prefixes, µ/u, `x10^9/L` → `10*9/L`, mass/volume/length/temperature conversions, relative tolerance 1e-3), set (Jaccard for `given[]`, `coding[]`), concept (any coding system+code equal → 1; gold-listed alternative codes → 0.75; display/text match → 0.5 × text score; else 0).
- `tool/extraction_bench/src/hungarian.dart` + `scoring.dart` -- rectangular Kuhn–Munkres per resource type with cost Σ(1−field score); TP/FP/FN accounting per the matrix; per doc: micro P/R/F1, omission rate (FN fields / gold non-null fields), hallucination rate (FP fields from pred non-null / pred non-null fields).
- `tool/extraction_bench/src/report.dart` + `bootstrap.dart` -- `report.json` + `report.md`: overall and per stratum (split, lang, family, degradation), per resource type, F1/P/R with CIs, omission and hallucination rates, generation strict-JSON validity rate, error/missing counts, latency median/p90 (TTFT, promptEval, imageEncode, wall per doc), peak RSS. `compare`: paired bootstrap of the doc-F1 difference (B), CI and P(diff ≤ 0), overall and per stratum.
- `tool/extraction_bench/bench.dart` -- `args`-based CLI: `generate --out --seed --per-cell --langs --families`; `score --dataset --predictions --out [--seed]`; `compare --dataset --a --b --out [--seed]`; `oracle --dataset --out` writes a predictions.jsonl whose `predictedResources` are each doc's gold resources (sanity baseline). Non-zero exit with a message on bad input.
- `integration_test/extraction_bench_test.dart` + `integration_test/extraction_bench/{recording_data_source.dart, degradation.dart, run_record.dart}` -- defines `BENCH_MODEL` (variant name, required), `BENCH_VISION`, `BENCH_RUN_ID`, `BENCH_LIMIT`, `BENCH_COOLDOWN_S` (default 0). Wires `ProcessingRepositoryImpl` with a recording decorator around `AiInferenceDataSourceImpl` (raw output, strict-JSON flag, `lastGenerationStats`, imageEncodeMs parsed from native logs) and the getIt-provided other dependencies. Rasterizes PDFs (or takes `page-*.png|jpg` for real docs), applies a seeded degradation (`scan`: ±2° rotation, blur, noise, JPEG q60; `photo`: rotation, brightness gradient, JPEG q70), samples `ProcessInfo.currentRss` every 250 ms, and appends one JSONL record per doc `{docId, runId, model, platform, predictedResources, generations[], peakRssBytes, wallMs, error?}`.
- `pubspec.yaml` -- add `integration_test: {sdk: flutter}` and `args` to dev_dependencies.
- `test/extraction_bench/*_test.dart` -- unit tests for every I/O-matrix row, the Hungarian optimum on known matrices, UCUM conversions, bootstrap determinism (identical runs → diff 0, CI [0,0]), generator determinism, and gold-on-document.
- `tool/extraction_bench/README.md` + `doc/architecture.md` -- usage per platform (copying into the macOS container / `adb push` with `run-as` / `xcrun devicectl`), the real hold-out layout `real/<docId>/{page-*.jpg|document.pdf, gold.json, meta.json}`, and the de-identification rule.

**Acceptance Criteria:**
- Given `bench.dart generate --seed 7 --per-cell 2`, when it is run twice, then both outputs are byte-identical and contain 2 × 4 langs × 2 families = 16 docs, each `gold.json` parsing with `fhir_r4` `Bundle.fromJson`.
- Given a generated doc, when its rendered text is checked, then every scored gold scalar appears in its localized form.
- Given `oracle` predictions for a generated dataset, when `score` runs, then the mean F1 is 1.0, the omission and hallucination rates are 0, and `report.md` lists every stratum.
- Given two predictions files, when `compare` runs with the same seed twice, then the outputs are identical.
- Given a dataset in the app container and the model files present, when `fvm flutter test integration_test/extraction_bench_test.dart -d macos --dart-define=BENCH_MODEL=qwen --dart-define=BENCH_LIMIT=2` runs, then `predictions.jsonl` has 2 records with generations, TTFT, promptEval and peak RSS, and `score` produces a report from it.

## Spec Change Log

## Review Triage Log

### 2026-10-22 — Review pass
- verdicts: 49 findings — high 1, medium 15, low 19, false 6, maybe-false 8
- findings:
  - `medium` `patch` IA1: README/fields.dart claim a perfect pipeline reaches 1.0, but coded gold concepts cap text-only predictions at 0.5 — docs corrected to describe a fixed FHIR-truth scale (grouped with BH2).
  - `false` `reject` IA2: unlisted resource types are dropped from scoring — the pipeline only emits the 10 MappingResource types, all of which have field specs.
  - `low` `patch` IA3: omission and hallucination rates have no CIs — added to the same document bootstrap.
  - `false` `reject` IA4: latency/RSS not split by platform or model — each predictions file is one run (one model, one platform); devices are compared across reports.
  - `low` `reject` IA5: no real-shaped dataset scored in tests — real docs use the same loader and scoring path; the runner test now exercises a `real/` page-image doc.
  - `low` `reject` IA6: gold-on-document checks rendered lines, not PDF text — verifying PDF text needs an extraction dependency; rendered pages were inspected visually.
  - `medium` `patch` IA7: production stats seam untested — unit test for buildGenerationStats added (grouped with VG3).
  - `maybe-false` `defer` IA8: mtmd lines may not reach LlamaLogging — settle with one real vision run.
  - `maybe-false` `defer` IA9: RSS may exclude GPU memory — settle against Instruments.
  - `maybe-false` `defer` IA10: runner never run with a model — no model on this machine, disk 97% full.
  - `false` `reject` IA11: upgrade described as uncommitted — committed as 7c74be72 with the user's approval before the run; changes kept.
  - `medium` `patch` VG1: compare not tested with differing coverage — test added.
  - `medium` `patch` VG2: stratum assertion satisfied by Documents table — strata/resourceTypes assertions added.
  - `medium` `patch` VG3: lastGenerationStats seam untested — unit test added (grouped with IA7).
  - `medium` `patch` VG4: field-spec contract pinned for 5 of 10 types — remaining 5 types added.
  - `medium` `patch` VG5: visit branch and later-line-wins untested — tests added.
  - `medium` `patch` BH1: token-set text compare scores wrong dosages (1-0-0 vs 1-0-1) as equal — the gold's numbers must now appear in order among the prediction's (an exact-sequence rule first applied was relaxed so a printed ICD code in the prediction does not zero the score).
  - `medium` `patch` BH2: perfect-pipeline claim false — see IA1.
  - `false` `reject` BH3: BENCH_VISION defaults to true while mobile production defaults to text — deliberate: the benchmark measures VLM extraction on every platform, documented, and BENCH_VISION=false reproduces the mobile default.
  - `low` `reject` BH4: degradation not crossed with cells, pixels differ per platform rasterizer — same-platform model comparisons are unaffected; the fix is host-side rendering, a redesign.
  - `medium` `patch` BH5: generate writes into a non-empty --out — see EC7.
  - `low` `reject` BH6: mixed runs, mappingErrors/imageDecodeMs/useVision not in report — documented append semantics; raw values stay in predictions.jsonl.
  - `medium` `patch` BH7: latency pools vision and text generations — per-mode distributions added (the model is reloaded per phase by the pipeline itself, so there is no single cold start).
  - `maybe-false` `defer` BH8: cells may overflow columns — see EC12.
  - `high` `patch` BH9: README lacks a warning that device runs install a debug build under the production id, uninstalling a store build with real data — warning added.
  - `low` `patch` BH10: G/M/T prefixes and phone formats with / ( ) . unsupported — added.
  - `low` `reject` BH11: no blood pressure in vitals — coverage gap; needs a component comparator, follow-up work.
  - `low` `reject` BH12: no resume of an interrupted run — feature request.
  - `low` `patch` BH13a: ro license doc says 7–9 digits, produces 6 — doc corrected.
  - `low` `patch` BH13b: README says all phone numbers are invented, es/ro are random — wording corrected.
  - `low` `patch` BH13c: isStrictJson accepts null and scalars — now requires List or Map.
  - `low` `reject` BH13d: formatDecimal never prints fixed precision — realism detail, no scoring impact.
  - `low` `patch` EC1: page-* images sorted lexicographically — numeric sort.
  - `maybe-false` `defer` EC2: a hung generation blocks the run — no hang observed.
  - `false` `reject` EC3: malformed meta.json aborts the run — it fails loudly before the loop, which is correct for bad input.
  - `maybe-false` `defer` EC4: log records may arrive after _current is cleared — encode lines are emitted at prefill.
  - `medium` `patch` EC5: Hungarian can pick a non-agreeing cheap pair over an agreeing one — non-agreeing pairs now get a large cost before solving.
  - `medium` `patch` EC6: app sets DiagnosticReport.issued = now when the date is missing, scoring omissions as wrong values — runner drops `issued` when issuedDate does not parse.
  - `medium` `patch` EC7: generate into an existing dataset keeps stale docs — non-empty --out refused (grouped with BH5).
  - `low` `patch` EC8: empty/duplicate --langs/--families accepted — rejected.
  - `low` `reject` EC9: wrong-typed JSON fields raise TypeError — runner-written files; loud failure; guards add complexity.
  - `medium` `defer` EC10: app codes orthopedics as 394609007 (General surgery) — pre-existing app bug; gold 394801008 is correct.
  - `low` `patch` EC11: README adb run-as quoting breaks && — command quoted.
  - `maybe-false` `defer` EC12: RowBlock cells unchecked for width — rendered samples show no overlap.
  - `low` `reject` EC13: degradation noise uses math.Random — SDK pinned via FVM; fix needs a custom noise loop.
  - `maybe-false` `defer` EC14: getPerformanceContext may block production after generation — worker idle after stream ends.
  - `low` `reject` EC15: codeless gold concepts compared at full text weight, spec says 0.5× — fix would edit the spec; full weight is the only way a codeless concept can match.
  - `low` `reject` EC16: coding[] compared by concept tiers, not Jaccard — fix would edit the spec; any-shared-code is order-insensitive set semantics.
  - `false` `reject` EC17: missing-model row has no unit test — covered by the integration runner, which ran and failed fast as specified.

## Design Notes

- **In-house generator instead of Synthea:** Synthea is Java, US-only, and a German study matched only 7 of 16 of its resource types to German core profiles without conversion (research §D2). Our exact-truth generator gives the same property as VAREX: the gold is by construction what is printed.
- **Dart reimplementation instead of the Python ExtractBench evaluator:** it keeps the toolchain single-language and testable under `fvm flutter test`; the methodology (Hungarian matching, correct-null credit, per-document micro-F1) follows LlamaIndex ExtractBench.
- The runner skips `ProcessingHandler`'s OCR pre-match against existing records, since the benchmark has no records repository; this is documented in the README.

## Verification

**Commands:**
- `fvm flutter analyze` -- expected: no new errors or warnings versus the branch base.
- `fvm flutter test` -- expected: all tests pass, including `test/extraction_bench/`.
- `fvm dart run tool/extraction_bench/bench.dart generate --out build/extraction_bench/dataset --seed 7 --per-cell 2` then `oracle` and `score` on its output -- expected: mean F1 1.0.
- `fvm flutter test integration_test/extraction_bench_test.dart -d macos --dart-define=BENCH_MODEL=qwen --dart-define=BENCH_LIMIT=2` -- expected: 2 records; when the model is absent, a fast failure naming the expected paths.

## Auto Run Result

Status: done

**Summary.** Built the document→FHIR extraction benchmark harness (research Rec 3 / §D4):
- A pure-Dart CLI (`generate`, `oracle`, `score`, `compare`).
- A Flutter `integration_test` runner that drives the production pipeline on a desktop or device.
- One production seam, `AiInferenceDataSource.lastGenerationStats`.

**Files changed.**
- `lib/features/processing/data/model/generation_stats.dart` (new): Freezed `GenerationStats` and `GenerationMode`.
- `lib/features/processing/data/data_source/network/ai_inference_handler.dart`: captures the final chunk's `usage` plus the perf context into `lastGenerationStats`, reset per call.
- `lib/features/processing/data/data_source/network/ai_inference_data_source.dart`: `lastGenerationStats` getter on the interface.
- `tool/extraction_bench/bench.dart`: the CLI entry point; validates input (non-empty `--out` refused, empty or duplicate langs/families rejected).
- `tool/extraction_bench/src/codes.dart`: LOINC, SNOMED, ICD-10, ATC/RxNorm, allergen and procedure tables in en/es/de/ro, plus name pools and identifier schemes.
- `tool/extraction_bench/src/generator.dart`: seeded lab reports and discharge letters, rendered to PDF with the Matter font, with a gold FHIR Bundle and meta.
- `tool/extraction_bench/src/formats.dart`: localized dates and decimals.
- `tool/extraction_bench/src/rng.dart`: mulberry32/FNV-1a deterministic RNG.
- `tool/extraction_bench/src/fields.dart`: scored field spec per resource type.
- `tool/extraction_bench/src/comparators.dart`: text, exact, identifier, date, quantity (UCUM), set and concept comparators.
- `tool/extraction_bench/src/hungarian.dart`: rectangular Kuhn–Munkres.
- `tool/extraction_bench/src/scoring.dart`: per-type matching, TP/FP/FN with correct-null credit, omission and hallucination.
- `tool/extraction_bench/src/bootstrap.dart`: document bootstrap and paired bootstrap.
- `tool/extraction_bench/src/report.dart`: report.json/md (strata, resource types, CIs, latency per mode, RSS), compare, oracle.
- `tool/extraction_bench/src/dataset.dart`: dataset and predictions loaders.
- `tool/extraction_bench/README.md`: workflow, per-platform copying, a data-safety warning, the real hold-out layout and de-identification rule, scoring rules.
- `integration_test/extraction_bench_test.dart`: the runner entry (defines, model fail-fast, wiring, page ordering).
- `integration_test/extraction_bench/document_runner.dart`: per-document pipeline run mirroring `ProcessingHandler`, mapping, `issued` fix-up, RSS sampling.
- `integration_test/extraction_bench/recording_data_source.dart`: recording decorator (raw output, strict JSON, stats, mtmd image-encode times).
- `integration_test/extraction_bench/degradation.dart`: seeded scan/photo degradation.
- `integration_test/extraction_bench/run_record.dart`: the JSONL record.
- `test/extraction_bench/*.dart`: scoring, comparators, UCUM, Hungarian, generator determinism, gold-on-document, report/compare, runner, degradation and generation-stats tests.
- `pubspec.yaml` / `pubspec.lock`: dev dependencies `integration_test`, `args`, `pdf`.
- `doc/architecture.md`: extraction benchmark section and updated test count.

**Review findings breakdown.** 49 findings: high 1, medium 15, low 19, false 6, maybe-false 8.
- **Patched (24 rows, 19 entries):**
  - high: BH9.
  - medium (entries): IA1/BH2, IA7/VG3, VG1, VG2, VG4, VG5, BH1, BH7, EC5, EC6, EC7/BH5.
  - low: IA3, BH10, BH13a, BH13b, BH13c, EC1, EC8, EC11.
- **Deferred (9 rows, 8 frontmatter items):**
  - EC10: the app codes orthopedics as SNOMED 394609007 (General surgery); medium, pre-existing.
  - Unverified: IA8, IA9, IA10, BH8/EC12, EC2, EC4, EC14.
- **Rejected:**
  - IA2 (false): only the 10 mapped types exist.
  - IA4 (false): one run per file.
  - IA5 (low): same code path as synthetic.
  - IA6 (low): needs PDF text extraction; pages inspected visually.
  - IA11 (false): the upgrade was committed with approval.
  - BH3 (false): vision is the default on purpose, and the define reproduces the mobile default.
  - BH4 (low): a redesign; same-platform comparisons are unaffected.
  - BH6 (low): documented; raw data stays in the JSONL.
  - BH11 (low): blood pressure needs a component comparator; follow-up.
  - BH12 (low): resume is a feature request.
  - BH13d (low): realism only.
  - EC3 (false): loud failure on bad input.
  - EC9 (low): runner-written files.
  - EC13 (low): SDK pinned.
  - EC15 and EC16 (low): the fix would edit the spec.
  - EC17 (false): the integration runner ran and failed fast.

**Follow-up review recommendation: true.** This pass patched 1 high and 11 medium entries.
- Unverified risk: the runner has not run end to end with a model, so these are untested against real llamadart 0.15.6 output:
  - `lastGenerationStats` values;
  - the mtmd image-encode log capture;
  - peak RSS;
  - the `issued` fix-up.

**Verification performed.**
- `fvm flutter analyze`: no new issues compared with the baseline (484 pre-existing infos/warnings, unchanged set).
- `fvm flutter test`: 119 tests pass.
- `bench.dart generate --seed 7 --per-cell 2`: 16 documents. A second run into the same `--out` is refused with exit 1. `oracle` then `score` gives mean F1 1.0000 [1.0000, 1.0000] over 16 documents.
- `fvm flutter test integration_test/extraction_bench_test.dart -d macos --dart-define=BENCH_MODEL=qwen --dart-define=BENCH_LIMIT=2`: prints the documents directory and fails fast naming the missing model files. No model was present for a full run.
- Rendered `de-lab-001` and `es-dis-001` pages were inspected: legible, localized, no overlap.

**Residual risks.**
- Acceptance criterion 5 (a 2-document macOS run with a model) is unverified.
- The text-only predictions the app produces earn at most 0.5 on coded concepts by design. Absolute F1 is therefore low; compare runs, not absolute numbers.
- `pubspec.yaml` still carries the temporary `dependency_overrides: fhir_r4` until `fhir_ips_export` is pushed.

