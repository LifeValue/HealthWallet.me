# Proximity sharing audit

Audit of phone-to-phone proximity sharing, for triage. Written 2026-10-28 against `feature/proximity-share-encryption` (app) and `airdrop` `main` at `86d040d`.

**Scope.** App: `lib/features/share_records/`, receive mode (`ReceiveModeManager`, the settings toggle, `lib/app/view/app.dart`), the record views used for received records. Plugin (`airdrop`): Android and iOS native code, the Dart bridge. macOS plugin code (desktop sync only) and the deliberate behaviours below were left out.

**Method.** Four independent code reviews (app flow and state machine; receiver data lifecycle, privacy and crypto; Android native; iOS native and Dart bridge), merged and de-duplicated. The findings marked _Verified_ were re-read in the code while compiling this document; _Traced_ means a reviewer followed the code path; _Device_ means it also needs checking on a phone. Nothing was changed in the code.

**Accepted, not issues.** Sharing adds related records (including the Patient) to the selection. Desktop has no sharing; its UI is hidden.

## Summary

| Severity | Count |
| -------- | ----- |
| Critical | 1     |
| High     | 13    |
| Medium   | 19    |
| Low      | 4     |
| Test gap | 3     |

**What holds up.** The new end-to-end encryption is sound: the sender commits to its key before seeing the receiver's, keys are validated on the curve, the derived key is bound to both public keys, nonces are fresh, the envelope header is authenticated, unencrypted shares are rejected, and the payload key is released only after "Codes match". MultipeerConnectivity sessions use `encryptionPreference: .required`. The new iOS signal buffering handles split and merged reads.

**Where it breaks.**

1. **The plugin trusts the network before the app's encryption can help.** File names and sizes from the peer are used as given: a peer can write files outside the receive folder or crash the app (A1, A2).
2. **Nobody checks who the peer is.** BLE writes, TCP connections and MPC invitations are accepted from any nearby device, and on iOS 16+ every iPhone is called "iPhone" (A10–A14).
3. **"Deleted when you exit" doesn't hold.** Shared notes go into the synced notes table, nothing is cleaned up after a kill or crash, open records outlive the session, and one cleanup path deletes the working directory (A3, A4, A8, A9).
4. **The sender can't reliably revoke a share.** Several paths end the sender's view of the session without telling the receiver (A5, A6, A7).

## Proposed order

| Step | Issues                     | Why                                                                                                                                                  |
| ---- | -------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | A1, A2, A3, A4, A5, A6, B8 | Remote file writes and crashes, records leaking or left behind, two regressions on this branch, and a one-line fix that can break iOS→Android shares |
| 2    | A7, A8, A9, B1             | Revocation and cleanup, so "view-only, deleted when you exit" is true                                                                                |
| 3    | A10–A14                    | Bind every channel (BLE, TCP, MPC) to the chosen peer                                                                                                |
| 4    | B2–B19, then C             | Robustness, UX and leftovers                                                                                                                         |
| 5    | T1–T3, alongside each step | Tests for what each step fixes; on-device runs of all three phone pairs                                                                              |

Issues marked **This branch** come from the encryption work on `feature/proximity-share-encryption` and are worth fixing before it merges.

## Status

Steps 1–3 are implemented (app on `feature/proximity-share-encryption`, plugin on `airdrop` `dev/transfer-hardening`), not yet run on devices. B6 was fixed with them, because B1's cancel-on-background depends on it.

Merging `develop` (mobile stabilization) into the branch also fixed C1 (share texts are localized; `SessionEndedView` reads a typed end reason) and the sender's payload in C3 (deleted after the transfer; `TempFileSweeper` deletes share payloads and sessions at startup, which replaced this branch's own sweep).

| Issue      | Status                                                                                                                                                                                                                   |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| A1–A9      | Fixed                                                                                                                                                                                                                    |
| A10, A12   | Fixed                                                                                                                                                                                                                    |
| A11        | Fixed for MPC ids; selecting a BLE entry when several iPhones share a name now fails instead of inviting a random phone. A readable name per phone needs the user-assigned-device-name entitlement.                      |
| A13        | Fixed for sessions this phone receives. While this phone is the one selecting, its own GATT server still serves credentials to any central, because the chosen iPhone may read them from an address Android can't match. |
| A14        | Fixed except the per-session nonce, which needs a protocol change. Wi-Fi Direct still joins the first peer when the select carries no expected name.                                                                     |
| B1, B6, B8 | Fixed                                                                                                                                                                                                                    |

