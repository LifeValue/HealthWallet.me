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

`generate` options: `--seed` (default 1234), `--per-cell` documents per language × family (default 10), `--langs en,es,de,ro`, `--families lab_report,discharge_letter` (add `lab_report_long` for multi-page lab reports; it is not in the default, so default datasets stay byte-identical), `--font-dir` (default `assets/font/matter-font`; run from the repository root). `score` and `compare` take `--seed` (default 1234) for the bootstrap. `score --only-predicted` scores only the documents that have a record, for a `BENCH_LIMIT` run; without it the rest of the dataset counts as missing and pulls the means down. `generate` refuses a non-empty `--out`, and empty or repeated `--langs` / `--families`. Every command exits non-zero with a message on bad input.

## Runner

`--dart-define`s:

| Define | Default | Meaning |
|---|---|---|
| `BENCH_MODEL` | required | `AiModelVariant` name: `qwen`, `medGemma`, `qwen7b` |
| `BENCH_VISION` | `true` | `useVision` for phase 2 (phase 1 always falls back to vision as in production). The app defaults to vision on desktop and text-only on phones (AI settings → vision off), so pass `false` for a phone run that matches what users get |
| `BENCH_RUN_ID` | `<model>-<os>-<UTC timestamp>` | Results folder; re-using an id appends, and `score` keeps the last record per document |
| `BENCH_LIMIT` | all | Process only the first N documents (sorted by docId) |
| `BENCH_DOCS` | all | Process only these comma-separated docIds (e.g. to re-run the documents that errored; merge the records by docId before scoring) |
| `BENCH_COOLDOWN_S` | `0` | Pause between documents, to keep phones out of thermal throttling |
| `BENCH_OUTPUT` | the app's pref (unset: `schema`) | `ExtractionOutputMode` for every phase: `grammar` (the generic JSON-array grammar), `schema` (a flat per-phase JSON schema as llamadart `responseFormat`) or `schemaDraft` (an unconstrained draft call, then the schema call with the draft in its prompt). Sets the `aiOutputMode` pref for the run and restores it afterwards, so the runner reads the mode the way `ProcessingHandler` does. Recorded as `outputMode` in each record |
| `BENCH_GPU_LAYERS` | the app's config | GPU layers for every model load, text and vision (`0` = CPU only, `99` = all). Without it the app's `DeviceCapabilityService.computeModelConfig` decides, and its text paths never take the AI-settings value; on iOS that is 0 layers for text and at most 4 for vision. Recorded as `gpuLayers` in each record |

The runner fails before the first document when the model or mmproj file of `BENCH_MODEL` is missing from `<documents>/ai_models/`, naming the expected paths. Download the model in the app once (Settings → AI model) or copy the files there.

For each document it:

1. Rasterizes `document.pdf` with the production `PdfConversionMixin.convertPdfToImages` (200 dpi), or takes `page-<n>.png|jpg` in page-number order (`page-2` before `page-10`).
2. Applies the document's seeded degradation: `scan` (rotation within ±2°, blur, noise, JPEG q60) or `photo` (rotation within ±4°, brightness gradient, blur, JPEG q70); `clean` is untouched.
3. Mirrors `ProcessingHandler`: `ProcessingRepositoryImpl.mapBasicInfo`, then `docCategory` = `lab_report` when the container is a `MappingDiagnosticReport`, else `visit`, then `mapRemainingResources` with `useVision` from `BENCH_VISION`; both phases get the output mode read from the `aiOutputMode` pref. Each yield is a snapshot of every phase-2 resource so far; the last one is kept, as `ProcessingHandler` keeps it in the session. Tuning prefs (max tokens, GPU layers, threads, context) are passed on mobile and left null on desktop, as in the app.
4. Maps the patient, the container and every phase-2 resource with `toFhirResource(subjectId: 'bench-patient', encounterId: 'bench-container')`. A resource whose mapping throws is left out and listed in `mappingErrors`.
5. Samples `ProcessInfo.currentRss` every 250 ms and appends one JSON line to `predictions.jsonl`.

