# Extraction benchmark

Measures how accurately the on-device pipeline (native OCR → llamadart phase 1 and phase 2 → `MappingResource.toFhirResource`) turns medical documents into FHIR R4. Background and method: research report §D4 and Recommendation 3 (`_bmad-output/planning-artifacts/research/technical-on-device-document-to-fhir-extraction-2026-10-22/research.md`).

Three parts:

| Part | Where | Runs on |
|---|---|---|
| Generator, scorer, comparison (`generate`, `oracle`, `score`, `compare`) | `tool/extraction_bench/bench.dart`, `src/` | Host, pure Dart: `fvm dart run` |
| Runner: the production pipeline over a dataset | `integration_test/extraction_bench_test.dart`, `integration_test/extraction_bench/` | The app on a desktop or device: `fvm flutter test` |
| Unit tests | `test/extraction_bench/` | `fvm flutter test test/extraction_bench` |

Datasets, results, models and real documents are never committed. Keep them under the gitignored `build/` or outside the repository.

> **Warning: run the runner only on a dedicated device, simulator or Mac user account with no real health data.** `fvm flutter test -d <device>` installs a debug build under the production id `com.techstackapps.healthwallet`. On a phone that has the store build, installing it replaces that build and deletes its data, real health records included; on any target the runner then opens the app's real database and preferences (it sets the selected AI model and restores it afterwards).

## Workflow

```bash
# 1. Generate a synthetic dataset (deterministic for a seed)
fvm dart run tool/extraction_bench/bench.dart generate --out build/extraction_bench/dataset --seed 7 --per-cell 10

# 2. Scorer self-check: gold as predictions must score F1 1.0 (this says nothing about the pipeline)
fvm dart run tool/extraction_bench/bench.dart oracle --dataset build/extraction_bench/dataset --out build/extraction_bench/oracle
fvm dart run tool/extraction_bench/bench.dart score --dataset build/extraction_bench/dataset \
  --predictions build/extraction_bench/oracle/predictions.jsonl --out build/extraction_bench/oracle-report

# 3. Copy the dataset into the app's documents directory (see "Per platform"), then run the pipeline
fvm flutter test integration_test/extraction_bench_test.dart -d macos --dart-define=BENCH_MODEL=qwen

# 4. Copy results/<runId>/predictions.jsonl back to the host and score it
fvm dart run tool/extraction_bench/bench.dart score --dataset build/extraction_bench/dataset \
  --predictions build/extraction_bench/results/<runId>/predictions.jsonl --out build/extraction_bench/reports/<runId>

# 5. Compare two runs on the same dataset (B against baseline A)
fvm dart run tool/extraction_bench/bench.dart compare --dataset build/extraction_bench/dataset \
  --a build/extraction_bench/results/<runA>/predictions.jsonl \
  --b build/extraction_bench/results/<runB>/predictions.jsonl --out build/extraction_bench/compare/<runA>-vs-<runB>
```

`generate` options: `--seed` (default 1234), `--per-cell` documents per language × family (default 10), `--langs en,es,de,ro`, `--families lab_report,discharge_letter`, `--font-dir` (default `assets/font/matter-font`; run from the repository root). `score` and `compare` take `--seed` (default 1234) for the bootstrap. `score --only-predicted` scores only the documents that have a record, for a `BENCH_LIMIT` run; without it the rest of the dataset counts as missing and pulls the means down. `generate` refuses a non-empty `--out`, and empty or repeated `--langs` / `--families`. Every command exits non-zero with a message on bad input.

## Runner

`--dart-define`s:

| Define | Default | Meaning |
|---|---|---|
| `BENCH_MODEL` | required | `AiModelVariant` name: `qwen`, `medGemma`, `qwen7b` |
| `BENCH_VISION` | `true` | `useVision` for phase 2 (phase 1 always falls back to vision as in production). The app defaults to vision on desktop and text-only on phones (AI settings → vision off), so pass `false` for a phone run that matches what users get |
| `BENCH_RUN_ID` | `<model>-<os>-<UTC timestamp>` | Results folder; re-using an id appends, and `score` keeps the last record per document |
| `BENCH_LIMIT` | all | Process only the first N documents (sorted by docId) |
| `BENCH_COOLDOWN_S` | `0` | Pause between documents, to keep phones out of thermal throttling |
| `BENCH_GPU_LAYERS` | the app's config | GPU layers for every model load, text and vision (`0` = CPU only, `99` = all). Without it the app's `DeviceCapabilityService.computeModelConfig` decides, and its text paths never take the AI-settings value; on iOS that is 0 layers for text and at most 4 for vision. Recorded as `gpuLayers` in each record |

The runner fails before the first document when the model or mmproj file of `BENCH_MODEL` is missing from `<documents>/ai_models/`, naming the expected paths. Download the model in the app once (Settings → AI model) or copy the files there.