New tests: share BLoC (T1: session end, expiry, backgrounding, cancel during verification and during decryption, cleanup on close, for both receiver and sender; peer list), service cleanup and sweep, receive-mode pause, shared notes, and Android `ReceivedFileGuard` (JVM). Writing T1 found that ending a session could add an event to a closed bloc if the screen closed within the kill's 500 ms grace period; fixed.

Found while fixing, not yet triaged:

- Android receiving from an iPhone: accepting can raise a second invitation, and accepting that one may not start the TCP server (pre-existing).
- Android: a re-select during the 5 s rejection delay lets the old invitation reset the new session (pre-existing).
- Android: a large in-memory payload is copied again on the main thread when handed to Flutter; near the 256 MiB limit that can run out of memory. A lower in-memory limit (32–64 MiB) would close it.
- iOS: a sender whose invitation is declined, including because the receiver accepted another phone, gets no feedback (pre-existing).

---

## A. Critical and high

| ID  | Issue                                                                 | Area            | Severity | Confidence      | Origin      | Decision |
| --- | --------------------------------------------------------------------- | --------------- | -------- | --------------- | ----------- | -------- |
| A1  | Received file names can write outside the receive folder              | Plugin, both    | Critical | Verified        | Existing    |          |
| A2  | Peer-chosen sizes crash the app or fill the disk                      | Plugin, both    | High     | Verified        | Existing    |          |
| A3  | Shared notes are written to the receiver's synced notes table         | App             | High     | Verified        | Existing    |          |
| A4  | Cleanup deletes the working directory when a share has no attachments | App             | High     | Verified        | Existing    |          |
| A5  | Cancel or Back after "Codes match" leaves the receiver viewing        | App             | High     | Verified        | This branch |          |
| A6  | Locking the sender's phone with receive mode on drops a live share    | App             | High     | Verified        | Existing    |          |
| A7  | Ending a session is best-effort but reported as done                  | App             | High     | Traced          | Existing    |          |
| A8  | Open records and documents stay visible after the session ends        | App             | High     | Traced          | Existing    |          |
| A9  | Nothing is cleaned up after a kill, crash, reboot or screen close     | App             | High     | Traced          | Existing    |          |
| A10 | A third iPhone can join an MPC session and take it over               | Plugin, iOS     | High     | Verified (part) | Existing    |          |
| A11 | iPhones identify each other as "iPhone" on iOS 16+                    | Plugin, iOS     | High     | Verified        | Existing    |          |
| A12 | Accepting one invitation accepts whoever invited last                 | Plugin, iOS     | High     | Traced          | Existing    |          |
| A13 | Any nearby phone can rewrite the BLE handshake values                 | Plugin, both    | High     | Traced          | Existing    |          |
| A14 | TCP and Wi-Fi Direct connections aren't bound to the expected peer    | Plugin, Android | High     | Traced          | Existing    |          |

### A1. Received file names can write outside the receive folder

