# HealthWallet.me architecture reference

Reference for work in `lib/features/processing/`, `lib/features/capture/` and `lib/features/desktop/`. Rules every session needs are in `AGENTS.md`; this file holds the detail behind them. Verified against `eef6c7f` on 2026-10-22.

## Platforms and toolchain

- Flutter 3.47.7 via FVM (`.fvmrc`); Dart SDK `>=3.13.5 <4.0.0` (`pubspec.yaml`).
- Mobile: iOS 16.4+ (llamadart 0.15 floor), Android minSdk 24. Package name `com.techstackapps.healthwallet`.
- Android: Gradle 9.4.1, AGP 9.2.1, Kotlin 2.4.0, compileSdk 37, NDK 28.2. Code compiles to Java 11; CI runs Gradle on Temurin JDK 17. AGP 9 runs in Flutter's compatibility mode (`android.builtInKotlin=false`, `android.newDsl=false` in `android/gradle.properties`); `android/build.gradle.kts` raises plugins compiling below SDK 36 to 37 and fills in missing namespaces.
- Desktop: macOS 14+ (production; llamadart 0.15 floor) and Windows (Store-packaged MSIX). Linux is not scaffolded; `Platform.isLinux` branches are kept for a future port.

## Entry points

| File                    | Platform        | Sets up                                                                                                                                                                                                                                                                                                            |
| ----------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `lib/main.dart`         | iOS / Android   | Clears `lww_offline_queue`, preserves the native splash, registers `AppPlatform.mobile`, `configureDependencies()`, `ShareIntentService`, `DeepLinkService`, `ProcessingBloc.add(ProcessingInitialised())`, removes the splash                                                                                     |
| `lib/main_desktop.dart` | macOS / Windows | Registers `AppPlatform.desktop`, `CommunicationBloc` and `TrayBloc` by hand (`BackupBloc`, `HandoverBloc`, `LwwSyncBloc`, `WindowLifecycleService` come from injectable), sends their init events and `ProcessingInitialised`, pipes `CommunicationBloc` and `LwwSyncBloc` state into `TrayBloc`. No native splash |

`App` provides the BLoCs through `MultiBlocProvider` and, as a `WidgetsBindingObserver`, starts and stops P2P discovery on resume and pause.

## Commands

```bash
fvm flutter pub get
fvm dart run build_runner build      # or: watch
fvm flutter analyze
fvm flutter test                     # whole suite: 119 tests, under a minute
fvm flutter test test/widget_test.dart

fvm flutter build apk --release
fvm flutter build appbundle --release
fvm flutter build ios --release --no-codesign
fvm flutter build macos --release --target lib/main_desktop.dart
fvm flutter build windows --release --target lib/main_desktop.dart   # scripts/build_windows.ps1 also zips it
fvm flutter run -d <device-id>                                       # add -t lib/main_desktop.dart for desktop

cd ios && bundle exec fastlane beta       # TestFlight
cd macos && bundle exec fastlane beta     # TestFlight (macOS)
cd android && bundle exec fastlane beta   # Play internal
```

The `beta` lanes set the build number to the store's latest plus one. There are no `release` lanes; a tested beta is promoted to production by hand in App Store Connect and Play Console.

## Code generation

`build_runner` generates Freezed (`*.freezed.dart`), json_serializable and drift (`*.g.dart`), injectable (`injection.config.dart`), AutoRoute (`app_router.gr.dart`) and envied (`env.g.dart`) output. All of it is gitignored and excluded from analysis. `build.yaml` keeps drift off `lib/features/backup/data/services/transport/**` and names the database `my_database`.

Localization is separate: `flutter gen-l10n` (driven by `l10n.yaml`) writes `lib/core/l10n/arb/app_localizations*.dart`, which are committed, and `untranslated_messages.json`, which lists ARB keys missing per locale.

Envied reads `.env`: `HUGGING_FACE_TOKEN` (model downloads), `GOOGLE_WALLET_ISSUER_ID`, `APPLE_PASS_TYPE_ID`, `APPLE_TEAM_ID`.

## Feature modules

