---
title: 'Scan and AI settings apply as shown: token limit, Deep Scan, PDF quality, download cancel, out-of-memory message'
type: 'bugfix'
created: '2026-11-03'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'b079f4f5b097bbb7b2d2b679f00894e7e5b65b6c'
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The AI settings don't do what the screens say:
- Preferences defaults the token limit to 500 and saves every value on Save, so one Save caps mobile scans at 500. The Processing screen also saves every value, so its first Save always restarts mapping.
- Deep Scan changed in Preferences doesn't reach the running Processing screen, and the dialog defaults it off while desktop scans default it on.
- PDF pages reach OCR and the AI at 72 dpi.
- Cancelling a model download leaves the transfer running, and the model then shows as downloaded.
- Running out of memory tells the user to raise the context size.

**Approach:**
- One default per setting.
- Both screens save only what changed. Deep Scan goes through `VisionToggled`.
- A one-time reset of values the bug saved.
- A separate 200 dpi page set for OCR and the AI, rendered in the background and kept in step with page edits.
- Cancel that really stops each transfer.
- One honest out-of-memory message on every platform.

## Boundaries & Constraints

**Always:**
- Write a failing test first, and un-skip the `BUG:` test in `processing_failures_test.dart`.
- The 72 dpi preview images and their cache keys stay as they are.
- `capacityFailure` keeps its context-size wording and its Increase AI Capacity button.
- New strings go into all four ARBs, placed next to the related processing keys (not at the end of the file), followed by `fvm flutter gen-l10n`.
- Run `fvm dart run build_runner build` after changing Freezed state or events.
- Every touched handler sets a `transformer:`.
- Log cancel and cleanup errors with `logger`.