- **Where:** `airdrop: android/.../common/DocumentFileHelper.kt:82,85,141` (`File(dir, fileName)` with the name from the network); `airdrop: ios/Classes/ios_ios/MultipeerConnectivityManager.swift:699-710` (`appendingPathComponent(resourceName)`, deletes any existing file at that path, then moves the received file there). The iOS TCP disk path has the same pattern in `FileSystemHelper.swift:12,19`.
- **What happens:** a peer sends a file named `../../…/shared_prefs/x.xml` (Android) or an MPC resource named `../Library/Application Support/…` (iOS). The file is written over the app's database, preferences or Flutter files. This runs before the app decrypts anything, so the encryption doesn't help. With A10/A14 any nearby device can reach it.
- **Fix:** keep only the last path component; reject `..`, `/`, `\`, NUL and empty names; check that the canonical path stays inside the receive folder; never delete an existing file.

### A2. Peer-chosen sizes crash the app or fill the disk

- **Where:** Android `transfer/ReceiveManager.kt:303-311`, `cross_platform/HotspotTransferManager.kt:331-339` (`ByteArrayOutputStream(fileSize.toInt())`), `common/FileTransferUtils.kt:31,121-138`; iOS `transfer/ReceiveManager.swift:374,383,540-546` (`Int64(fileSize)` traps above `Int64.max`, `reserveCapacity(Int(fileSize))`, name length never checked against the 10 000 limit).
- **What happens:** a header with a huge size makes Android allocate gigabytes at once; the resulting `OutOfMemoryError` isn't an `Exception`, so nothing catches it and the app dies. iOS crashes on the conversion or the reservation, or waits for a 4 GB "name". On disk, a huge size streams until storage is full.
- **Fix:** reject names over 10 000 bytes and sizes that are negative or above an app-set limit (and a per-session total) before allocating; close the connection and report `failed`.

### A3. Shared notes are written to the receiver's synced notes table

- **Where:** `share_records_transfer_handler.dart` `_insertEphemeralNotes`; `lib/features/desktop/lww_sync/data/services/change_watcher_service.dart:46-48` (watches `record_notes`); `records_repository_impl.dart` `deleteRecordNote` (hard delete).
- **What happens:** opening a share that has notes inserts the sender's notes as real rows. On a phone paired with a desktop, sync sends them to the desktop within about half a second, or queues them in `lww_offline_queue` (SharedPreferences, included in device backups). At session end they are hard-deleted with no tombstone, so the desktop copy stays forever. After a crash the phone copy stays too.
- **Fix:** keep received notes in memory in the session container and have the notes widget read them from there, never from the database.

### A4. Cleanup deletes the working directory when a share has no attachments

- **Where:** `share_records_session_handler.dart:98-107`.
- **What happens:** with no attachments the code builds `File('').parent`, which is `.`, and calls `delete(recursive: true)` on it, swallowing errors. On a phone the working directory is `/` and the sandbox most likely stops it; in `flutter test` it is the project root; on desktop it would be `/`. The real session folder is also never deleted in this case.
- **Fix:** delete `tmp/share_session_<sessionId>` by its own path. Fix before adding bloc tests (T1), which would otherwise delete the repo.

### A5. Cancel or Back after "Codes match" leaves the receiver viewing

- **Origin:** this branch.
- **Where:** `handleVerificationConfirmed` returns the sender to `SharePhase.connecting`; `share_records_page.dart:205-219` (X sends `sendModeSelected`) and the back handler (`modeCleared`) only disconnect.
- **What happens:** after the payload key has gone out, the sender taps X or Back and believes the share is cancelled. No kill is sent; the receiver decrypts and views for the full duration.
- **Fix:** a separate post-confirm phase (for example `awaitingViewer`) whose exits go through `killSessionRequested`, excluded from auto-retry and "declined" handling (see B2).

### A6. Locking the sender's phone with receive mode on drops a live share

- **Where:** `lib/app/view/app.dart:56-63` (on `paused`, stops receive mode); `receive_mode_manager.dart:88-113` (`stopListening` calls `disconnect()`; `isListening` is still true while the share screen has paused the manager).
- **What happens:** the sender is monitoring a session and the screen locks. The shared transport is torn down, the sender sees the session end, the receiver keeps viewing until its own timer runs out, and the sender can no longer end it. On resume, receive mode re-subscribes alongside the share screen.
- **Fix:** skip receive-mode stop and start while a share screen owns the transport.

### A7. Ending a session is best-effort but reported as done

- **Where:** `share_records_session_handler.dart:159-186` (kill failure swallowed, "Session terminated" shown); `share_records_bloc.dart` `_sessionEndedSub` (acts only when sending); the sender's countdown expiry ends the session locally without a kill.
- **What happens:** with a weak link the sender taps End, the kill fails silently, and the sender is told it worked. The receiver ignores the dropped connection and keeps the records until its own timer runs out.
- **Fix:** the receiver destroys the session when the connection drops; the sender is told when the kill didn't reach the other phone and how long the records stay there; send the kill on countdown expiry.

### A8. Open records and documents stay visible after the session ends

- **Where:** `ephemeral_viewer_view.dart` (turns screen protection off on dispose); `lib/features/records/presentation/pages/record_detail_page.dart:58-66`; nothing listens to `EphemeralSessionManager.sessionStateStream`.
- **What happens:** the receiver opens a record or a PDF and waits for the timer or for the sender to end the session. Only the share page underneath switches to "ended", which also turns screen protection off; the record on top stays visible and can be screenshotted.
- **Fix:** when the session is destroyed, pop back to the share route, and keep screen protection on until then.

### A9. Nothing is cleaned up after a kill, crash, reboot or screen close

- **Where:** `share_records_bloc.dart` `close()` (no `destroySession`, no `_cleanupEphemeralData`); `ShareRecordsEvent.disposed` is never sent; `lib/main.dart` has no startup sweep.
- **What happens:** decrypted attachments in `tmp/share_session_<id>/` and inserted notes (A3) stay after the app is killed, crashes or the phone reboots, and nothing removes them on the next launch.
- **Fix:** on every launch delete `share_session_*` and `share_*.bin` from the temp folder (and any leftover shared notes until A3 is fixed); run the cleanup in `close()`.

### A10. A third iPhone can join an MPC session and take it over

- **Where:** `MultipeerConnectivityManager.swift:894` (invitations auto-accepted once `discoveryOnlyMode` is false), `:760` (sender auto-invites new peers), `:597,607-615` (re-sends files to a newly connected peer), `handlePeerConnected` (overwrites `connectedPeer`), `didReceive` (doesn't check the sender).
- **What happens:** after the first accept, advertising and browsing continue. Another iPhone gets connected, receives the encrypted envelope, becomes the target of the key-exchange messages, can inject `KILL_SESSION`, and its disconnect ends the real session. The code comparison stops it from decrypting, but the share breaks.
- **Fix:** stop advertising and browsing once connected; reject invitations and data from anyone other than the bound peer.

### A11. iPhones identify each other as "iPhone" on iOS 16+

- **Where:** `MultipeerConnectivityManager.swift:63,134` (`MCPeerID(displayName: UIDevice.current.name)`); `PeerDiscoveryCoordinator.swift:228-237` (`inviteFirstAvailablePeer`). Runner has no `user-assigned-device-name` entitlement.
- **What happens:** every iPhone advertises as "iPhone", peers overwrite each other in the discovered map, and selecting a device can invite whichever peer the dictionary returns first. With two iPhones nearby the invitation can go to the wrong person.
- **Fix:** add a random per-session ID (or a token exchanged over BLE) to the display name or `discoveryInfo`, and invite only the peer that matches the selected device.

### A12. Accepting one invitation accepts whoever invited last

- **Where:** `MultipeerConnectivityManager.swift:481-489,887-888`; `InvitationHandler.swift:26`.
- **What happens:** a second invitation overwrites the pending handler, and `acceptInvitation(invitationId)` ignores the ID. Tapping the first sender connects to the second.
- **Fix:** key pending handlers by invitation ID and decline the ones that are replaced or expire.

### A13. Any nearby phone can rewrite the BLE handshake values

- **Where:** Android `handshake/BluetoothPeripheralManager.kt:324-334,418-443,533-550`; iOS `handshake/BluetoothManager.swift:458-557`.
- **What happens:** GATT writes need no pairing and aren't tied to the selected peer. A nearby device can abort or reset shares, start a transfer without an invitation in Ready mode or turn on the hotspot (Android), flip the detected peer OS so the kill goes over the wrong transport, or point the TCP connection at another IP (iOS).
- **Fix:** accept writes only from the peer the session is bound to and only in the expected state; drop the write handlers the flows don't use.

### A14. TCP and Wi-Fi Direct connections aren't bound to the expected peer

- **Where:** `cross_platform/HotspotTransferManager.kt:69-101` (first connection accepted, no handshake), `transfer/SendManager.kt:53-70`, `transfer/ReceiveManager.kt:116-145`; `android_android/WifiDirectConnector.kt:73-77,112` (falls back to the first discovered peer and to `192.168.49.1`).
- **What happens:** anyone on the network who connects first gets the session and locks the real peer out; a receiver can join a stranger's Wi-Fi Direct group. Both feed A1 and A2.
- **Fix:** exchange a per-session nonce over BLE and require it in the TCP handshake on every path; check the remote address; fail instead of falling back.

---

## B. Medium

| ID  | Issue                                                                        | Area            | Confidence          | Origin                            | Decision |
| --- | ---------------------------------------------------------------------------- | --------------- | ------------------- | --------------------------------- | -------- |
| B1  | Cancelling or backgrounding during decryption still opens the records        | App             | Traced              | This branch                       |          |
| B2  | After "Codes match", a dropped link shows "declined" or triggers a retry     | App             | Traced              | This branch                       |          |
| B3  | Two share screens can run at once and both answer the key exchange           | App             | Traced              | Existing                          |          |
| B4  | Receiver Retry waits for invitations nobody listens to                       | App             | Traced              | Existing                          |          |
| B5  | Receiver errors never reach the sender; the sender waits for ever            | App             | Traced              | This branch                       |          |
| B6  | Pulling down Control Center or the notification shade wipes the session      | App             | Device              | Existing                          |          |
| B7  | The share log keeps names and record types on disk and opens in release      | App             | Traced              | Existing                          |          |
| B8  | The key exchange can fail on the Android hotspot receive path (iOS→Android)  | Plugin, Android | Verified, device    | Existing (exposed by this branch) |          |
| B9  | Native logs reach release logs; Android diagnostic dumps grow without limit  | Plugin, both    | Traced              | Existing                          |          |
| B10 | Signals can be mixed into file bytes; a second monitor reads the same socket | Plugin, Android | Traced              | Existing                          |          |
| B11 | An unknown signal or oversized message stalls the iOS receive stream         | Plugin, iOS     | Traced              | Existing                          |          |
| B12 | Sessions and transfers that never end (Android timeouts)                     | Plugin, Android | Traced              | Existing                          |          |
| B13 | iOS hotspot join always reports success; "Don't join" is retried             | Plugin, iOS     | Traced              | Existing                          |          |
| B14 | Android hotspot and server can come back after a cancel                      | Plugin, Android | Traced              | Existing                          |          |
| B15 | iOS failures that never reach Flutter                                        | Plugin, iOS     | Traced              | Existing                          |          |
| B16 | iOS transfer state is shared across queues without synchronisation           | Plugin, iOS     | Traced, part device | Existing                          |          |
| B17 | Android: accepting after the 60 s invitation timeout hangs                   | Plugin, Android | Traced              | Existing                          |          |
| B18 | Declining in the receive-mode dialog silences receive mode                   | App             | Traced              | Existing                          |          |
| B19 | Extension requests have no timeout; a failed send still extends locally      | App             | Traced              | Existing                          |          |

- **B1.** `_receiveSecurePayload` (transfer handler) doesn't check for a cancel after `awaitPayload` or `parsePayload`. If the receiver cancels or leaves the app while the payload is decrypted and attachments are written, the records still open, possibly in the background, after the sender was told the session ended. Fix: after each await, check the session is still current and not cancelled; otherwise delete the session folder and return.
- **B2.** The post-confirm `connecting` phase is shared with pre-transfer connecting. If the link drops before "viewing started", `sessionEnded` with no start time is treated as "declined", or `TransferStatus.failed` triggers an auto-retry and a new discovery; a late "viewing started" sets `_pendingViewingStarted`, which is never reset. Fix: the phase from A5; reset `_pendingViewingStarted` on every attempt.
- **B3.** With receive mode on, accepting an invitation while on the send screen pushes a second share screen. Both blocs handle received data, both send a receiver key, and `readReceivedFile` deletes the file under the other. Fix: ignore received data unless the bloc is receiving in an expecting phase; pause receive mode as soon as a share screen opens.
- **B4.** Receivers arrive through receive mode, so the bloc skips the invitation stream. After an error, Retry restarts receiving but no one handles the next invitation and the receiver waits for ever. Fix: subscribe the bloc to invitations whenever it pauses receive mode.
- **B5.** "Older version" and read failures on the receiver show an error but send nothing; `SecureShareSession.awaitReceiver` has no timeout, so the sender waits indefinitely. If parsing fails after the codes were confirmed, the sender's 60 s fallback shows "Receiver is viewing". Fix: send a kill on every receiver error path; time out `awaitReceiver`.
- **B6.** `EphemeralSessionManager` (`:104-112`) and the bloc destroy the session on `AppLifecycleState.inactive`, which fires for Control Center, the notification shade, call banners and Face ID prompts. Fix: destroy on `paused`, `hidden` and `detached` only; blur on `inactive`.
- **B7.** `ShareLogBuffer` appends to `Documents/share_debug.log` (no rotation, included in backups) with device names, record types and IDs, file paths and timestamps. The log sheet, with a copy button, opens from the terminal icon in `transfer_views.dart:70-78,133-140` in release builds; lines also go to `debugPrint`. Fix: debug builds only, in memory, without names or IDs.
- **B8.** In `HotspotTransferManager.kt` the in-memory receive posts `onDataReceived` (`:357`) inside the receive loop but creates `outputStream` only after the loop (`:372`). If the app sends its receiver key before the batch-complete marker is read, `sendSessionMessage` fails and the share ends with "couldn't set up a secure connection". Fix: create `outputStream` when the connection is accepted (same in `receiveFiles`, `:271`).
- **B9.** The Dart bridge (`airdrop_platform_interface.dart:159-183`) `debugPrint`s every native log line (device names, SSIDs, IPs, file paths) in release. Android `DiagnosticLogger` writes a dump on every failure to `getExternalFilesDir/logs`, never rotates dumps, includes SSID and IPs, and `exportLogs` exposes the folder. No passwords or contents are logged. Fix: no forwarding in release; redact; rotate.
- **B10.** `SendManager.kt:151-179` and `HotspotTransferManager.kt:139-169` write file data outside the stream lock that signals use; `sendAdditionalFiles` starts a second monitor on the same socket. A signal sent during a send corrupts the stream; two readers split a session message. Fix: one write lock per batch; one monitor per connection.
- **B11.** `TransferSignalHandler.swift:107-119` returns "not a signal" for an unknown negative marker or a message over 64 KiB, and `ReceiveManager` then reads it as a 4 GB file name and stalls, missing later kills. Senders don't enforce 64 KiB. Fix: treat any negative marker as a signal and fail fast on bad input; enforce the limit when sending.
- **B12.** Connection monitors `continue` on read timeouts, accepted sockets have no read timeout, the session timeout is 30 minutes, and loss of the P2P group is ignored. A peer that walks away or stalls mid-file leaves the session or transfer open. Fix: socket timeouts, a heartbeat, report P2P disconnects.
- **B13.** `HotspotManager.swift:87-107,151-198`: every path reports success, "Don't join" (error 7) is retried three times, and any IPv4 address (home Wi-Fi) counts as connected; the app then spends minutes connecting to the wrong network. Fix: pass the real result through, stop on user denial, check the current network is the hotspot.
- **B14.** `HotspotManager.kt:80-84,288-305`: retry runnables aren't removed and `stopHotspot` doesn't cancel a start in progress, so a cancelled share can bring the hotspot and a TCP server back seconds later. Fix: a session generation checked in callbacks; remove callbacks on stop.
- **B15.** iOS: `.waiting` after the last retry has no failure path, MPC invites use a 7200 s timeout and report success before the peer answers, and plugin calls never complete `result` when the view model is nil. Fix: report `failed`, a ~30 s invite timeout, always complete `result`.
- **B16.** iOS `ReceiveManager`/`SendManager` state is changed from several queues; the path monitor and the 20 s timer can both create a connection; `cancel()` sends `onFilesReceived` with a list it clears straight after. Fix: one serial queue per manager; copy values before dispatching.
- **B17.** `BluetoothPeripheralManager.kt:474-497`: after the internal 60 s invitation timeout the invitation and its waiter are kept and Flutter isn't told; a later Accept reports success and nothing connects. Fix: clear both and notify Flutter on timeout.
- **B18.** `receive_mode_manager.dart`: Decline clears the invitation but not a payload that already arrived, so the next invitation skips its dialog and the next payload doesn't navigate. Fix: `clearPendingPayload()` on Decline.
- **B19.** `share_records_session_handler.dart:216-263`: an unanswered extension request stays pending for ever; a failed "accepted" send still extends the local timer, so the two phones disagree; the auto-reject isn't awaited. Fix: a timeout; extend only after a successful send; await the auto-reject.

---

## C. Low

| ID  | Issue                                                                                                                                                                                                                                                                                    | Area         | Decision |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | -------- |
| C1  | English strings hard-coded in the bloc, the receive-mode dialog and the permissions helper; `SessionEndedView` detects "declined" by searching the English status text                                                                                                                   | App          |          |
| C2  | Per-attempt state (`wifiToggleNeeded`, retry count, start time, extension fields) isn't reset between attempts                                                                                                                                                                           | App          |          |
| C3  | Leftover files: the sender's `share_<id>.bin` after normal sessions; untracked temp PDFs for shared Media records; a static PDF page cache; same-title attachments overwrite each other; iOS↔iOS envelopes saved to Documents (backed up); Android partial files after a failed transfer | App, plugin  |          |
| C4  | Threading details: iOS `FlutterResult` called off the main thread, a keep-alive timer that can leak, Android GATT callbacks mutating a `HashMap` on Binder threads, `reuseAddress` set after bind                                                                                        | Plugin, both |          |

## T. Test gaps

| ID  | Gap                                                                                                                                                | Decision |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| T1  | No tests for the share bloc and handlers (about 1 200 lines): session end, expiry, backgrounding, cancel during decryption, cleanup. Fix A4 first. | Done     |
| T2  | No native tests in the plugin: framing, `TransferSignalHandler` on both platforms, file-name cleaning, size limits.                                |          |
| T3  | The encrypted flow hasn't been run on devices yet: iPhone↔Android in both directions, Android↔Android, iPhone↔iPhone, and cancel on each side.     |          |