For each document it:

1. Rasterizes `document.pdf` with the production `PdfConversionMixin.convertPdfToImages` (200 dpi), or takes `page-<n>.png|jpg` in page-number order (`page-2` before `page-10`).
2. Applies the document's seeded degradation: `scan` (rotation within ±2°, blur, noise, JPEG q60) or `photo` (rotation within ±4°, brightness gradient, blur, JPEG q70); `clean` is untouched.
3. Mirrors `ProcessingHandler`: `ProcessingRepositoryImpl.mapBasicInfo`, then `docCategory` = `lab_report` when the container is a `MappingDiagnosticReport`, else `visit`, then `mapRemainingResources` with `useVision` from `BENCH_VISION`. Each yield is a snapshot of every phase-2 resource so far; the last one is kept, as `ProcessingHandler` keeps it in the session. Tuning prefs (max tokens, GPU layers, threads, context) are passed on mobile and left null on desktop, as in the app.
4. Maps the patient, the container and every phase-2 resource with `toFhirResource(subjectId: 'bench-patient', encounterId: 'bench-container')`. A resource whose mapping throws is left out and listed in `mappingErrors`.
5. Samples `ProcessInfo.currentRss` every 250 ms and appends one JSON line to `predictions.jsonl`.

The runner skips `ProcessingHandler`'s OCR pre-match against existing patient records (`mapContainerOnly`), since the benchmark has no records; it always runs the full phase 1.

