# Mobile → desktop handover audit

Audit of handing a document from the phone to the desktop for processing, for triage. Written 2026-11-10 against `develop` at `4c9eb27e`.

**Scope.** The handover feature (`lib/features/desktop/handover/`: `HandoverSenderService` on the phone, `HandoverService` and `HandoverBloc` on the desktop, the send dialog, the desktop Handover tab, `HandoverUtils`). Also every place that starts one (the processing page, the resources section, the session list, the load-model page), the parts of `ProcessingBloc` a handover drives on the desktop (`DocumentImported` with phase-1 data, `SessionActivated`, `ProcessRemainingResources`, `SessionCleared`), the dashboard listeners that announce results, and the desktop start-up hook that resends results. The link underneath (handshake, frames, reconnects) was audited in `sync-audit.md` and is used here as it now stands. The problems already tracked elsewhere are listed under [Known issues](#known-issues).

**Method.** One review: the code was read end to end on both sides, and every finding below was re-read at the cited lines. The existing tests were read too (`test/features/desktop/handover/`), including the five skipped `BUG:` tests. _Verified_ means the outcome follows directly from the code, or a test shows it. _Traced_ means the path was followed but the outcome depends on timing or data. _Device_ means it needs a phone and a desktop to confirm. One throwaway test (deleted afterwards) confirmed A2: a fresh `HandoverSenderService` that receives a `handover.result` for a session it never sent clears every queued session and announces "Desktop finished processing". Nothing was changed in the code.

## Summary

| Severity | Count |
| -------- | ----- |
| Critical | 0     |
| High     | 7     |
| Medium   | 7     |
| Low      | 10    |
| Test gap | 5     |

**What holds up.**

- **Only the paired phone can hand over.** Handover messages travel inside the verified, encrypted link session, so a stranger can't offer documents to the desktop or read the results.
- **Received file names can't escape the imports folder.** The desktop keeps only the base name the phone sent and writes into `Documents/imports`.
- **A missing model is reported with a reason code.** The desktop sends `reason: model_not_found`, the phone also understands older desktops' English text (`_remoteFailure`), and both show localized messages.
- **The phone stops its own processing only after the files are sent** (`_isSent`), so a failed send leaves its work running. Cancelling before the accept sends no files, and a file deleted after the offer fails the session cleanly.
- **A desktop draft goes through the normal review and save.** Layout extractors apply too. Once saved, the records reach the phone through the outbox, which survives drops and restarts.
- **A repeated result is handled once** while the phone app keeps running.

**Where it breaks.**

1. **The phone deletes documents it never sent.** Any result clears every queued session on the phone with its files. The desktop resends every result it ever produced on each reconnect, and the phone forgets which ones it handled when it restarts (A1, A2).
2. **The desktop doesn't know which session is the handover's.** It takes the first session whose origin is "handover", so a draft left from an earlier handover is sent as the new result and the new document is never processed. Phase 2 of a PDF can read the pages of the last document opened on the desktop (A3, A4, B1, B4).
3. **The transfer has no failure path.** A file over about 12 MB closes the link. A failed send leaves the phone's dialog spinning and the desktop's card "receiving" forever. Pages can arrive reordered, duplicated or overwritten (A5, A6, B2, B3).
4. **"Finished" means "waiting for someone at the desktop".** The desktop stops at a draft (or after the patient step), and nothing reaches the wallet until a person reviews and saves it there. The phone says "Desktop finished processing" and offers "Go to records" (A7).

## Proposed order

| Step | Issues                     | Why                                                                                                                                                                                                                                                                        |
| ---- | -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | A1, A2                     | Data loss on the phone, in normal use. Phone only, small: act only on results for sessions this phone started, clear only that session's source, and persist which results were handled. The desktop side of A2 (drop a result once the phone acknowledged it) can wait for step 3 |
| 2    | A3, A4, B1, B4             | Desktop only, no protocol change: tie the handover to the session its `DocumentImported` created, keep per-handover state in a map, start phase 2 from that session's own pages, and queue a phase-1 session while the desktop is busy                                      |
| 3    | A5, A6, B2, B3, B5, B8, B9 | A transfer that fails visibly and recovers: files in indexed chunks, the accept listener attached before the offer, errors and timeouts on both ends, a `handover.cancel`, results acknowledged and then dropped. A protocol change: phone and desktop ship it together (backlog rule 4) |
| 4    | A7                         | Needs a product decision (below), then the messages and possibly where the review happens                                                                                                                                                                                  |
| 5    | B6, B7, then C             | Leftover copies on the desktop, one entry point, conventions                                                                                                                                                                                                                |
| 6    | T1–T5, alongside each step | A failing test first for each fix (backlog rule 1). T1 rewrites a test that currently asserts A1 as intended behaviour                                                                                                                                                    |

Step 3 changes what goes over the wire. To avoid bumping the link version for it, the offer can carry a handover version and the accept can answer which one the desktop speaks, so an updated phone still works with an old desktop the old way.

**Decision needed (A7).** Where is a handed-over document reviewed?

- **On the desktop.** This is how it works today. The phone should say "Ready for review on the desktop", and the desktop should announce it.
- **On the phone.** The phone turns the `handover.result` it already receives (resources, patient, encounter) into a draft session and reviews it like its own scan; the desktop then keeps no draft.

## Status

Implemented on `feature/handover-stabilization`. Nothing has run on devices yet. `scripts/check.sh` passes except the two SSDP tests, which fail on any machine where another app holds UDP port 1900.

**A7, decided 2026-11-10: both.** The desktop runs the AI and keeps its draft, and sends the draft to the phone, which turns it into a normal draft session. Either device can review and save it; the first save tells the other, which drops its draft. Saving on both while apart writes the same rows (the draft's ids, document ids derived from the session), which the LWW sync merges.

The handover protocol is version 2: the phone and the desktop must both be updated. An older desktop never answers an offer, and the phone says to update it; an older phone's offer is rejected. How it works now is in `architecture.md`, "Handover".

| Issue  | Status                                                                                                                                                              |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1, A2 | Fixed. A result applies to its own session only; results for sessions the phone doesn't have are acknowledged and dropped; messages wait in an outbox until acknowledged |
| A3     | Fixed. The desktop session takes the phone's session id; everything is tracked by id                                                                                |
| A4     | Fixed. Every step reads its own session's pages, prepared when missing                                                                                              |
| A5     | Fixed. Files go in 256 KiB chunks, assembled by index and offset; 200 MB per handover                                                                              |
| A6     | Fixed. Every failure ends the transfer with a reason; a cancel or a drop tells the desktop, which also times out after 60 s                                          |
| A7     | Done as decided above                                                                                                                                               |
| B1     | Fixed. The queue continues a handover after its patient step; a step interrupted by closing the app starts again                                                     |
| B2, B3 | Fixed                                                                                                                                                               |
| B4     | Fixed. Failures carry their session id                                                                                                                              |
| B5     | Fixed. The phone keeps the document as "On the desktop" until the draft comes back; failures and deletes on the desktop return it with a notification            |
| B6     | Fixed. Received files go to a temporary folder, deleted once processing has its copies                                                                              |
| B7     | Fixed. The load-model page hands over the document it was opened for, through the same path                                                                       |
| B8, B9 | Fixed. Messages survive restarts in the outbox; the Handover tab shows only transfers in progress                                                                  |
| C1–C8  | Fixed, except C2 in part: `HandoverBloc` and `PhoneHandoverBloc` (presentation) drive `ProcessingBloc`; the services no longer use `getIt` or the blocs                |
| T1–T5  | Done: the old service tests are replaced by tests over a linked pair of fake links, both blocs and the processing steps                                           |

Also fixed with them: tapping a notification without a route does nothing (part of `mobile-stabilization.md` B6), and a document's records keep stable ids when a session is saved again.

## Known issues

Already tracked, not repeated as new findings:

| Where                               | Issue                                                                                                                 | Here                                                       |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `mobile-stabilization.md` §9        | A result clears every pending session on the phone                                                                    | A1 adds that the files are deleted, and A2 that it repeats |
| `mobile-stabilization.md` §9        | The desktop tracks one handover at a time                                                                             | Part of A3                                                 |
| `mobile-stabilization.md` §9        | Skipped tests pin file ordering, duplicate files and name clashes                                                     | B2                                                         |
| `mobile-stabilization.md` B6        | Handover notifications have an empty route                                                                            | Unchanged (`dashboard_page.dart:90-102`)                   |
| `sync-audit.md` C12, "Still present" | `getIt` in `HandoverSenderService`; a result clears every pending session                                             | C2, A1                                                     |

Found while auditing, not yet triaged:

- `architecture.md` says that on `handover.step1_complete` and `handover.result` "the records arrive through LWW sync". They arrive only after someone saves the draft on the desktop (A7). Its table also lists `handover.result` as the "full FHIR resource list", which the phone ignores.

---

## A. High

| ID  | Issue                                                                                   | Area             | Severity | Confidence     | Decision |
| --- | --------------------------------------------------------------------------------------- | ---------------- | -------- | -------------- | -------- |
| A1  | A desktop result deletes every queued document on the phone, not only the one sent      | Phone            | High     | Verified       |          |
| A2  | Every reconnect after a phone restart replays all results, and A1 runs again            | Both             | High     | Verified       |          |
| A3  | The desktop sends an earlier handover's draft as the new result and drops the new document | Desktop          | High     | Verified       |          |
| A4  | Phase 2 of a handed-over PDF can read another document's pages                          | Desktop          | High     | Traced         |          |
| A5  | A file over about 12 MB closes the link, and the handover hangs                         | Transfer         | High     | Verified       |          |
| A6  | A failed send leaves the phone's dialog spinning and the desktop waiting forever        | Transfer, phone  | High     | Verified       |          |
| A7  | The phone says "finished" when nothing has reached the wallet                           | Product, both    | High     | Verified       | Needed   |

### A1. A desktop result deletes every queued document on the phone, not only the one sent

- **Where:**
  - `handover_sender_service.dart:188-197` (`handover.result`) and `:213-222` (`handover.step1_complete`) add `SessionCleared` for every session that is `pending` and has files.
  - `SessionCleared` deletes the session's files from disk (`processing_repository_impl.dart:310-316`, through `session_handler.dart:234`).
  - The result names its session, but the phone never uses that id here.
- **What happens:**
  1. The phone has no AI model. The user scans three documents, which wait as `pending`.
  2. From the load-model page they tap "Process on desktop", which sends one of them (B7).
  3. The desktop's result arrives. All three sessions and their scans are deleted, including the two never sent.

  The document that was sent is often not among them: the dialog already cancelled its processing, so it is `patientExtracted` or `cancelled`, not `pending`. It is cleared only if the user taps Continue or Go to records.
- **Fix:** keep the source session id with the handover (the dialog already has `sourceSessionId`), clear only that session, and only once the result arrives. Ignore results for sessions this phone didn't start.

### A2. Every reconnect after a phone restart replays all results, and A1 runs again

- **Where:**
  - On the desktop, `_pendingResults` (`handover_service.dart:250-254,304-307`) is never pruned, and `resendPendingResults` (`:365-371`) sends all of it on every phone connection (`main_desktop.dart:42-45`).
  - On the phone, `_processedResultIds` (`handover_sender_service.dart:28,181-182`) lives only in memory. `_handleResult` and `_handleStep1Complete` clear, notify and sync before checking that the session is one of `_activeSessions`.
  - The dashboard creates the sender service at start-up on the phone (`dashboard_page.dart:79-80`), so it listens from the first frame.
- **What happens:** the user hands over a document on Monday. The desktop keeps running. On Tuesday the phone app is restarted (an update, iOS ending it in the background) and reconnects:
  1. The desktop resends Monday's result.
  2. The phone shows "Desktop finished processing" again and deletes every queued document (A1).

  This repeats on each restart, once per result the desktop has produced since it started. The throwaway test reproduced it: one replayed result cleared both queued sessions and raised one notification.
- **Fix:** on the phone, act only on results for sessions it started, and persist the handled ids if a result can arrive after a restart. On the desktop, drop a result once the phone acknowledges it (`handover.result_ack`, step 3) and keep results across a restart, or let them go.

### A3. The desktop sends an earlier handover's draft as the new result and drops the new document

- **Where:**
  - `handover_service.dart:175-178` and `:219-221` pick `firstWhereOrNull((s) => s.origin == ProcessingOrigin.handover)`, not the session this handover's `DocumentImported` created.
  - The listener is subscribed straight after `DocumentImported` is added (`:161-175`), so it sees the `loading` state before the new session exists.
  - Per-handover state is shared by the whole service: `_processingBlocSub`, `_step1Notified` and `_hasPhase1Data` (`:134,138,174,208-209`).
  - Pinned by the skipped test "a draft left over from an earlier handover is not sent as this result" (`handover_service_test.dart:523-559`).
- **What happens:** a handover draft is waiting for review on the desktop; drafts are stored, so this survives a restart. The phone hands over the next document:
  1. On the first state change, the old draft is found and `_sendResults` sends its resources under the new session id. The new handover is marked complete and its listener cancelled.
  2. The phone announces "finished" and clears its queue (A1).
  3. On the desktop, the new document never goes on. Without phase-1 data it stays `pending`. With phase-1 data it stays `patientExtracted`, because phase 2 is started only by the listener that was cancelled.

  A second handover arriving while the first is processing replaces the first's listener. The first then never reports a result, and the two can exchange progress, because both look for "the first handover session".
- **Fix:** have `DocumentImported` carry an id the handover chooses (or report the session it created), follow only that session, and keep a map of per-handover state.

### A4. Phase 2 of a handed-over PDF can read another document's pages

- **Where:**
  - With phase-1 data, `handover_service.dart:188-197` adds `SessionActivated`, then `ProcessRemainingResources` 300 ms later.
  - `onSessionActivated` (`session_handler.dart:258-290`) first awaits `prepareAllImages`. For a PDF that rasterises every page at 200 dpi (`ocr_processing_service.dart:41-67`), which takes seconds. Only then does it store the session's pages.
  - `onProcessRemainingResources` (`processing_handler.dart:391-392`) uses `state.sessionImagePaths[id] ?? state.allImagePathsForOCR`, the pages of whichever session was activated last.
  - Neither handler sets a `transformer:`, so they run concurrently.
- **What happens:** on the phone, the patient step finishes on a PDF, then the user taps "Continue processing on Desktop".
  - If the desktop has opened another document since it started, phase 2 extracts that document's medications and results and stages them under this patient.
  - Otherwise the list is empty and the draft has no phase-2 records.

  The review on the desktop is the only safeguard. Images (camera pages) are prepared at once, so they are not affected.
- **Fix:** start phase 2 when the session's own pages are ready (from `SessionActivated`, or by waiting for `sessionImagePaths[id]`), and never fall back to another session's pages.

### A5. A file over about 12 MB closes the link, and the handover hangs

- **Where:**
  - Each file is read whole and sent as one base64 `handover.file` message (`handover_sender_service.dart:114-123`).
  - Session frames are capped at 16 MiB (`link_protocol.dart:462`), and base64 adds a third, so the limit is about 12 MB per file.
  - The sender doesn't check the size. The receiver closes the channel on a larger frame (`tcp_service.dart:332,505`).
- **What happens:** a scanned multi-page PDF imported from Files is 15 MB. The link drops in the middle of the handover, and the phone's dialog stays at "Sending" (A6). The phone reconnects, LWW sync resumes, and the user tries again with the same result. The whole file also sits on the phone's UI isolate four or five times over (bytes, base64, JSON, UTF-8, ciphertext). _Device_ for how large typical imports are.
- **Fix:** send files in indexed chunks, as `sync.file_chunk` already does (256 KiB), and assemble them on the desktop by index.

### A6. A failed send leaves the phone's dialog spinning and the desktop waiting forever

- **Where:**
  - `sendHandover` catches nothing. `File.length` throws for a missing file before the offer (pinned as expected in `handover_sender_service_test.dart:122-128`), and every `sendData` throws `LinkNotConnectedException` once the link is down.
  - `_startSending` awaits it without a `catch` (`handover_send_dialog.dart:128-135`). The error is unhandled, the session stays `sending`, and the dialog shows a progress bar and Cancel.
  - Cancel tells the desktop nothing; there is no cancel message.
  - The desktop has no timeout. An offer whose files never all arrive stays `receiving` in `HandoverBloc` forever: a spinner card on the Handover tab, which never goes away (B9).
- **What happens:** the user starts handing over ten pages and switches apps. iOS suspends the app and the link drops. Back in the app, the dialog is still "Sending". The user cancels and tries again, which works. The desktop keeps a "Receiving files 4/10" card until it restarts, and the files it did receive stay in `imports/`.
- **Fix:** catch failures in `sendHandover` and end the session in `error` with a reason. Send `handover.cancel` from Cancel. Expire an incomplete transfer on the desktop after a timeout, and delete its files.

### A7. The phone says "finished" when nothing has reached the wallet

- **Where:**
  - On the desktop, a handover with phase-1 data stops at `draft` (`handover_service.dart:261-270`); one without stops after the patient step (`:238-259`). Nothing saves a handover draft by itself.
  - The phone ignores the resources in `handover.result`. It shows "Handed over to Desktop" as soon as the files are sent (`handover_send_dialog.dart:148-150,197-209`) and "Desktop finished processing" on any result (`dashboard_page.dart:79-83`). It offers "Go to records" and triggers a sync that has nothing to fetch (`handover_sender_service.dart:199-201`).
  - The desktop announces a finished handover as "Handover patient matched" (`dashboard_page.dart:60-72`), even when it is a full draft.
- **What happens:** the user hands over a lab report and taps "Go to records". There is nothing new. The records appear only once someone opens the Handover tab on the desktop, reviews the draft and saves it. If nobody does, they never appear. Without phase-1 data, "finished" arrives when only the patient has been read.
- **Decision:** see [Decision needed](#proposed-order). Either way, the phone's wording should match what has happened.

## B. Medium and low

| ID  | Issue                                                                                     | Area           | Severity | Confidence     | Decision |
| --- | ----------------------------------------------------------------------------------------- | -------------- | -------- | -------------- | -------- |
| B1  | A busy desktop strands a handover that has phase-1 data                                   | Desktop        | Medium   | Traced         |          |
| B2  | Pages can be reordered, duplicated or overwritten on the desktop                          | Desktop        | Medium   | Verified       |          |
| B3  | An accept that arrives during the offer's send is lost, and the handover times out         | Phone          | Medium   | Traced, device |          |
| B4  | Any processing failure on the desktop fails the handover, and a failed one can still "complete" | Desktop   | Medium   | Verified       |          |
| B5  | Once the dialog closes, the phone never hears of a failure, and Continue already deleted the scan | Phone     | Medium   | Verified       |          |
| B6  | Every received file stays twice on the desktop, and neither copy is ever deleted          | Desktop        | Medium   | Verified       |          |
| B7  | The load-model page hands over a different document, without reconnecting or phase-1 data | Phone          | Medium   | Verified       |          |
| B8  | A result ready while the phone is away is marked failed on the desktop, and lost on restart | Desktop       | Low      | Verified       |          |
| B9  | The desktop's Handover tab and stuck transfer cards never clear                           | Desktop UI     | Low      | Verified       |          |

- **B1.** With phase-1 data, the handover session is `patientExtracted`. If any other session is processing on the desktop, `SessionActivated` returns early (`session_handler.dart:298-301`) and `ProcessRemainingResources` returns without a word (`processing_handler.dart:380-383`). `startNextPendingSession` picks only `pending` sessions, and `phase2Triggered` is already set, so nothing resumes it. The phone waits forever, and the desktop user has to find the session and continue it by hand. Without phase-1 data the session is `pending` and is picked up later.
- **B2.** Three skipped `BUG:` tests in `handover_service_test.dart:238-302` pin this:
  - `file_index` is ignored. A duplicated message counts as a page, so processing starts with one page twice and another missing.
  - Pages are appended when their write finishes, so a large page 1 lands after a small page 2.
  - The stored name `<base>_<ms><ext>` collides when two pages share a name within a millisecond, so one overwrites the other.

  `_autoReorderByPageNumber` fixes the order only for documents that print "page x of y".
- **B3.** `_acceptSub` is attached only after `sendData('handover.offer')` returns (`handover_sender_service.dart:71-85`). An accept that arrives while the send is still in progress is dropped. That can happen over MPC, where the platform call returns late, or behind a slow flush. The phone then fails after 30 s with "The desktop did not accept the documents" while the desktop waits for files. Pinned by a skipped test (`handover_sender_service_test.dart:205-229`). The listener is also a single field, so a second offer replaces the first's.
- **B4.** `processingState.status is Failure` from any session fails the handover and sends an error to the phone (`handover_service.dart:272-281`). One example is the desktop user's own import failing while a handover is processing. `_updateSessionError` doesn't cancel the listener, so when the real session later reaches `draft`, the result is sent anyway. The phone then goes from "failed" to "finished" and runs A1.
- **B5.** `waitingForResults` counts as sent (`handover_send_dialog.dart:143-150`). The dialog shows a check and lets the user leave, and Continue or Go to records deletes the source session and its files (`:115-126,246-269`). The desktop checks for a model only after every file has arrived. A later `model_not_found` or other error reaches `sessionUpdates`, but the dialog is gone and nothing else listens; notifications are raised only for results. The phone's copy is deleted, and the user is never told. The desktop still holds the document in its queue.
- **B6.** The desktop writes each file to `Documents/imports/<name>_<ms>` (`handover_service.dart:95-102`). `DocumentImported` then copies it again to `imports/<name>_<ms>_<ms>` (`session_handler.dart:547-561`), and the session uses the copy. The first copy is never deleted. Clearing the session or deleting the record removes only the second copy, so every document a phone ever handed over stays on the desktop's disk.
- **B7.** `LoadModelPage._sendToDesktop` (`load_model_page.dart:378-406`) differs from `HandoverUtils.initiateHandover`:
  - It sends `pending.first`, not the document the user was looking at.
  - It sends no phase-1 data.
  - It shows the pairing dialog (`DeviceSyncDialog`) instead of reconnecting the paired desktop.
  - It pops the page (`maybePop`, not awaited) before showing the send dialog with the same context. _Device_ for whether that pops the dialog instead.
- **B8.** If the phone is gone when the desktop finishes, `_sendResults` catches `LinkNotConnectedException`. The desktop marks the handover failed although its draft is ready (`handover_service.dart:325-327`). The result is resent on reconnect (A2), but `_pendingResults` lives in memory, so a desktop restart loses it.
- **B9.** `HandoverBloc.activeSessions` is never pruned. Once any handover has happened, the desktop's Handover tab stays until restart (`dashboard_page.dart:137-150`), and a transfer stuck in `receiving` (A6) shows a spinner there for good. The tab lists only `receiving` transfers (`handover_page.dart:32-34`), so a failed transfer isn't shown there at all.

## C. Low: conventions and leftovers

| ID  | Issue                                                                                                                                                                                                                                                                                                         | Where                                    |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| C1  | Empty `catch (_) {}` blocks, against AGENTS.md                                                                                                                                                                                                                                                                | `handover_sender_service.dart:197,201,222,226`, `handover_send_dialog.dart:125`, `handover_service.dart:369` |
| C2  | Layering: `HandoverService` (data) depends on `ProcessingBloc` and drives it with events; `HandoverSenderService` (data) reaches `ProcessingBloc` and `LwwSyncBloc` through `getIt`; the send dialog cancels generation and disposes the model through the repository; `HandoverUtils` builds the phase-1 payload | handover services, dialog, utils         |
| C3  | No `transformer:` on `HandoverBloc`; `HandoverFileReceived` and `HandoverSessionUpdated` both set `receivedCount`                                                                                                                                                                                              | `handover_bloc.dart:19-25,63-78`         |
| C4  | UI kit: `Colors.transparent`, `BorderRadius.circular(12)`, `fontSize: 11`, a bare `GestureDetector` close icon without semantics, `Theme.of` in the resources section, `debugPrint` of session ids and statuses in the dialog                                                                                   | dialog, `handover_page.dart`, `processing_resources_section.dart:296` |
| C5  | Dead or unread: `lastResult` (tests only), `total_bytes` and `file_index` (sent, never read), the result's `resources`, `patient` and `encounter` (A7); a `handover.progress` frame for every processing state change                                                                                        | sender, `handover_service.dart:224-236`  |
| C6  | Dashboard subscriptions to `HandoverBloc` and `ProcessingBloc` are never stored or cancelled                                                                                                                                                                                                                   | `dashboard_page.dart:65,126`             |
| C7  | `_activeSessions` and `_cancelled` on the phone are never pruned                                                                                                                                                                                                                                              | `handover_sender_service.dart:24-25`     |
| C8  | `_cancelMobileProcessing` calls `cancelGeneration()` and `disposeModel()` without awaiting them, then `MappingCancelled`; the model is disposed under any other session the phone is working on                                                                                                                  | `handover_send_dialog.dart:89-113`       |

## Test gaps

| ID  | Gap                                                                                                                                                                                                       |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| T1  | `handover_sender_service_test.dart:362-382` asserts A1 as intended: a result must clear `pending-with-files`, a session unrelated to the handover. Rewrite it to expect only the source session cleared |
| T2  | Nothing covers a result for a session the phone didn't start, or a desktop's resend after a phone restart (A2)                                                                                           |
| T3  | No test of a phase-1 handover whose pages take longer than 300 ms to prepare, or that arrives while the desktop is busy (A4, B1)                                                                           |
| T4  | No test of the dialog when sending throws, of a file over the frame cap, or of a cancel reaching the desktop (A5, A6)                                                                                     |
| T5  | Each side is tested against its own fake; nothing runs the phone's sender against the desktop's receiver over one fake link, as the LWW tests do for sync                                                |