| Feature                                                | What it does                                                                                                |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `capture/scan/`                                        | Camera capture + `ScanBloc` (mobile only)                                                                   |
| `capture/import/`                                      | File picker for PDFs and images + `ImportBloc`                                                              |
| `capture/desktop_import/`                              | Desktop drag-and-drop / picker + `DesktopBloc`                                                              |
| `processing/`                                          | Document → FHIR pipeline, shared by mobile and desktop                                                      |
| `desktop/`                                             | Communication, handover, LWW sync, backup, tray (desktop builds; communication and sync also run on mobile) |
| `sync/`                                                | Fasten Health OnPrem pairing and FHIR sync (`sync/ehrs/fasten/`, shared `sync/data/`, `sync/domain/`)       |
| `home/`                                                | Dashboard grid of health category cards                                                                     |
| `records/`                                             | FHIR resource browsing, attachments, IPS PDF export (private `fhir_ips_export`)                             |
| `share_records/`                                       | P2P proximity sharing via the private `airdrop` package                                                     |
| `wallet_pass/`                                         | Apple / Google Wallet emergency card; its QR opens emergency.healthwallet.me (`docs/`)                      |
| `user/`, `onboarding/`, `notifications/`, `dashboard/` | Profile and patient deduplication, first launch, in-app notifications, tab container                        |

Capture hands files to `ProcessingBloc` with a `DocumentImported` event.

Fasten sync flow: parse QR → create wallet source → create default patient → clear demo data → authenticate with a bearer token → sync FHIR resources from the backend sequentially.

## Processing pipeline

1. **OCR**: `NativeTextRecognitionService` calls the `dev.lifevalue.healthwallet/ocr` method channel (`processing/data/data_source/platform/ocr_channel.dart`), rasterising PDF pages first. Native handlers: Apple Vision in `ios/Runner/TextRecognitionHandler.swift` and `macos/Runner/AppDelegate.swift`, ML Kit in `android/app/src/main/kotlin/com/techstackapps/healthwallet/ocr/TextRecognitionHandler.kt`, `Windows.Media.Ocr` in `windows/runner/windows_ocr_plugin.cpp`. No OCR Flutter plugin, so iOS has no ML Kit pods and runs on arm64 simulators.
2. **Vision, phase 1**: `AiInferenceDataSource.runVisionPrompt()` (`processing/data/data_source/network/ai_inference_data_source.dart`, implemented in `ai_inference_handler.dart`) extracts patient demographics, encounter and a primary diagnostic report.
3. **Vision, phase 2**: `runVisionPrompt()` again for the remaining resource types (medications, immunizations, allergies, vitals…).
4. **Text fallback**: if vision fails, `runTextPrompt()` runs on the OCR text.
5. **FHIR mapping**: `ProcessingRepository` (`processing/domain/repository/`, implemented in `processing/data/repository/processing_repository_impl.dart`) maps the staged `MappingResources` (`processing/domain/entity/mapping_resources/`) to FHIR R4 and writes them through Drift.

### Output modes

`ExtractionOutputMode` (`processing/domain/entity/extraction_output_mode.dart`), read from the `aiOutputMode` pref on every platform and passed by `ProcessingHandler` to `mapContainerOnly`, `mapBasicInfo` and `mapRemainingResources` like the other AI tuning prefs. Unset or unknown → `ExtractionOutputMode.defaultMode`, which is `schema` since the 2026-10-26 measurement (`tool/extraction_bench/README.md`, "Output-mode measurement").