The production classes are used unchanged. A recording decorator wraps `AiInferenceDataSourceImpl` and keeps each generation's raw output, whether it parses as JSON exactly as produced (`strictJsonValid`), the call's `GenerationStats` (prompt and completion tokens, time to first token, prompt-eval and total duration from llamadart's final chunk and performance context), and the image-encode time. Image-encode time comes only from llama.cpp's mtmd log lines (`image slice encoded in N ms`), which the runner receives through `LlamaLogging.configure`; when none appear the value is `null` and the report prints "n/a".

### Record format

```json
{"docId": "de-lab-001", "runId": "qwen-macos-…", "model": "qwen", "platform": "macos", "useVision": true, "gpuLayers": 99,
 "predictedResources": [{"resourceType": "Patient", …}, …],
 "generations": [{"phase": "basic", "mode": "text", "strictJsonValid": true, "promptTokens": 812,
   "completionTokens": 143, "timeToFirstTokenMs": 950.2, "promptEvalMs": 901.0, "durationMs": 4210.7,
   "imageEncodeMs": null, "imageDecodeMs": null, "rawOutput": "[…]"}],
 "peakRssBytes": 3012345856, "wallMs": 48211, "mappingErrors": ["…"], "error": "…"}
```

`error` is present only when the pipeline threw; `predictedResources` is then empty. `gpuLayers` is present only with `BENCH_GPU_LAYERS`.

### Per platform

The runner reads `<documents>/extraction_bench/dataset/` and writes `<documents>/extraction_bench/results/<runId>/predictions.jsonl`, where `<documents>` is `getApplicationDocumentsDirectory()`. The app (and the debug build the test runs) is sandboxed on macOS and iOS, so host paths are not readable; copy files in and out.

**macOS** (`-d macos`): the documents directory is `~/Library/Containers/<container>/Data/Documents`, where `<container>` is either the bundle id `com.techstackapps.healthwallet` or a UUID. The runner prints it as its first line (`[bench] documents: …`) and names it in every failure, so run it once to find it:

```bash
DOCS=~/Library/Containers/<container>/Data/Documents
mkdir -p "$DOCS/extraction_bench" && rm -rf "$DOCS/extraction_bench/dataset"
cp -R build/extraction_bench/dataset "$DOCS/extraction_bench/dataset"
fvm flutter test integration_test/extraction_bench_test.dart -d macos --dart-define=BENCH_MODEL=qwen --dart-define=BENCH_RUN_ID=qwen-mac-1
mkdir -p build/extraction_bench/results && cp -R "$DOCS/extraction_bench/results/qwen-mac-1" build/extraction_bench/results/
```

The model files go to `$DOCS/ai_models/` (download them in the app, or copy `Qwen3VL-2B-Instruct-Q4_K_M.gguf` and `mmproj-Qwen3VL-2B-Instruct-F16.gguf` there). Terminal may need Full Disk Access to read other apps' containers.

**Windows** (`-d windows`): documents = `%USERPROFILE%\Documents` (the test runs the unpackaged build). Copy the dataset to `%USERPROFILE%\Documents\extraction_bench\dataset` and read results from `%USERPROFILE%\Documents\extraction_bench\results`.

**On a phone or simulator, always pass `--no-uninstall`.** By default `flutter test` uninstalls the app when the test ends, which deletes the results, the dataset and the downloaded models with it. Keep the screen on (Auto-Lock: Never on iOS, stay awake while charging on Android): the runner holds no wake lock, and a locked phone suspends the app and stops the inference.

**Android** (debug build, documents = `/data/data/com.techstackapps.healthwallet/app_flutter`): install the app once (run the test, which fails fast without a dataset), then:

```bash
adb push build/extraction_bench/dataset /data/local/tmp/bench_dataset
adb shell "run-as com.techstackapps.healthwallet sh -c 'mkdir -p app_flutter/extraction_bench && rm -rf app_flutter/extraction_bench/dataset && cp -R /data/local/tmp/bench_dataset app_flutter/extraction_bench/dataset'"
fvm flutter test integration_test/extraction_bench_test.dart -d <device> --no-uninstall --dart-define=BENCH_MODEL=qwen --dart-define=BENCH_RUN_ID=qwen-a54-1
adb exec-out run-as com.techstackapps.healthwallet cat app_flutter/extraction_bench/results/qwen-a54-1/predictions.jsonl \
  > build/extraction_bench/results/qwen-a54-1.jsonl
```

Model files go to `app_flutter/ai_models/` the same way, or download them in the app.

**iOS device** (documents = the app's data container `Documents/`):

```bash
xcrun devicectl device copy to --device <udid> --domain-type appDataContainer \
  --domain-identifier com.techstackapps.healthwallet \
  --source build/extraction_bench/dataset --destination Documents/extraction_bench/dataset
fvm flutter test integration_test/extraction_bench_test.dart -d <udid> --no-uninstall --dart-define=BENCH_MODEL=qwen --dart-define=BENCH_RUN_ID=qwen-ip15-1
xcrun devicectl device copy from --device <udid> --domain-type appDataContainer \
  --domain-identifier com.techstackapps.healthwallet \
  --source Documents/extraction_bench/results/qwen-ip15-1/predictions.jsonl \
  --destination build/extraction_bench/results/qwen-ip15-1.jsonl
```

On the iOS simulator, `xcrun simctl get_app_container booted com.techstackapps.healthwallet data` prints the container path; copy into its `Documents/`.

## Datasets

```
<dataset>/
  manifest.json                      generator output only
  synthetic/<docId>/document.pdf     page as rendered
                    gold.json        FHIR R4 Bundle, type collection
                    meta.json        {docId, split, lang, family, degradation, seed, generatorVersion}
  real/<docId>/page-1.jpg, page-2.jpg …  or document.pdf
               gold.json
               meta.json             split "real", degradation "clean" (the photo is already real)
```

`score` and the runner read every `*/<docId>/meta.json`; strata come from `meta.json` (`split`, `lang`, `family`, `degradation`).

### Synthetic documents

The generator draws everything from the seed, builds the gold Bundle, and prints the same values on an A4 page with the Matter font. Families:

- `lab_report`: Patient, DiagnosticReport, 6–12 laboratory Observations (LOINC, UCUM), Practitioner, Organization.
- `discharge_letter`: Patient, Encounter (department as serviceType), 1–3 Conditions (SNOMED + ICD-10; full, year-month or year onset), 2–4 MedicationStatements (ATC + RxNorm ingredient), 0–2 AllergyIntolerances, 0–1 Procedure, 2–4 vital-sign Observations, Practitioner, Organization.

Every scored gold value is printed in the document's language and formatting: decimal comma for es/de/ro, `14 Mar 2025` / `14/03/2025` / `14.03.2025`, localized labels, German lower-case litre units (`mg/dl`). Gold concepts carry the codes; a broader code that earns partial credit is listed in the extension `https://healthwallet.me/fhir/extraction-bench/alternative-coding`. Codes are in `src/codes.dart`. Names, addresses, organisations and identifiers are invented (CNPs, DNIs and German insurance numbers have valid check digits). UK and German phone numbers come from the ranges reserved for drama; Spanish and Romanian ones are random digits and may belong to someone. Each page carries a "SYNTHETIC TEST DOCUMENT" footer. A character the font lacks stops the generator before it writes anything.

Same seed, same options: byte-identical `document.pdf`, `gold.json`, `meta.json` and `manifest.json`.

### Real hold-out

Real documents measure the synthetic-to-real gap and never train anything. Layout as above under `real/`, with a hand-written `gold.json` that holds only what is printed, in the shape of the synthetic gold (the scored fields below).

De-identification rule: a real document enters the hold-out only after every direct identifier (names, ID and insurance numbers, dates of birth, addresses, phone numbers, e-mail addresses, signatures and stamps, photos, barcodes and QR codes) has been removed or replaced on the image itself, and the gold uses the replaced values. The hold-out lives outside the repository (or under the gitignored `build/`) and is never committed, uploaded to CI, or attached to tickets or chats.

## Scoring

Per document, within each resource type, predicted and gold resources are paired by the Hungarian algorithm (rectangular Kuhn–Munkres, cost Σ(1 − field score)). A pair that agrees on no field (no field present on both sides with a score above 0) gets a prohibitive cost, so it never displaces an agreeing pair, and stays unmatched if the assignment still proposes it.

| Case | Counts |
|---|---|
| Both null on a matched pair | TP 1 (correct-null credit) |
| Gold null, predicted value | FP 1 (hallucinated) |
| Gold value, predicted null | FN 1 (omitted) |
| Both present, score s | TP s, FP 1 − s, FN 1 − s |
| Unmatched gold record | FN per non-null gold field (omitted) |
| Unmatched predicted record | FP per non-null predicted field (hallucinated) |

Empty strings count as null. Per document: micro precision, recall and F1 (`2TP / (2TP + FP + FN)`; with nothing predicted, precision is 1 only if nothing was missed), omission rate (omitted FN / gold non-null fields) and hallucination rate (hallucinated FP / predicted non-null fields). Reports give the mean of each (F1, P, R, omission and hallucination rates) over documents with 95% percentile bootstrap CIs over documents (10,000 resamples, `--seed`). A document missing from the predictions, or whose record has an `error`, is scored with no predictions and counted under `missing` / `errors`.

Scored fields are only those `toFhirResource` can fill. The gold is fixed FHIR truth, coded concepts included, so the scale is absolute rather than relative to what the app can emit: the app codes only the patient identifier type, the encounter specialty and vital-sign observations, so a text-only prediction earns at most 0.5 on a coded concept and a flawless extraction still scores below 1.0. The oracle's 1.0 only checks that the scorer is consistent with itself.

| Type | Fields |
|---|---|
| Patient | family (text), given (set), birthDate (date), gender (exact), identifier value (identifier) |
| Encounter | type (concept), serviceType (concept), period.start (date) |
| DiagnosticReport | code (concept), effectiveDateTime / issued (date), conclusion (text) |
| Observation | code (concept), valueQuantity / valueString (quantity) |
| Condition | code (concept), onsetDateTime (date) |
| MedicationStatement | medicationCodeableConcept (concept), dosage text (text) |
| AllergyIntolerance | code (concept), category (exact), first reaction manifestation (concept) |
| Procedure | code (concept), performedDateTime (date) |
| Practitioner | name text (text), qualification (concept), identifier value (identifier) |
| Organization | name (text), address text (text), phone (identifier) |

Comparators:

- **text**: case, diacritics and whitespace folded; equal → 1; otherwise 0 when the gold's numbers do not all appear, in order, among the prediction's (`1-0-0` vs `1-0-1`, `20 IE` vs `14 IE`; extra numbers such as a printed ICD code are allowed), else token Jaccard if ≥ 0.5, else 0.
- **exact**: equal after folding.
- **identifier**: equal ignoring spaces, dashes, slashes, parentheses, dots and case (`(030) 23125-123` = `030/23125123`).
- **date**: date part only (time ignored); same precision and equal → 1, one a coarser prefix of the other → 0.5, else 0.
- **quantity**: value and unit from `valueQuantity` or a string such as `13,5 g/dL`. Unit text normalized (`µ`→`u`, `x10^9/L`→`10*9/L`, `l`→`L`, `°C`→`Cel`, `mmHg`→`mm[Hg]`, `bpm`→`/min`, `IU`/`UI`→`[IU]`); equal unit text, or UCUM-convertible units (prefixes f…T, a bare `G`/`T` as 10^9/10^12 so `G/l` = `10*9/L`; mass, volume, length, time, temperature), with values within a relative 1e-3 → 1. A predicted value without a unit against a gold unit scores 0.5 when the number matches. Units that don't convert (`mmol/L` vs `mg/dL`) score 1 only if value and normalized unit text are both equal.
- **set**: Jaccard of the elements' folded tokens (`["Ana Maria"]` = `["Ana", "Maria"]`).
- **concept**: a shared `system|code` → 1; a gold-listed alternative code → 0.75; otherwise 0.5 × the best text score between the texts and displays. A gold concept with no codings (document title, qualification) is compared as text at full weight. The app codes only the patient identifier type, the encounter specialty and vital-sign observations, so for most concepts the text tier is what a prediction can earn.

`report.json` / `report.md`: overall and per stratum (split, lang, family, degradation), per resource type, F1/P/R and omission and hallucination rates with CIs, strict-JSON validity rate of the generations, error and missing counts, median/p90 of time to first token, prompt eval and image encode (per generation, pooled and per mode, since a vision call's time to first token includes the image encode) and wall time (per document), and peak RSS (median, p90, max per document).

`compare`: the per-document F1 difference B − A over documents present in both prediction files, paired bootstrap (same resamples for both runs), its 95% CI and P(B − A ≤ 0), overall and per stratum. Same seed, same output.