**Never:**
- Add constructor parameters to `ProcessingBloc` (`feature/holders-and-sources` rewrites it) or touch `processing_handler.dart:272-340,506-675`.
- Change the `processing_sessions` schema (holders bumps the schema to v14).
- Change the handover protocol or the phone's handover failure text.
- Change how the desktop picks its context size, threads or GPU layers.
- Call `FileDownloader().cancelAll()`.
- Add a cancel button for the vision (mmproj) download.
- Remove the dead download methods (a later slice).
- Change model files, ids or the GGUF check.
- Add an OCR Flutter plugin.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fresh install, AI settings | Nothing saved | Preferences and Processing both show 4,096; Save with no change writes nothing and doesn't restart mapping | N/A |
| Change one value | User changes context size only | Only that value is saved | N/A |
| First start after update | `aiMaxTokens`=500 saved; desktop `aiUseVision`=false saved | Both removed once, so defaults apply; a flag stops it running again | N/A |
| Deep Scan toggled in Preferences | Processing screen alive | Progress bar and step-2 banner follow it without restart | N/A |
| Defaults | Nothing saved | Deep Scan on for desktop, off for mobile, on every screen | N/A |
| PDF scan | Text-heavy page | Preview shows at 72 dpi right away; OCR and AI use 200 dpi pages rendered off the UI isolate | Render failure logged, falls back to the 72 dpi page |
| Reorder, delete, rotate | Pages edited in preview | The 200 dpi set follows the same order, deletion and rotation | N/A |
| Edited session reopened after restart | Pages were reordered or deleted, app closed | 200 dpi pages are rebuilt from the original PDF pages recorded in the session's page map | If the original is gone, falls back to 72 dpi and logs |
| Session saved, reset or deleted | Has 200 dpi pages | Its 200 dpi pages and page map are deleted (they aren't kept as cache) | Logged |
| Reset or session delete | Session with page images | Its 72 and 200 dpi page images are deleted | Logged |
| Cancel download | Dio (desktop) or background_downloader (mobile) running | Every running model download stops; the separate vision-file download keeps running; the model shows as not downloaded; the notification is removed; a partial `.tmp` is deleted after the transfer has ended | Logged |
| Restart download quickly | Same variant | One clean writer; no `.tmp` race | N/A |
| Out of memory | `Not enough memory` from inference, phone or desktop | New message with the Retry button only | Logged |

**Decisions (2026-11-03):**
- OCR and AI pages use 200 dpi on every device; the preview stays at 72. On phones the AI shrinks images to 560 px anyway, so the gain there is OCR. Desktop vision gains too.
- The out-of-memory message is the same on phone and desktop. It doesn't mention Context Size, because the desktop ignores it:
  - en: "Not enough free memory to run the AI model. Close other apps and try again, or turn off Deep Scan in AI Settings."
  - es: "No hay suficiente memoria libre para ejecutar el modelo de IA. Cierra otras apps e inténtalo de nuevo, o desactiva el Escaneo profundo en Ajustes de IA."
  - de: "Nicht genügend freier Speicher, um das KI-Modell auszuführen. Schließe andere Apps und versuche es erneut, oder schalte den Tiefenscan in den KI-Einstellungen aus."
  - ro: "Nu există suficientă memorie liberă pentru a rula modelul AI. Închide alte aplicații și încearcă din nou, sau dezactivează Scanare Profundă din Setări AI."
- When the desktop runs out of memory during a handover, the phone keeps today's generic failure.
- After a cancel, the download notification is removed and the model shows as not downloaded.
- Settings the bug saved are reset once: `aiMaxTokens`=500 everywhere and `aiUseVision`=false on desktop.
- The Processing screen also saves only changed values.
- Cancel keeps today's scope: every running model download stops. The separate vision-file (mmproj) download keeps running.
- 200 dpi is kept even for edited sessions reopened after a restart. Each session keeps a small page map: a JSON file next to its preview pages that maps every preview page to its original PDF and page number. Nothing changes in the database. The 200 dpi pages are temporary and are deleted when the session is saved, reset or deleted, to save space.

</frozen-after-approval>

## Code Map

All paths are under `lib/features/` unless they start with `lib/` or `test/`.

- Settings:
  - `user/presentation/preferences_modal/sections/ai-model/ai_model_section.dart:363` uses `?? 500`. `:374-378` writes all five settings, and `:378` is Deep Scan.
  - `processing/presentation/widgets/ai_settings/ai_settings_dialog.dart`:
    - `AiSettingsResult` (`:25-39`) doesn't carry the values the dialog opened with. Those are computed in `show()` (`:81-98`), and `:85` uses `?? false`.
    - Return both the opening and the chosen values, or only the changed fields.
    - 4096 maps to `custom` (`:219-224`); the presets are in `ai_settings_token_section.dart:8-12`.
  - `processing/presentation/pages/processing/processing_page.dart:155-157` (tokens) and `:168-173` (GPU, threads and context written on every Save).
  - `lib/core/config/constants/app_constants.dart:8-9` -- `defaultMaxTokens` and `maxAllowedTokens`.
- `processing/presentation/bloc/processing_bloc.dart`:
  - `:187-188` reads `useVision` once.
  - `:225-231` `VisionToggled` (event at `processing_event.dart:195`).
  - Don't use `TokenCapacityUpdated` (`:216-223`): it needs a session and restarts mapping.
  - `ProcessingBloc` is `@LazySingleton` (`:38`). Preferences can call `getIt<ProcessingBloc>().add(VisionToggled(...))`.
  - Put the Deep Scan default in a pure function `defaultDeepScan(bool isDesktop)` in `processing/domain/` and use it at `:187`, in `processing_handler.dart:384-385` and in the dialog `:85`. Keep `@Default(false) useVision` (`processing_state.dart:88`) consistent with it.
  - Run the one-time reset in `onProcessingInitialised` (`processing_bloc.dart:176`, registered at `:90`), through the prefs access it already uses. Guard it with a pref flag.
- Page images:
  - `processing/data/services/pdf_conversion_mixin.dart:138-140`, `convertPdfToImagesForPreview(dpi:)`, with its cache key at `:63-74`. Call it with `dpi: 200`. Don't use the PNG `convertPdfToImages` (`:15-52`).
  - `processing/domain/services/ocr_processing_service.dart:36-61` `prepareAllImages`.
  - `processing/presentation/bloc/handlers/session_handler.dart`:
    - `:278` calls `prepareAllImages`.
    - `:266-271` is the cache check.
    - `:343-367` `onPagesReordered` rewrites `sessionImagePaths` and the stored `filePaths`, sent from the preview at `processing_page.dart:319-327`.
  - Rotate changes the preview file in place (`lib/features/capture/scan/presentation/pages/preview/bloc/preview_bloc.dart:41-55`) and never tells `ProcessingBloc`. Add an event, e.g. `PageRotated(previewPath, quarterTurns)`, sent from the preview, so the 200 dpi page rotates too.
  - `PagesReordered` carries only paths, so match pages by path, not index. Add `ocrPageByPreviewPath` (`Map<String, String>`) to `processing_state.dart`.
  - Write the page map `pdf_preview_cache/<sessionId>.pages.json` (preview path → original file and page number) when pages are prepared, and update it on reorder and delete.
  - `Printing.raster` and the documents path use platform channels, so rasterizing stays on the main isolate. Run only the decode, composite and JPEG encode in `Isolate.run`, after the preview list is ready.
  - Consumers fall back to `?? allImagePathsForOCR` at `processing_handler.dart:87,105,183,363`.
  - No schema change: `processing_sessions` stores only `filePaths`. The handover keeps sending `filePaths` (`lib/features/desktop/handover/presentation/utils/handover_utils.dart:115`).
- Cache cleanup:
  - Page images live in `Documents/pdf_preview_cache/<key>_page_N.jpg`.
  - `lib/core/services/temp_file_sweeper.dart:107,192-210` deletes only `<hex>.json` there, and only on Reset.
  - Delete a session's page images and page map on Reset, on session delete and when the session is saved.
  - Session delete is `lib/features/processing/data/repository/processing_repository_impl.dart:310-317`, reached from `session_handler.dart:194-231`. It deletes with `.ignore()` and logs nothing; make it log.
- Download cancel:
  - Live path: `notifications/notification_widget.dart:346` → `processing/presentation/pages/load_model/bloc/load_model_bloc.dart:447-461` (add `droppable()`) → `processing/domain/services/ai_model_download_service.dart:289-301`.
  - The repository streams in `processing/data/repository/processing_repository_impl.dart:346-366,380-400` need an `onCancel`.
  - `processing/data/data_source/network/ai_inference_data_source.dart`, a LazySingleton:
    - Dio at `:383-406`: keep a `CancelToken` per file name, and await the transfer's end before deleting the `.tmp`.
    - background_downloader at `:427-450`: keep the `taskId` per file name and call `cancelTaskWithId` (it exists in 9.5.4). The file moves in only on completion.
    - Make `Dio` and `FileDownloader` injectable through the constructor or a factory so tests can replace them.
  - Notifications: the `cancelled` branch (`load_model_bloc.dart:397-433`) turns the notification into an error. Instead, send `NotificationRemovedById` for every `downloadingVariants` entry before the map is cleared.
  - `_addCancelledNotification` (`:435-445`) uses the wrong id. Remove it.
- Memory failure:
  - `processing/presentation/bloc/processing_state.dart:37,46` maps `notEnoughMemory` to `processingFailedCapacity`.
  - That key is shown in `processing/presentation/pages/processing/widgets/processing_mapping_section.dart:148` and `processing/presentation/widgets/capture_error_listener.dart:32`.
  - The ARB keys are near en `:226-228`, es `:217-219`, de `:213-215` and ro `:216-218`. The new key is `processingFailedMemory`, placed right after `processingFailedCapacity` in each file.
- Tests:
  - `test/features/processing/presentation/bloc/processing_failures_test.dart`:
    - `:87` fake
    - `:196` mapping
    - `:213-224` the `BUG:` skip
  - `test/features/processing/presentation/widgets/processing_mapping_section_test.dart:67,142`
  - `test/features/processing/data/services/pdf_conversion_mixin_test.dart`
  - Fakes in `processing_session_steps_test.dart:85`, `processing/l10n/processing_l10n_test.dart:55`, `capture_error_listener_test.dart:19`.
  - `test/features/processing/l10n/load_model_bloc_l10n_test.dart:98` expects the cancelled notification. Rewrite it.
  - Holders edits these test files too, so prefer new test files.

## Tasks & Acceptance

**Execution:**
- [x] `processing_failures_test.dart`, `processing_state.dart`, the ARBs, then gen-l10n:
  - Un-skip the memory test and fix `:196`.
  - Add the new key with the Decisions text.
- [x] `processing/domain/deep_scan_defaults.dart` (new) and its test -- `defaultDeepScan` for both platforms. Use it in the bloc, the handler and the dialog.
- [x] `ai_settings_dialog.dart`, `ai_model_section.dart`, `processing_page.dart` (with a new `test/features/processing/presentation/widgets/ai_settings/ai_settings_dialog_test.dart`: the dialog shows the platform's Deep Scan default, and an unchanged Save on the Processing screen writes nothing and doesn't restart mapping):
  - Save only changed values.
  - Use the `AppConstants` token default.
  - Send Deep Scan through `VisionToggled`.
  - New widget test `test/features/user/presentation/preferences_modal/sections/ai-model/ai_model_section_test.dart`: 4,096 on a fresh install, nothing written on an unchanged Save, Deep Scan reaches `ProcessingBloc`.
- [x] `processing_bloc.dart` `_onInitialised` -- The one-time reset with its flag, plus `sequential()` on `VisionToggled`. Tests: reset happens once, values are kept on the second start, desktop-only vision reset.
- [x] `processing_state.dart`, `processing_event.dart`, `session_handler.dart`, `ocr_processing_service.dart`, `processing_handler.dart`, `preview_bloc.dart`:
  - `ocrPageByPreviewPath` at 200 dpi, with encoding in an isolate.
  - The page map file.
  - Kept in step with reorder, delete and rotate (the new `PageRotated` event).
  - Rebuilt from the page map when an edited session is reopened.
  - Falls back to the 72 dpi pages on error.
  - Then run build_runner.
- [x] New `test/features/processing/presentation/bloc/processing_ocr_images_test.dart` -- OCR and AI receive 200 dpi; the preview stays at 72; reorder, delete and rotate stay matched; an edited session reopened after a restart rebuilds 200 dpi from the page map; a missing original falls back; the 200 dpi pages are deleted when the session is saved.
- [x] `temp_file_sweeper.dart` and the session delete path -- Remove the page images, with tests.
- [x] `ai_inference_data_source.dart`, `processing_repository_impl.dart`, `ai_model_download_service.dart`, `load_model_bloc.dart` -- Per-file cancel, awaited `.tmp` cleanup, notification removal.
- [x] New `test/features/processing/data/data_source/network/ai_inference_data_source_cancel_test.dart` and a rewritten `load_model_bloc_l10n_test.dart:98` -- No final file after cancel; the variant is absent; the vision download is untouched; a quick restart is clean.

**Acceptance Criteria:**
- Given a cancelled download, when the app restarts, then the model is not listed as downloaded.
- Given a 5-page PDF on a 4 GB phone, when it is scanned, then the preview appears as fast as before. This is checked on a device.

## Implementation Notes

- Choices that don't block the work and aren't settled by this spec may be decided during implementation; record each one here with its reason.
- Package B, 200 dpi pages (worktree `.claude/worktrees/agent-a8314af9702caccbe`):
  - `onSessionActivated` shows the 72 dpi previews first. For a session that isn't a draft it then awaits `OcrProcessingHelper.prepareOcrPages` (200 dpi) before mapping starts; consumers use `state.ocrPagesFor(sessionId)`, which falls back to the preview.
  - Rasterising stays on the main isolate. Decode, composite and JPEG run in `Isolate.run`. JPEG quality is 85 above 72 dpi and stays 75 at 72.
  - The page map `pdf_preview_cache/<sessionId>.pages.json` (written atomically through a temp file and rename) holds each page's original file (relative, via `PathResolver`), page number and `quarterTurns`, plus the preview and OCR cache keys.
  - Rotation:
    - `PreviewBloc({onPageRotated})` sends `PageRotated`.
    - Rotated 200 dpi pages are written as `<key>_page_N_r<turns>.jpg` copies, never rotated in place.
    - The preview rotate handler is `droppable()` and logs failures.
  - On save, `onTransition` in `SessionHandler` detects success (the handler body is in a range holders rewrites) and sends the internal `OcrPagesReleased`.
  - Session delete removes the 72 and 200 dpi pages and the map. `deleteProcessingSession` awaits each delete and logs failures. Reset also removes `_rN` copies, page maps and `.tmp` leftovers.
  - Transformers: `sequential()` on `PageRotated`, `OcrPagesReleased` and (at merge) `PagesReordered`; `concurrent()`, made explicit, on `SessionActivated`, `SessionCleared` and `ProcessRemainingResources`.
  - `OcrProcessingHelper` gains a `PathResolver` constructor parameter.
  - Known limits:
    - After an edit, `filePaths` are the 72 dpi previews, so saved documents and the desktop handover still use 72 dpi.
    - The original import in `Documents/imports` is not deleted with its session.
    - A pending session's mapping starts after its 200 dpi pages are rendered (a few seconds on a slow phone).
    - A 72 dpi preview re-rendered after a cache miss loses its rotation.
- Merge (2026-11-03): packages A, B and C applied to the branch with no conflicts. Added `transformer: sequential()` to `PagesReordered`. Removed the now-unused `aiModelDownloadCancelledTitle`, `aiModelDownloadCancelledNotificationTitle` and `aiModelDownloadInterruptedMessage` from all four ARBs, then ran gen-l10n (untranslated `{}`) and build_runner. `scripts/check.sh`: format and analyze clean; the full suite passes (2,608). A desktop pairing timing test failed once under load from parallel agents and passes 5/5 alone.
- Package C, download cancel (worktree `.claude/worktrees/agent-a7ca60f26b58e5256`):
  - The data source keeps one `CancelToken`/`taskId` per file. A restart of the same file waits for the old transfer to end.
  - New interface methods `cancelModelDownloadForVariant` and `cancelMmprojDownloadForVariant` return once the transfer has ended and its partial file is gone. The wait is capped at 15 s, with a log line.
  - Dio streams the response itself (`dio.get` with back-pressure) instead of `dio.download`, which returned before its own `.tmp` cleanup. Each download gets its own Dio, so the HuggingFace `Authorization` header doesn't leak through the shared one.
  - background_downloader: the task id is recorded before the first await; `cancelTaskWithId`, never `cancelAll`; negative progress markers are no longer reported; a task that completes while being cancelled has its file deleted.
  - Test seams are optional `@ignoreParam` constructor arguments; the generated DI is unchanged.
  - `integration_test/extraction_bench/recording_data_source.dart` passes the two new methods through.
  - The service cancels every model subscription in parallel and waits, then reports one cancelled state per variant. The vision subscription is untouched.
  - Bloc transformers: `droppable()` on cancel, `sequential()` on `LoadModelServiceStateChanged`, `restartable()` on `LoadModelInitialized`. `_addCancelledNotification` is removed.
  - Tests: `ai_inference_data_source_cancel_test.dart` (13), `load_model_bloc_cancel_test.dart` (4), plus the rewritten l10n test at `:98`. Mutation checks fail as expected.
  - Left over: `aiModelDownloadCancelledTitle`, `aiModelDownloadCancelledNotificationTitle` and `aiModelDownloadInterruptedMessage` are unused now; remove them at the spec 2 merge.
  - Device checks:
    - Android notification removal, including background_downloader's own notification.
    - A quick restart leaves no `.tmp`.
    - The vision download keeps running.
    - The macOS cancel responds right away.
- Package A, settings and memory message (worktree `.claude/worktrees/agent-a9cd3c4ce4fb301f6`):
  - `AiSettingsResult` fields are nullable (null means unchanged). The dialog reads the saved token value itself, with `AppConstants.defaultMaxTokens` as the fallback.
  - `TokenCapacityUpdated.newMaxTokens` became optional, so changing only the context size doesn't also save a token limit.
  - The reset decision is a pure function in `processing/domain/ai_settings_reset.dart`; the bloc does the reads and writes, guarded by `SharedPrefsConstants.aiMistakenSettingsReset`. The bloc and handler keep `Platform.is*` (no constructor change), and the dialog uses `getIt<AppPlatform>()`.
  - `ProcessingInitialised`, `TokenCapacityUpdated` and `VisionToggled` use `sequential()`.
  - `@Default(false) useVision` is left as it is (it equals the mobile default).
  - A saved 500 is reset even if the user chose Medium, as decided.
  - Tests: `deep_scan_defaults_test`, `ai_settings_reset_test`, `processing_ai_settings_test`, `ai_settings_dialog_test`, `ai_model_section_test`, `processing_memory_failure_test`, plus the helper `test/helpers/ai_settings_dialog_driver.dart`. The full suite passes (2,499).

## Spec Change Log

## Review Triage Log

All `patch` rows below were fixed by the package agents and are in the commit `fix(processing): keep cancels, page edits and token limits correct in edge cases`. `scripts/check.sh` passed afterwards (2,626 tests).

| # | Source | Finding | Verdict | Evidence | Route |
|---|---|---|---|---|---|
| 1 | blind, edge | Cancel lost before the transfer registers, or on cancel → restart → cancel | medium | `_cancelDownload` returns when `_transfers[filename]` is null or finds the old cancelled transfer while the restart waits | patch |
| 2 | blind, edge | The restart wait on `previous.ended` is unbounded | medium | A native cancel that never ends hangs later downloads at 0% | patch |
| 3 | blind, edge | `LoadModelBloc` cancel emits `modelAbsent` despite the re-check, and clears vision-only or new variants | medium | Status is hard-coded; the maps are cleared wholesale | patch |
| 4 | edge | `SessionCleared` during activation writes pages for a deleted session | medium | No existence re-check after the render steps | patch |
| 5 | edge | Activation's early return skips 200 dpi preparation and rotation recording | medium | `:301-314` returns before `_prepareOcrPages`; `rotateOcrPage` needs a map entry | patch |
| 6 | blind, edge | `_turned` writes non-atomically and reuses a truncated file | medium | Direct write plus an `exists()` reuse | patch |
| 7 | edge | A non-preset saved token value is snapped to a preset, so an unchanged Save overwrites it and restarts mapping | medium | `_presetFromValue` versus the new changed-only detection | patch |
| 8 | blind, edge | The original import is orphaned when an edited session is deleted | medium | Only the page map refers to it after an edit; it is a health document | patch |
| 9 | verification | Processing-screen context, GPU and thread save untested | medium | Only the token and Deep Scan cases exist | patch |
| 10 | verification | Preview turn → `PageRotated` wiring untested | medium | Only the bloc callback and direct events are tested | patch |
| 11 | verification | Mobile `TaskStatus.failed` untested | medium | The fake completes only with complete or canceled | patch |
| 12 | blind | An OS-side cancel shows as a download failure | low | Rare | reject |
| 13 | blind | An interrupted download gives no feedback since the notification was removed | false | The old code targeted the wrong id, so it showed nothing either | reject |
| 14 | blind | The reset wipes a deliberate 500, runs late, keeps the pinned GPU, threads and context | low | 500 per decision; Save writes nothing unchanged now; pinned load settings need a decision | defer |
| 15 | blind | Orphaned 200 dpi pages after a crash | low | Pages belong to a session that still exists and are reused or removed with it | reject |
| 16 | blind | A pending session waits for the 200 dpi render | low | Documented limit | reject |
| 17 | blind | Two platform sources for the Deep Scan default | low | Documented: no `ProcessingBloc` constructor change | reject |
| 18 | blind | Generated l10n missing from the diff | false | Excluded from the review diff on purpose; regenerated and in the tree | reject |
| 19 | blind, verification | Legacy `downloadModel`/`downloadMmproj`/`cancelMmprojDownload` not cancellable | low | No callers in `lib/`; removed in batch 2 | reject |
| 20 | blind | No progress without `Content-Length`; missing service and repository tests | low | Pre-existing; covered by the data-source tests | reject |
| 21 | edge | A native task outliving the app lands the file after a cancel | low | Needs a failed native cancel plus an app exit | reject |

## Verification

**Commands:**
- `fvm dart run build_runner build` -- expected: succeeds
- `fvm flutter test test/features/processing test/features/user test/features/capture test/core/services` -- expected: all pass, no `BUG:` skip left in `processing_failures_test.dart`
- `scripts/check.sh` -- expected: no issues

**Manual checks (if no CLI):**
- On an Android phone: cancel a model download; the notification disappears and `ai_models/` has no file for that variant.
- Scan a PDF with small print on a 4 GB phone and on macOS: the preview is quick, the text is read better than before, and there is no freeze.