| Mode          | Each generation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `grammar`     | `GbnfGrammars.jsonArray`: any JSON array of objects; prompts describe `resourceType`-tagged objects                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `schema`      | A flat JSON schema per phase as llamadart `responseFormat` (no grammar): phase 1 one object (patient fields, `documentTitle`, `documentDate`, `conclusion`, `documentCategory` enum), container-only the document fields, phase 2 one object of arrays per category (`lab_report`: observations, practitioners, organizations; `visit`: conditions, medications, procedures, allergies, vitalSigns, practitioners, organizations; anything else the union). Enums for closed sets, dates as `^([0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?)?$` (llamadart's pattern subset has no `\d`), `maxItems` on every array, `additionalProperties: false` |
| `schemaDraft` | An unconstrained draft call (≤ 384 tokens, same modality as the step), then the `schema` call text-only with the draft and the OCR text in the prompt (text context ≥ 4096). A failed draft leaves the constrained call without one                                                                                                                                                                                                                                                                                                                                                                                                    |

`processing/data/model/structured_output/extraction_schemas.dart` holds the schemas, the shape text the prompts show (llama.cpp does not inject the schema into the prompt) and the mappers from the schema output back to the legacy `resourceType` maps, so `MappingResource.fromJson`, the dedupe and skip rules, the review UI, sync and the DB are the same in every mode. Output cut off mid-JSON is salvaged up to the last complete array item; unusable phase-2 output gives no resources, unusable phase-1 output takes the vision fallback as before. Every schema is checked with llamadart's `LlamaStructuredOutput.jsonValueSchema` in `test/features/processing/extraction_schemas_test.dart`.

Shared by all modes: the basic-info prompts and `PatientPostProcessor`'s default label take their country from the document (`CountryIdentifier.forDocument`: identifier names and field labels scored in the OCR text, the phone locale only when nothing or a tie matches), and lab-report prompts and their few-shot example no longer offer Condition. Phase 2 OCR is per page (`OcrPages`): lines of 8+ characters printed on every page (all but one from 3 pages up; letterhead, patient block, footer) are kept on the first page only. Each vision batch (`AiModelConfig.visionPagesPerBatch` pages: 2, or 1 for Qwen3.5-4B, whose ~840-token pages overflow the 4096 vision context two at a time with a long lab answer) gets its own pages' OCR, up to 2000 characters, and the few-shot example; in `schemaDraft` the vision draft call gets that OCR only (no example, no shape). Text calls (the fallback, and the constrained pass in `schemaDraft`) load at a 4096 context, or the smaller text context when 4096 does not fit in memory, and split the pages into chunks of (context − 1000 prompt − 1500 answer tokens [− 384 draft]) × 2 characters (3192 at 4096, at least 800), one constrained call per chunk, outputs merged and deduplicated by type and name. The earlier fixed 2000-character head (HM-181, a crash workaround at a 2048 context) left ~300 tokens for the answer and cut a 4-page lab report after its second test. `ObservationOcrValidator` adds or corrects an observation from an OCR line only when its unit is a lab unit (`%`, an SI-prefixed `g`/`mol`/`L`/`IU`/`UI`/`U`/…, `x10^n`, with `/denominators`) and its name is not a range row (ending in a dash), a page footer, or a phone, address or code label. `GenerationStats.finishReason` (`length` = truncated) is recorded per generation.

`fhir_r4_validation` (probe, 2026-10-26): not used. 0.14 needs `fhir_r4 ^0.14` (the app and `fhir_ips_export` are on 0.6), validates against an R4B (4.3.0) model, and ships no definitions: offline, with its default cache, every resource fails with "No StructureDefinition found". With the HL7 R4 or R4B `definitions.json` loaded into a cache it still needed two workarounds (complex types are looked up by bare name, and a binding to a terminology.hl7.org value set outside the core package throws and aborts the run), and then 32 of 40 `toFhirResource` samples (4 per type, from benchmark runs) failed on validator-internal errors on Reference, Period, Quantity and ContactPoint ("Element type or path is missing", "Context is null for <invariant>"), every type but Patient and Practitioner. 6 came out valid (2 Patients, 4 Practitioners); the other 2 Patients carry the one real defect it found, a model-written `gender` of `Female`, which the required administrative-gender binding rejects and the `schema` mode's gender enum rules out.

| Type                                                                                            | Location                                 |
| ----------------------------------------------------------------------------------------------- | ---------------------------------------- |
| `ProcessingBloc`                                                                                | `processing/presentation/bloc/`          |
| `ProcessingHandler` mixin (`DocumentImported`, `SessionActivated`, `ProcessRemainingResources`) | `processing/presentation/bloc/handlers/` |
| `SessionHandler` mixin (session lifecycle)                                                      | `processing/presentation/bloc/handlers/` |
| `AiModelDownloadService` (model + mmproj from HuggingFace, progress)                            | `processing/domain/services/`            |
| `NativeTextRecognitionService`                                                                  | `processing/data/services/`              |
| `ProcessingSession` (persisted in `ProcessingSessions`, not synced)                             | domain entity                            |

Models (`lib/core/config/constants/ai_model_config.dart`), downloaded on demand into the app documents directory:

| Model                       | Model   | mmproj | Notes                                                                                                                                                                          |
| --------------------------- | ------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Qwen3-VL-2B-Instruct Q4_K_M | 1056 MB | 445 MB | Default vision model                                                                                                                                                           |
| Qwen3.5-4B Q4_K_M           | 2614 MB | 641 MB | Advanced (recommended on 6 GB+ phones and on desktops without the RAM for 8B); skips the device check, needs full capability in the picker                                     |
| Qwen3-VL-8B                 | 4560 MB | 815 MB | Desktop only; skips the device check                                                                                                                                           |
| MedGemma 4B-IT Q4_K_M       | 2490 MB | 851 MB | Retired Advanced model (`retiredVariants`): no longer offered for download; listed as "Medical" and kept working only where its files are already on the device, until deleted |

Bench-only candidates (`AiModelVariant` values left out of `availableVariants`, so users can't pick them; `getActive` resolves any variant from the `aiSelectedModel` pref, so the benchmark runs the production path): Qwen3.5-2B, NuExtract 2.0-2B, NuExtract3 and MedGemma 1.5 4B (Qwen3.5-4B was one until it became Advanced). `AiModelConfig.promptFamily` (`standard`, `nuExtract2`, `nuExtract3`) picks the prompt: for the NuExtract families, schema-mode text calls send the OCR text as the only user message with no system prompt, and pass `NuExtractPrompt.kwargs` (the phase schema as a NuExtract template, plus `instructions` for NuExtract3) as llamadart `chatTemplateKwargs`. Without a template, NuExtract3's chat template falls into its document-to-Markdown mode. Grammar, schemaDraft and vision calls keep the standard prompts. Results are in `tool/extraction_bench/README.md` ("Model candidates", 2026-10-26, and the re-run on the multi-page phase-2 code, 2026-10-27: 48 synthetic documents plus 12 multi-page lab reports, simulator, text only). Lite: keep Qwen3-VL-2B (Qwen3.5-2B ties and truncates on multi-page reports, NuExtract 2.0 is worse). Advanced: Qwen3.5-4B replaced MedGemma 1 (ΔF1 +0.067 [0.046, 0.088] on 48 documents, +0.084 [0.024, 0.143] on multi-page reports, no truncation, Apache-2.0). NuExtract3 is no better than MedGemma (−0.009 [−0.049, 0.025]) and MedGemma 1.5 is worse (−0.087).

### Extraction benchmark

`tool/extraction_bench/` measures the pipeline's document→FHIR accuracy; usage, dataset layout, scoring and the de-identification rule for real documents are in `tool/extraction_bench/README.md`.

- `bench.dart` (pure Dart, `fvm dart run tool/extraction_bench/bench.dart`): `generate` writes seeded synthetic lab reports and discharge letters (EN/ES/DE/RO) as PDF plus a gold FHIR R4 Bundle; `score` matches predicted to gold resources per type (Hungarian), scores fields with FHIR-aware comparators (UCUM, partial dates, code tiers) and reports per-document F1 with document-level bootstrap CIs per stratum; `compare` runs a paired bootstrap between two runs; `oracle` writes gold-as-prediction as a sanity check.
- `integration_test/extraction_bench_test.dart` runs the production classes on a desktop or device (`--dart-define=BENCH_MODEL=<variant>`), reading `<documents>/extraction_bench/dataset/` and writing `<documents>/extraction_bench/results/<runId>/predictions.jsonl`. It mirrors `ProcessingHandler` (phase 1, `docCategory` from the container, phase 2) but skips the OCR pre-match against existing patients.
- The only production seam is `AiInferenceDataSource.lastGenerationStats` (`GenerationStats`: prompt/completion tokens, time to first token, prompt eval, duration), reset at the start of every `runVisionPrompt` / `runTextPrompt`. Image-encode time is read from llama.cpp's mtmd log lines, which only the runner subscribes to through `LlamaLogging.configure`.
- Datasets, results, models and real documents are never committed; keep them under `build/` or outside the repository.

## Database

`lib/core/data/local/app_database.dart`, `schemaVersion` 11. Tables: `FhirResource`, `Sources`, `RecordNotes`, `ProcessingSessions`. v1→8 migrate with drift `stepByStep` (there is no v4; `from3To5` covers it). v8→9 (per-patient wallet sources), v9→10 (sync triggers) and v10→11 are hand-written in `onUpgrade`. Snapshots for v1–3 and v5–11 are in `drift_schemas/my_database/`, generated test schemas in `test/drift/my_database/generated/`, tests in `test/drift/my_database/migration_test.dart`.

Synced tables have triggers that set `updated_at` on insert and on any update that leaves it unchanged.

## Mobile ↔ desktop communication

Mobile is the client, desktop the server. Frames are AES-256-GCM encrypted over TCP or, between Apple devices, MultipeerConnectivity (MPC, from `airdrop`).

### Pairing

Desktop shows a QR with a `DevicePairing` JSON: `deviceId` (UUID v4), `deviceName` (hostname), `pairingKey` (32 random bytes, base64url, the AES key), `lastIp`, `lastPort` (default 49152), optional `lastSsid`, `lastPassword`, `os`, and `pairedAt`. Mobile saves it through `PairingStorageService` (SharedPreferences key `device_pairing`) and connects.

### Discovery (mobile, `communication_bloc.dart`)

1. **Saved IP**: `lastIp:lastPort`, 5 s `Socket.connect()` timeout.
2. **mDNS + SSDP**: `MdnsService` and `SsdpService` in parallel, 3 s timeouts each. Both are awaited and the mDNS result is preferred; the saved IP is updated.
3. **MPC**: iOS/macOS only, waits up to 10 s.

If all fail: `CommunicationConnectionFailed` ("Desktop not found"). When an established connection drops, mobile retries with exponential back-off (3 s base, doubling, 5 attempts), then clears the pairing and asks for a new QR scan. A failed first connection is not retried.

| Mobile \ Desktop | macOS     | Windows |
| ---------------- | --------- | ------- |
| iOS              | MPC + TCP | TCP     |
| Android          | TCP       | TCP     |

`TcpService` holds one client. A second connection becomes a pending client, and the desktop shows an accept/reject dialog. The server binds to the machine's current local IP when it starts (port 49152, falling back to a random port, then to `anyIPv4`), on every platform; after a network change the saved IP is stale and the first reconnect falls through to mDNS/SSDP.

### Wire format

Key: the first 32 bytes of the base64url-decoded `pairingKey` (zero-padded if shorter). Message: `[12-byte random nonce][ciphertext + 16-byte tag]`. TCP adds a 4-byte big-endian length prefix; MPC sends without one. With no pairing key the payload goes out unencrypted.

The decrypted payload starts with a `MessageType` byte:

| Code | Type    | Meaning                                                                                                                             |
| ---- | ------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| 0x01 | `hello` | Handshake, JSON `{pairing_key_hash, device_name}` (hash: SHA-256 of the key, base64url). Receiver checks the hash and replies `ack`. The desktop server reads nothing else from a new connection until a valid hello arrives, closes it if none arrives within 15 s or the hash is missing or wrong, and caps frames at 64 KiB before the hello and 1 GiB after |
| 0x02 | `ack`   | Acknowledgement                                                                                                                     |
| 0x03 | `ping`  | Client keep-alive every 10 s; 5 s pong timeout                                                                                      |
| 0x04 | `pong`  | Reply to ping                                                                                                                       |
| 0x05 | `data`  | Application message, JSON `{type, payload}`, routed by `MessageRouter`                                                              |
| 0xFF | `kill`  | Graceful disconnect; receiver replies `ack` and closes                                                                              |

### Application messages

**LWW sync** (`desktop/lww_sync/`):

| Type                | Direction         | Meaning                                                                                                                                                              |
| ------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sync.delta`        | both              | Rows of one table changed since a timestamp (`SyncDelta`: table, rows, deviceId, timestamp). Attachments travel inline as base64 and are written to files on receipt |
| `sync.ack`          | both              | Acknowledges a delta                                                                                                                                                 |
| `sync.status`       | both              | Row counts per table; differing counts start reconciliation                                                                                                          |
| `sync.verify`       | both              | Counts after reconciliation                                                                                                                                          |
| `sync.file_request` | receiver → sender | Missing attachment paths                                                                                                                                             |
| `sync.file_data`    | sender → receiver | `path → base64` for those files                                                                                                                                      |

Conflicts: the later `updated_at` wins; on a tie the larger device id wins. Only `fhir_resource` stores a local `device_id`, so on a tie in `sources` or `record_notes` the incoming row nearly always wins. A local `DocumentReference` with a broken attachment loses to the incoming row. The delta query is `WHERE updated_at >= ?`; counts skip rows with `deleted_at` set; `LwwSyncInitialised` hard-deletes rows whose `deleted_at` is older than 30 days.

Deletes travel as `deleted_at` tombstones, with no wire or schema change:

1. A user delete of a `fhir_resource`, `sources` or `record_notes` row runs `UPDATE … SET deleted_at = :nowMs, updated_at = :nowMs`, in milliseconds through raw SQL, never through a drift `DateTime` (drift stores seconds). Already tombstoned rows are left as they are. Deleting a record or a source also tombstones the notes of the deleted records; clearing demo data and replacing a scan's DocumentReferences tombstone too. The statements live in one place, the `SoftDelete` extension on `AppDatabase` (`lib/core/data/local/soft_delete.dart`); repositories and data sources call it, and their delete methods (`RecordsRepository.deleteResource`, `deleteResourcesByIds`, `deleteResourceWithRelated`, `deleteRecordNote`, `clearDemoData`, `SyncLocalDataSource.deleteSource`, `DocumentReferenceService.deleteDocumentReferences`) are soft.
2. Tombstones travel in normal deltas (`computeDelta` does not filter them). LWW per row decides: the newer `updated_at` wins, so a later edit on the other device resurrects the row, and a full-table resend does not bring a deleted row back. Tombstoned DocumentReferences are sent without their files and restored without writing files, and a missing file on either side of a tombstone never overrides LWW.
3. Every UI and export read excludes `deleted_at IS NOT NULL` (records, related records, references, search, notes, sources, DocumentReferences of a scan). Row counts already did.
4. Every save or insert of a row clears `deleted_at` (upserts write `deleted_at = NULL`, and the `INSERT OR REPLACE` paths replace the whole row). The demo and wallet source rows leave `updated_at` to the trigger rather than drift (which stores seconds). The trigger stamps in millisecond units at whole-second precision (`strftime('%s') * 1000`), so a re-created row beats a tombstone from an earlier second, but a row re-created within the same second as its delete loses to the tombstone; this limit is accepted. In-place updates of a single column (raw JSON, specialty, note text, encounter link) leave `deleted_at` as it is, so they never resurrect a row.
5. `cleanupTombstones` (on `LwwSyncInitialised`) hard-deletes tombstones older than 30 days. A device offline for longer than that can bring the row back; this limit is accepted.
6. Mixed versions: a peer without this change stores incoming tombstones (they are ordinary rows), keeps showing the rows until it updates, and its own deletes stay hard, so they still come back from the updated peer.

Reset (`AppDataResetService`), `deleteAllFhirResources`, `deleteAllSources` and backup restore stay local hard wipes. The trigger stamps edits at whole seconds, so an edit made within the same second as a delete on the other device can lose to the tombstone.

Offline queue: `OfflineQueueService` keeps pending deltas in SharedPreferences (`lww_offline_queue`) and flushes them on reconnect; `lib/main.dart` clears the key on every mobile start.

**Backup** (`desktop/backup/`): desktop snapshots with `VACUUM INTO` to `~/Documents/HealthWallet/Backups/` (`USERPROFILE` on Windows).

| Type              | Direction         | Meaning                              |
| ----------------- | ----------------- | ------------------------------------ |
| `backup.request`  | mobile → desktop  | Take a snapshot                      |
| `backup.status`   | desktop → mobile  | Readiness                            |
| `backup.meta`     | sender → receiver | Size, SHA-256 checksum, chunk count  |
| `backup.chunk`    | sender → receiver | 64 KB chunk, base64                  |
| `backup.complete` | sender → receiver | Done; receiver verifies the checksum |
| `backup.error`    | either            | Failure                              |

`backup_bloc.dart` also sends `backup_start`, `backup_chunk` and `backup_complete`; nothing listens for them.

**Handover** (`desktop/handover/`): mobile offloads AI processing to desktop. `HandoverSenderService` sends on mobile; `HandoverService` receives on desktop.

| Type                      | Direction        | Meaning                                               |
| ------------------------- | ---------------- | ----------------------------------------------------- |
| `handover.offer`          | mobile → desktop | session_id, file_count, optional phase1_data          |
| `handover.accept`         | desktop → mobile | Accepted                                              |
| `handover.file`           | mobile → desktop | One image, base64                                     |
| `handover.progress`       | desktop → mobile | Inference progress                                    |
| `handover.step1_complete` | desktop → mobile | Patient extraction done (when phase1_data was absent) |
| `handover.result`         | desktop → mobile | Full FHIR resource list                               |

On `handover.step1_complete` and `handover.result` mobile clears its pending processing sessions and fires `LwwSyncBloc` `SyncTriggered`, so the records arrive through LWW sync.

**Tray** (`desktop/tray/`): `TrayService` owns the macOS/Windows tray icon and menu, `WindowLifecycleService` minimise-to-tray and restore, `TrayBloc` reflects connection and sync state.

## Proximity sharing encryption

Phone-to-phone shares (`share_records/`) are end-to-end encrypted in the app, on top of whatever the `airdrop` transport provides (an Android hotspot between iOS and Android, Wi-Fi Direct between Androids, MPC between iPhones). Crypto is in `data/crypto/share_crypto.dart`, the exchange in `data/service/secure_share_session.dart`, both on pointycastle: P-256 ECDH, HKDF-SHA256, AES-256-GCM.

1. The sender encrypts the payload JSON with a random 32-byte key K and transfers the envelope `"HWSE" | version 1 | SHA-256(sender public key) | nonce (12) | ciphertext + tag`, with the bytes before the nonce as associated data. The file holds no plaintext and not the sender's key.
2. After the transfer, over `airdrop` session messages (signal `-8`, see the package's ARCHITECTURE.md): the receiver sends `0x01 | receiver public key`; the sender answers `0x02 | sender public key`; the receiver checks it against the commitment.
3. HKDF over the ECDH secret (salt: sender key ‖ receiver key) gives the wrap key and a six-digit code. Both phones show the code (`SharePhase.verifyingCode`).
4. Only when the sender taps "Codes match" does it send `0x03 | nonce | K wrapped with the wrap key`. The receiver unwraps K, decrypts and opens the records.

The commitment makes the sender fix its key before seeing the receiver's, so a man in the middle cannot try keys until the two codes agree; with the sender's confirmation this protects the records' confidentiality. Receivers reject unencrypted (pre-encryption) payloads and older apps cannot open encrypted ones, so both phones need this version. Background receive mode (`ReceiveModeManager`) only holds the envelope; the share screen runs the exchange so the code is visible.

**Session lifecycle.**

- After "Codes match" the sender is in `SharePhase.awaitingViewer` until the receiver reports it is viewing. Every way out of that phase goes through `killSessionRequested`, since the receiver already has the key. If the kill can't be handed to the transport, the sender is told the other phone keeps the records until its timer ends (`remoteEndUnconfirmed`).
- The receiver ends the session when the connection drops, when the app is paused or hidden (not on `inactive`, which also covers Control Center and system prompts), when cancelled, or at expiry. Cancelling or leaving while decrypting stops the records from opening.
- Received notes are served from memory (`SharedNotesDatasource` behind `RecordsRepository.showSharedNotes`) and never written to `record_notes`, so they aren't synced and can't be left behind.
- Decrypted attachments live in `tmp/share_session_<id>/`, which is deleted by its own path when the session ends or the screen closes. `ShareRecordsService.sweepLeftovers()` runs at mobile startup and removes session folders and `share_*.bin` payloads left by a kill or crash.
- The share page owns screen protection from the moment records open until it closes, and pops anything opened on top of it (records, documents, dialogs) when the session ends.
- While a share screen owns the transport, receive mode is paused (`ReceiveModeService.isPaused`) and the app's lifecycle handler leaves it alone, so locking the phone doesn't cut a live share.

## CI/CD

GitLab CI (`.gitlab-ci.yml`) on `git.techstackapps.com/mobile/health-wallet/app`.

- **checks**: every push, Linux runners, `debian:bookworm-slim` with Flutter cloned at the pinned tag (cirruslabs images stop at 3.44). Runs `flutter pub get`, `dart run build_runner build`, `flutter analyze --no-fatal-infos --no-fatal-warnings`, `flutter test`. No secrets.
- **ios:testflight / macos:testflight / android:play-internal**: automatic on `develop`, manual elsewhere (the branch must be protected to see protected variables). `shell-macmini` runner, fastlane `beta`, one `resource_group` each. Automatic signing: certificates in the runner's login keychain, profiles via the App Store Connect API key and `-allowProvisioningUpdates`. Android Gradle runs on Temurin JDK 17 (`ANDROID_JDK_*`, cached per runner, set through `org.gradle.java.home`).
- **shorebird:patch-android / shorebird:patch-ios**: manual on `master`.
- **windows:release**: manual on any branch; `master` → `v<version>`, others → `v<version>-dev.<pipeline iid>`; uploads zip + msix to the generic package registry and creates a GitLab Release. Needs a `windows` runner (none registered yet).
- Private pub dependencies are fetched with `CI_JOB_TOKEN` (the project must be on their job-token allowlists).