The runner skips `ProcessingHandler`'s OCR pre-match against existing patient records (`mapContainerOnly`), since the benchmark has no records; it always runs the full phase 1.

The production classes are used unchanged. A recording decorator wraps `AiInferenceDataSourceImpl` and keeps each generation's raw output, whether it parses as JSON exactly as produced (`strictJsonValid`), how it was constrained (`constraint`: `grammar`, `schema`, or `none` for a schemaDraft draft call), the call's `GenerationStats` (prompt and completion tokens, time to first token, prompt-eval and total duration and `finishReason` from llamadart's final chunk and performance context; `finishReason` is `length` when the generation stopped at maxTokens or a full context, i.e. was truncated), and the image-encode and image-decode times from llama.cpp's mtmd log lines (`image slice encoded in N ms`, `image decoded (batch i/n) in N ms`).

llama.cpp writes its log to stderr, and llamadart never forwards it to a Dart handler, so the runner points the process's stderr (fd 2) at `results/<runId>/native.log` for the run (`NativeLogCapture`), reads what each generation wrote after it returns and copies it on to the real stderr. `native.log` is kept as the run's full native log. llamadart 0.15 encodes images with `mtmd_encode_chunk` itself and only decodes through mtmd's helper, so the decode line appears but the encode line does not: `imageEncodeMs` is `null` and the report prints "n/a". Use the vision calls' time to first token, which includes the encode, until llamadart logs or reports it.

Each record also keeps the pipeline's own `ProcessingLogBuffer` lines for the document (`pipelineLog`): OCR size, the model config and GPU layers, memory checks, vision batches and text fallbacks.

### Record format

```json
{"docId": "de-lab-001", "runId": "qwen-macos-…", "model": "qwen", "platform": "macos", "useVision": true,
 "outputMode": "schema", "gpuLayers": 99,
 "predictedResources": [{"resourceType": "Patient", …}, …],
 "generations": [{"phase": "basic", "mode": "text", "strictJsonValid": true, "promptTokens": 812,
   "completionTokens": 143, "timeToFirstTokenMs": 950.2, "promptEvalMs": 901.0, "durationMs": 4210.7,
   "finishReason": "stop", "constraint": "schema", "imageEncodeMs": null, "imageDecodeMs": null, "rawOutput": "{…}"}],
 "peakRssBytes": 3012345856, "wallMs": 48211, "pipelineLog": ["[12:25:05.290][ScanAI] loadModel: ctx=2048, gpuLayers=99, …", …],
 "mappingErrors": ["…"], "error": "…"}
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

**Simulators and emulators** give valid extractions for accuracy and regression checks, but not phone speed or memory: llamadart runs on the CPU in the iOS simulator (its Metal backend returns wrong output there, llamadart issue #950), and the app runs llama.cpp on the CPU on every Android device, so both run at the Mac's CPU speed. Platform OCR differs (Vision on iOS, ML Kit on Android), so compare runs within one platform.

*iOS simulator*: install once (the first run fails fast without a model), then copy into the data container. Its path changes on every reinstall, so look it up each time; `cp -c` clones the model without using disk.

```bash
SIM=<simulator udid>; xcrun simctl boot $SIM
fvm flutter test integration_test/extraction_bench_test.dart -d $SIM --no-uninstall --dart-define=BENCH_MODEL=qwen   # installs, then fails fast
C=$(xcrun simctl get_app_container $SIM com.techstackapps.healthwallet data)
mkdir -p "$C/Documents/ai_models" "$C/Documents/extraction_bench" && cp -c build/extraction_bench/models/*.gguf "$C/Documents/ai_models/"
rm -rf "$C/Documents/extraction_bench/dataset" && cp -R build/extraction_bench/dataset "$C/Documents/extraction_bench/dataset"
fvm flutter test integration_test/extraction_bench_test.dart -d $SIM --no-uninstall --dart-define=BENCH_MODEL=qwen --dart-define=BENCH_VISION=false --dart-define=BENCH_RUN_ID=qwen-sim-1
cp "$C/Documents/extraction_bench/results/qwen-sim-1/predictions.jsonl" build/extraction_bench/results/qwen-sim-1.jsonl
```

*Android emulator*: an arm64 image with at least 6 GB RAM and enough free data space for the model (about 2 GB, plus as much again while it is staged in `/data/local/tmp`). The default AVD's 2 GB RAM and 6 GB data partition are too small, and `-partition-size` does not grow an existing one, so create a dedicated AVD:

```bash
echo no | avdmanager create avd -n bench_pixel -k "system-images;android-35;google_apis_playstore_ps16k;arm64-v8a" -d pixel_8a
sed -i '' -e 's/^disk.dataPartition.size.*/disk.dataPartition.size = 16G/' -e 's/^hw.ramSize.*/hw.ramSize = 6144/' ~/.android/avd/bench_pixel.avd/config.ini
emulator -avd bench_pixel -no-snapshot-save -no-audio &
```

Then follow the Android steps above with `-d emulator-5554`, pushing `build/extraction_bench/models` the same way as the dataset. A document takes about 6 minutes there (Apple M-series CPU).

## Output-mode measurement (2026-10-26)

Dataset `generate --seed 7 --per-cell 3` (24 documents), Qwen3-VL-2B, iPhone 17 Pro simulator (CPU), one run per mode with `BENCH_OUTPUT` and `BENCH_VISION`; `compare` with `--seed 1234`. Run ids `qwen-sim-<text|vision>-<mode>`.

| Run | F1 [95% CI] | Recall | Omission | Strict JSON | Truncated | Median wall / doc |
|---|---|---|---:|---:|---:|---:|
| text, grammar | 0.564 [0.524, 0.603] | 0.587 | 14.2% | 95.8% | 4.2% | 47 s |
| text, schema | 0.602 [0.573, 0.631] | 0.645 | 6.0% | 100.0% | 0.0% | 42 s |
| text, schemaDraft | 0.606 [0.581, 0.633] | 0.649 | 6.1% | 100.0% | 0.0% | 59 s |
| vision, grammar | 0.558 [0.516, 0.599] | 0.572 | 16.0% | 93.8% | 6.3% | 49 s |
| vision, schema | 0.599 [0.570, 0.629] | 0.641 | 6.4% | 97.9% | 2.1% | 44 s |
| vision, schemaDraft | 0.597 [0.571, 0.622] | 0.640 | 6.1% | 100.0% | 0.0% | 51 s |

ΔF1 schema − grammar (text): +0.038 [0.006, 0.072], P(≤ 0) = 0.011; largest on ro (+0.111) and es (+0.070), de and en within ±0.014. ΔF1 schemaDraft − schema (text): +0.004 [−0.012, 0.020], P(≤ 0) = 0.303. Vision runs: schema − grammar +0.041 [0.006, 0.077], schemaDraft − schema −0.003 [−0.016, 0.011]. By the rule fixed before measuring (text run decides: schema if ΔF1 ≥ 0 and strict JSON not lower; schemaDraft only if its lower CI bound over schema is > 0), `ExtractionOutputMode.defaultMode` is `schema`.

The two grammar truncations (ro-dis-003, ro-lab-003, phase 2) are gone under the schema's `maxItems`. No run put a Condition on a lab report or a CNP label on a German patient. In the simulator the vision runs mostly measure the text path: its memory check (60% of the RAM estimated for the simulator's machine id, minus the RSS) stops the vision batch on most documents and phase 2 falls back to text, (20–22 of 24 documents; 2–4 vision generations per run), so read them as a check that the vision code paths run, not as vision accuracy; measure vision on a phone.

## Model candidates (2026-10-26)

Measured on the code before the phase-2 multi-page fix; "Phase-2 multi-page fix and candidates re-run (2026-10-27)" below supersedes the recommendation.

Research recommendation 4 (D1a). Dataset `generate --seed 7 --per-cell 6` (48 documents, `build/extraction_bench/dataset-48`), text only (`BENCH_VISION=false`), `BENCH_OUTPUT=schema`, iPhone 17 Pro and 17 Pro Max simulators (CPU), two runs in parallel; `compare` against the tier's current model with `--seed 1234`. Run ids `<variant>-sim-text-48`. The candidates are bench-only `AiModelVariant`s (not in `availableVariants`); NuExtract 2.0 and NuExtract3 get their chat template's `template` kwarg (built from the phase schema by `NuExtractPrompt`) and, for NuExtract3, `instructions`; the others use the production prompts. Every candidate loaded and ran in llamadart 0.15.6 (`qwen35` architecture and BF16 mmproj included). Rule fixed before measuring: recommend a candidate only if the lower bound of its ΔF1 95% CI is above 0 and strict JSON and truncation are no worse. Simulator times and RAM are not phone numbers; download is model + mmproj.

| Tier | Model | F1 [95% CI] | ΔF1 vs tier model [95% CI] | Omission | Hallucination | Strict JSON | Truncated | Median wall / doc | Download | Licence |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---|
| Lite | Qwen3-VL-2B (shipped) | 0.604 [0.585, 0.623] | | 5.8% | 16.5% | 99.0% | 1.0% | 48 s | 1.93 GB | Apache-2.0 |
| Lite | Qwen3.5-2B | 0.594 | −0.010 [−0.030, 0.009] | 11.6% | 16.2% | 97.9% | 2.1% | 55 s | 1.95 GB | Apache-2.0 |
| Lite | NuExtract 2.0-2B | 0.510 | −0.094 [−0.119, −0.069] | 35.3% | 21.6% | 100.0% | 0.0% | 29 s | 2.32 GB | MIT |
| Advanced | MedGemma 1 4B (shipped) | 0.635 [0.611, 0.660] | | 9.7% | 18.2% | 100.0% | 0.0% | 85 s | 3.34 GB | HAI-DEF |
| Advanced | Qwen3.5-4B | 0.696 [0.675, 0.718] | **+0.061 [0.041, 0.082]** | 3.8% | 14.7% | 97.9% | 2.1% | 99 s | 3.41 GB | Apache-2.0 |
| Advanced | NuExtract3 (4B) | 0.650 [0.632, 0.670] | +0.015 [−0.005, 0.036] | 6.5% | 17.5% | 100.0% | 0.0% | 85 s | 3.46 GB | Apache-2.0 |
| Advanced | MedGemma 1.5 4B | 0.548 [0.527, 0.570] | −0.087 [−0.114, −0.061] | 22.4% | 16.2% | 100.0% | 0.0% | 76 s | 3.34 GB | HAI-DEF |

Every run classified all 48 documents correctly as lab report or visit except NuExtract 2.0 (31/48; it has no instructions slot, so it never sees the lab-report-vs-visit rule).

- **Lite: keep Qwen3-VL-2B.** Qwen3.5-2B is a tie (de +0.022, en −0.033, lab reports −0.031 [−0.065, 0.000]); it is better on Conditions (0.65 vs 0.55) and DiagnosticReport (0.76 vs 0.62), worse on Observations (0.45 vs 0.53), and omits twice as much. NuExtract 2.0 is worse in every language and family (Condition 0.17, Procedure 0.15).
- **Advanced: Qwen3.5-4B is the only candidate with a significant gain, but by the rule it is not recommended yet.** It is ahead in every language (de +0.098, ro +0.070, en +0.041, es +0.036 [0.001, 0.067]) and family (lab reports +0.067, discharge letters +0.055), with Organization 0.94 vs 0.68 and MedicationStatement 0.34 vs 0.14. It fails the validity criterion on two phase-2 generations (es-dis-005, ro-dis-003; 2 of 96): prompt (~1,320 tokens) plus output (709–731) fill the 2,048-token context, because it writes indented JSON. Fix that (a larger phase-2 context or compact output) and re-measure before switching; it also drops MedGemma's HAI-DEF obligations.
- NuExtract3 is ahead of MedGemma (discharge letters +0.043 [0.023, 0.066], en +0.049 [0.016, 0.084], Condition 0.71 vs 0.58, Organization 0.98 vs 0.68) but not significantly overall (P(Δ ≤ 0) = 0.062), and below its own base model: NuExtract3 − Qwen3.5-4B = −0.046 [−0.067, −0.026]. Its vendor benchmark edge does not carry over to our schemas with this template prompt.
- MedGemma 1.5 is worse than MedGemma 1 in every stratum; it drops practitioners and organizations (0.36 and 0.26 vs 0.88 and 0.68) and procedures (0.23 vs 0.70).

14 Qwen3.5-4B documents first failed with the app's pre-load memory check ("Not enough memory to load the AI model. Available: ~3,450MB, required: ~4,635MB"): the simulator reports the Mac's free RAM, which dropped while both simulators loaded 4B models. They were re-run with `BENCH_DOCS` (`qwen35x4b-sim-text-48-rerun`, no errors) and merged by docId (`qwen35x4b-sim-text-48-merged`). On a phone, run one model at a time. Still open on a phone: speed, peak RAM and vision for Qwen3.5-4B and NuExtract3.

The missing-patient-ID path of the schema change is not measured by these runs: every generated document prints a patient identifier.

## Phase-2 multi-page fix and candidates re-run (2026-10-27)

A real 4-page Romanian lab report (7 results, hand-written gold, under the gitignored `build/`; never committed) scored 0.16–0.38 on an iPhone 17 with every model. Phase 2 saw only the first 2000 OCR characters, mostly the letterhead and patient block, so the answer stopped after the second test; `ObservationOcrValidator` then added phone numbers, addresses, page footers and reference-range rows as observations. The fix (`OcrPages`, 4096-context chunked text calls, per-batch vision OCR, a stricter validator; see `doc/architecture.md`, Output modes) took the real report on the iPhone 17 (`BENCH_DOCS=ro-lab-real-001`, schema, vision on; every 4B model's vision load fails the memory check on the 8 GB phone and phase 2 runs text-only) to:

| Model | F1 before | F1 after | Wall after |
|---|---:|---:|---:|
| Qwen3-VL-2B (Lite) | 0.215 | 0.431 | 42 s |
| Qwen3.5-2B | 0.247 | 0.521 | 48 s |
| NuExtract 2.0-2B | 0.380 | 0.365 | 39 s |
| MedGemma 1 4B (Advanced) | 0.157 | 0.352 | 145 s |
| Qwen3.5-4B | 0.277 | 0.596 | 94 s |
| NuExtract3 | 0.244 | 0.425 | 139 s |
| MedGemma 1.5 4B | 0.231 | 0.373 | 59 s |

What is left on that report: a value taken from the next row, OCR unit misreads (`Ul/mL`) and an OCR prefix kept in a test name.

Two simulator sets, text only, schema, run ids `<variant>-sim-long-fix` and `<variant>-sim-text-48-fix`: `dataset-long` (`generate --seed 7 --per-cell 3 --families lab_report_long`, 12 documents of 2–3 pages) and the 48-document set above. Qwen3-VL-2B old → new code: long 0.091 → 0.561 (+0.470 [0.413, 0.523]; the old code hallucinated 90.9% of its fields and truncated half its generations), 48 documents 0.604 → 0.652 (+0.048 [0.038, 0.059], hallucination 16.5% → 4.1%). MedGemma 48 documents 0.635 → 0.684 (+0.049 [0.039, 0.061]). Every earlier candidate comparison carried the validator's junk, so the candidates were re-run on the new code; NuExtract 2.0 and MedGemma 1.5 were left out (clearly worse above).

| Tier | Model | F1, 48 docs | ΔF1 vs tier model, 48 [95% CI] | Halluc. 48 | F1, long | ΔF1, long [95% CI] | Strict JSON / truncated, long | Median wall / doc, 48 / long |
|---|---|---:|---|---:|---:|---|---|---:|
| Lite | Qwen3-VL-2B (shipped) | 0.652 | | 4.1% | 0.561 | | 100% / 0% | 49 / 102 s |
| Lite | Qwen3.5-2B | 0.641 | −0.011 [−0.032, 0.010] | 3.8% | 0.522 | −0.038 [−0.117, 0.043] | 86.2% / 13.8% | 58 / 145 s |
| Advanced | MedGemma 1 4B (shipped) | 0.684 | | 5.8% | 0.575 | | 93.1% / 6.9% | 94 / 216 s |
| Advanced | Qwen3.5-4B | 0.751 | **+0.067 [0.046, 0.088]** | 1.9% | 0.659 | **+0.084 [0.024, 0.143]** | 100% / 0% | 104 / 193 s |
| Advanced | NuExtract3 (4B) | 0.676 | −0.009 [−0.049, 0.025] | 5.5% | 0.580 | +0.005 [−0.074, 0.075] | 100% / 0% | 91 / 207 s |

All 48-document runs have 100% strict JSON and no truncation. One NuExtract3 document (en-lab-003) failed the simulator's memory check twice (the simulator reports the Mac's free RAM) and counts as an error; its other memory-check failure was re-run and merged (`nuExtract3-sim-text-48-fix-merged`).

- **Lite: keep Qwen3-VL-2B.** Qwen3.5-2B ties on the 48 documents and on multi-page reports truncates 13.8% of its generations; its lead on the one real report does not outweigh that.
- **Advanced: Qwen3.5-4B is recommended** (the rule above: CI lower bound above 0, strict JSON and truncation no worse, on both sets). On the 48 documents it is ahead in every language (de +0.103, ro +0.074, en +0.046, es +0.043 [0.005, 0.076]), family (lab reports +0.068, discharge letters +0.065) and degradation; Organization 0.99 vs 0.68, MedicationStatement 0.34 vs 0.14. On the long set it is behind only in Romanian (−0.051 [−0.091, −0.027], 3 documents). Licence Apache-2.0 instead of HAI-DEF, download 3.41 GB vs 3.34 GB. On the 8 GB iPhone 17 neither 4B model fits with vision, so the switch loses nothing there. Still open on a phone: vision on a device with more RAM, and peak RAM.
- NuExtract3 is no better than MedGemma and below its base model (NuExtract3 − Qwen3.5-4B = −0.075 [−0.117, −0.041]).

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
- `lab_report_long` (docId `<lang>-labl-<n>`, opt-in): a lab report of 16–21 Observations, each with four age and sex reference brackets printed under its row, over 2–3 pages, with the letterhead, patient block, report date and table header repeated on every page, as many labs print them. It exercises what single-page documents never do: phase-2 OCR across pages and the repeated header lines.
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

`report.json` / `report.md`: the runs' output modes (a record without `outputMode` counts as `grammar`), overall and per stratum (split, lang, family, degradation), per resource type, F1/P/R and omission and hallucination rates with CIs, strict-JSON validity rate and truncated rate (`finishReason: length`, over the generations that recorded a finish reason) of the constrained generations (schemaDraft draft calls are free text and left out of both; `draftGenerations` counts them), error and missing counts, median/p90 of time to first token, prompt eval and image encode (per generation, pooled and per mode, since a vision call's time to first token includes the image encode) and wall time (per document), and peak RSS (median, p90, max per document).

`compare`: the per-document F1 difference B − A over documents present in both prediction files, paired bootstrap (same resamples for both runs), its 95% CI and P(B − A ≤ 0), overall and per stratum. Same seed, same output.
