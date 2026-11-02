# Mobile ↔ desktop sync audit

Audit of the sync between the phone and the desktop app, for triage. Written 2026-10-30 against `feature/records-stabilization` at `0009f709` (app) and `airdrop` `main` at `adba3ff`.

**Scope.** The LWW sync (`lib/features/desktop/lww_sync/`), the link it runs on (`lib/features/desktop/communication/`: pairing, discovery, TCP, the MPC transport), the `updated_at` triggers and the three synced tables, the sync UI on both ends (the mobile sync section and dialogs, the desktop connection dialog, home card and tray status), and `airdrop`'s `DesktopSyncManager` (iOS, macOS) with its Dart bridge. The Fasten sync was left out because it is being phased out. Backup and handover were read only where they start or depend on a sync. The problems already tracked in `mobile-stabilization.md` and `records-audit.md` are listed under [Known issues](#known-issues).

**Method.** Four independent code reviews: the LWW engine and its data; the sync BLoC, what triggers a sync, lifecycle and UI; the Dart transport, pairing and link security; the native MPC code in `airdrop`. They were merged and de-duplicated. _Verified_ means the reviewer re-read the exact code and the outcome follows from it directly. The most serious findings (A1, A2, A4, A8–A12, A14, B1, B2, B6) were re-read again while compiling this document. _Traced_ means a reviewer followed the code path but the outcome depends on timing, data or the network. _Device_ means it needs a phone and a desktop to confirm. Two things were checked outside the repo:

- A throwaway SQLite script, using the exact trigger and upsert SQL, confirmed the whole-second timestamps (A1), the column-name injection (B1) and the tie re-stamp (B2).
- A benchmark measured frame reassembly (A7) and the copy across the isolate boundary (C10).

Nothing was changed in the code.

## Summary

| Severity | Count |
| -------- | ----- |
| Critical | 0     |
| High     | 16    |
| Medium   | 22    |
| Low      | 12    |
| Test gap | 6     |

**What holds up.**

- **Encryption.** Frames are AES-256-GCM with a fresh random nonce each. The pairing key is 32 bytes from `Random.secure()`. TCP never runs without a key. A frame that fails its tag is dropped, so a stranger on the network or an MPC peer without the key can't read or forge anything; a rogue host only ever receives ciphertext.
- **Before the hello**, the desktop server reads nothing else, caps frames at 64 KiB and drops the client after 15 s. It holds at most one pending socket.
- **The engine doesn't trust table names or file paths from the peer.** Only the three synced tables are accepted; `processing_sessions` is never synced. Values are bound as parameters, and drift refuses a second statement. Received file names are reduced to a safe base name and never overwrite a file; served files must be regular files inside Documents, symlinks resolved, and never `db.sqlite`.
- **Sync writes don't echo:** they go through `customStatement`, which the change watcher doesn't see.
- **The notes `uuid` fix (records audit A13) holds,** and the offline queue keeps no file bytes.
- **The desktop LWW only starts after a valid hello.** `debugPrint` is silent in release, and no payload or key is logged.

**Where it breaks.**

1. **Edits silently never reach the other device.** The "last sync time" every delta is computed from moves forward when bytes are written, when a delta is received, and to a millisecond value the triggers can't match. A send to a dead link succeeds without error. Equal row counts then hide the gap for good (A1–A5).
2. **The phone believes it is connected before the desktop has said anything.** A bare TCP handshake counts as connected, a reconnecting phone gets parked on the desktop, and the reconnect counter resets on every attempt. So the phone loops, or gives up after one retry, and mDNS never finds anything (A8–A11, A14).
3. **A real record library is too big for one message.** Reconciliation resends whole tables with every attachment inline, from both sides, twice. Frames that size trip the 5 s pong timeout and are reassembled in quadratic time, so the first sync of a large library may never finish (A6, A7, B9).
4. **The link isn't bound to the paired device.** Any nearby Apple device running the app can take over the Mac's outgoing traffic over MPC. Captured frames replay, and anyone who sees the desktop's QR receives every paired phone's records (A12, A13, A15, A16).

## Proposed order

| Step | Issues                                     | Why                                                                                                                                                                                                                                                                          |
| ---- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | A1–A5, B5, B15                             | Edits lost in normal use. One design: a cursor per table, moved only on the peer's `sync.ack` to the highest `updated_at` sent; millisecond triggers; deltas applied in one transaction and acknowledged after; `sequential()` handlers. `sync.ack` already carries the table and timestamp |
| 2    | A8–A11, A14, B12, B14, C1, C2, part of A16 | Connections that recover by themselves: connected only after the desktop answers, newest verified client wins, a server idle timeout, a reconnect count that counts failures, mDNS `resolve`. Hide the QR once a phone is paired (the quick part of A16)                   |
| 3    | A6, A7, B6, B8, B9                         | Large libraries: reconcile by id and `updated_at` instead of resending tables, never embed files in reconciliation, chunk frames, reset the pong deadline on any received bytes, move database and crypto work off the UI isolate                                          |
| 4    | A12, A13, A15, A16, B1, B10, B21           | Bind the link to the paired peer: a challenge–response hello with per-session keys and counters, a pairing token in MPC `discoveryInfo` and invitations, a key per phone, a column allowlist. A protocol change: phone and desktop ship it together, and `airdrop` releases with it |
| 5    | B2–B4, B7, B11, B13, B16–B20, B22, then C   | Conflict rules, sync state across re-pairing, what the UI reports, Windows, leftovers                                                                                                                                                                                        |
| 6    | T1–T6, alongside each step                 | A failing test first for each fix (backlog rule 1), with a fake transport that drops silently like the real one; then runs on device pairs                                                                                                                                   |

Steps 1, 3 and 4 change what goes over the wire, so each needs the desktop to ship the same change (backlog rule 4). Security (step 4) comes after steps 1–3 here, unlike the share audit. Every attack in it needs someone on the same network or near the Mac, and none of them can read records without the pairing key. Steps 1–3 lose or block data for every paired user today.

## Status

A and B are implemented on `feature/records-stabilization` (app) and `airdrop` `dev/desktop-sync-binding` (plugin, used through a local `pubspec_overrides.yaml` until it is pushed and the `airdrop` ref bumped). Nothing has run on devices yet. The protocol is version 2: the phone and the desktop must both be updated. Existing pairings keep working: the first phone to connect becomes the paired one and gets a new key. A QR code shown by an older desktop app is refused with "update the app on the desktop". `scripts/check.sh` passes except the two SSDP tests, which fail on any machine where another app holds UDP port 1900. The macOS and iOS (simulator) apps and the Android debug APK build.

How it works now is in `architecture.md`, "Mobile ↔ desktop communication". In short:

- **Outbox.** Triggers log every local write in `sync_outbox` (schema v13); a batch is sent, applied in one transaction and acknowledged, and only then the position moves.
- **Reconciliation.** Each connection compares digests and exchanges key/`updated_at` manifests. Files travel on request, in chunks.
- **Link.** A version-2 handshake with per-session keys and counted frames. Connected means verified; the newest verified session wins; one phone per desktop, a new phone waits for the desktop user, and the key changes once a phone pairs. MPC uses the same handshake, bound by a token derived from the key.

| Issue    | Status                                                                                                                                                                                                         |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1–A5    | Fixed. The offline queue is gone (the outbox replaces it), so "the queue is cleared on every mobile start" no longer applies                                                                                   |
| A6, A7   | Fixed. Also: the link's AES-GCM moved from pointycastle (about 1.5 MB/s) to `cryptography` (about ten times faster), and the database runs on a background isolate (B8)                                        |
| A8–A10   | Fixed                                                                                                                                                                                                          |
| A11      | Fixed for Bonjour. SSDP is not used on iOS: the multicast entitlement has to be requested from Apple                                                                                                          |
| A12, A13 | Fixed in the plugin and the app; needs an iPhone, a Mac and a second Apple device nearby to confirm                                                                                                            |
| A14–A16  | Fixed. A16 follows the archived PRD: one phone per desktop                                                                                                                                                     |
| B1–B12   | Fixed                                                                                                                                                                                                          |
| B13      | Partly: the desktop shows a firewall hint under the QR code on Windows. No firewall rule is installed; the MSIX tooling has no option for one                                                                  |
| B14–B22  | Fixed. B19 (Windows tray icon, single instance) needs a Windows machine to confirm                                                                                                                             |

Also fixed with them: C1, C2, C3 (stale MPC sessions, MPC teardown on disconnect), C4 (a fixed peer name, so a long Mac name can't crash it), C5, C6, C7 (native logs in debug builds only, the raw QR no longer printed) and C10. From the records audit: B2, B3, B4 (sources stamped by the triggers in milliseconds), B16, and the skipped percent-encoded-URL `BUG:` test, now a passing test.

Backup status, found while testing: the phone's backup handler started only when the settings sheet opened, so it missed the desktop's report sent on connect and stayed on "Waiting..."; it now starts with the app, forgets the report when the link drops and says when the desktop has no backup folder. On the desktop, the settings row showed the built-in default folder as if it were chosen; settings, the status row and the home card now all say no folder is chosen until the user picks one.

New tests: the link (handshake, approval, takeover of a half-open socket, replay, frame caps, keep-alive, MPC with a stranger nearby), `CommunicationBloc` on real sockets (pairing and the key change, approval, reconnecting, Disconnect, re-pairing), the engine (outbox, conflicts, column filtering, reconciliation, files) and `LwwSyncBloc` with two devices end to end (lost batches and acks, offline edits, simultaneous edits, files, a new peer, one reload per burst).

Still to do on devices: every phone/desktop pair over TCP; iPhone ↔ Mac over MPC with another iPhone or Mac nearby; a first sync of a library of several hundred MB; secure storage after an app update on each platform (the key moves out of preferences); Windows tray, second instance and firewall; Mac sleep and wake.

Found while auditing, not yet triaged:

- `architecture.md` is wrong in two places. The reconnect back-off "3 s base, doubling, 5 attempts" never runs (A10). And `fhir_resource` doesn't really store a tie-break `device_id`: only the v10 backfill ever set it (B2).
- `OfflineQueueService` merges `record_notes` by `id`, not `uuid`. That is safe today only because a queue never leaves its device and local note ids are AUTOINCREMENT.

---

## A. Critical and high

| ID  | Issue                                                                                        | Area           | Severity | Confidence       | Decision |
| --- | -------------------------------------------------------------------------------------------- | -------------- | -------- | ---------------- | -------- |
| A1  | Edits made in the same second after a sync are never sent                                    | Engine         | High     | Verified         |          |
| A2  | The last sync time moves when a delta is written, not when the peer has applied it           | Engine, BLoC   | High     | Verified         |          |
| A3  | Receiving a delta moves the last sync time past local edits not yet sent                     | BLoC           | High     | Verified         |          |
| A4  | A drop right after connecting empties the offline queue                                      | BLoC           | High     | Verified         |          |
| A5  | Sync handlers run concurrently and share one status, so a sync is skipped and then passed over | BLoC         | High     | Traced           |          |
| A6  | Reconciliation resends whole tables with every attachment, from both sides, twice per connect | Engine, BLoC  | High     | Traced, device   |          |
| A7  | Large frames trip the pong timeout and are reassembled in quadratic time                     | Transport      | High     | Traced           |          |
| A8  | The phone reports "Connected" after a bare TCP handshake                                     | Transport      | High     | Verified         |          |
| A9  | The desktop gives its slot to the first socket; a reconnecting phone is parked as pending    | Transport      | High     | Verified, device |          |
| A10 | The reconnect counter resets on every connect: a rejected key loops, an outage gets one retry | Transport     | High     | Verified         |          |
| A11 | mDNS never resolves a service; SSDP lacks the iOS multicast entitlement                      | Transport      | High     | Verified, device |          |
| A12 | The Mac accepts any MPC peer, and that peer takes over all its outgoing traffic              | MPC, macOS     | High     | Verified         |          |
| A13 | The iPhone invites every `hw-sync` advertiser and counts as connected before a hello         | MPC, iOS       | High     | Verified         |          |
| A14 | When MPC drops, the transport still reports connected, so changes are neither sent nor queued | MPC, transport | High     | Verified         |          |
| A15 | Captured frames replay: the hello has no freshness and frames have no counter or direction   | Transport      | High     | Verified         |          |
| A16 | Any phone that scans the desktop's QR receives every paired phone's records                  | Pairing, BLoC  | High     | Traced           |          |

### A1. Edits made in the same second after a sync are never sent

- **Where:**
  - The triggers stamp whole seconds: `CAST(strftime('%s','now') * 1000 AS INTEGER)` in `lib/core/data/local/app_database.dart:298,307` (and `:260`).
  - The last sync time is set from `DateTime.now()` in milliseconds: `change_watcher_service.dart:108`, `lww_sync_bloc.dart:169,236,328`.
  - The delta query is `updated_at >= ?` (`lww_sync_service.dart:46`).
- **What happens:**
  1. The watcher sends a delta at 12:00:00.650 and sets the last sync time to 12:00:00.650.
  2. The user edits a note at 12:00:00.900; the trigger stamps it 12:00:00.000.
  3. The next delta leaves it out. The probe confirmed this: cursor `1793352437937`, row written after it stamped `1793352437000`, 0 rows returned.
  
  Note edits, record edits and attachment links all rely on the trigger. An edited row leaves the counts equal, so reconciliation never resends it. A new row arrives only with the next count mismatch.
- **Fix:** stamp milliseconds in the triggers (`CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)`), or keep the cursor at the highest `updated_at` actually sent (see A2).

### A2. The last sync time moves when a delta is written, not when the peer has applied it

- **Where:**
  - The cursor moves after a send: `change_watcher_service.dart:86-89,107-108` and `lww_sync_bloc.dart:122,158-159,168-169,316,327-328`.
  - `sync.ack` only trims the offline queue (`lww_sync_bloc.dart:73-80`).
  - With no socket, `TcpService.sendMessage` returns normally (`tcp_service.dart:686-691`); the server isolate's `client?.add` is fire-and-forget (`:316-325`).
  - `applyDelta` runs row by row without a transaction (`lww_sync_service.dart:96-122`).
- **What happens:** the phone leaves Wi-Fi, or iOS suspends it, just as the watcher sends three note edits. `sendData` writes into a dead or null socket without an error, and the last sync time becomes now. The edits are behind the cursor and the counts are equal, so they never reach the desktop until the same rows are edited again.

  Rows are also lost when the receiver fails partway through: an unknown column, a constraint, a frame over the 1 GiB cap, or a JSON error swallowed at `lww_sync_bloc.dart:104`. That failure also leaves the delta half applied. The same holds on the desktop. "Last synced" in the UI follows the same cursor (B16).
- **Fix:** keep a cursor per table, moved only on the peer's `sync.ack`, to the highest `updated_at` in that delta. Acknowledge only after the delta applied in one transaction. Make `sendMessage` throw when no transport is live.

### A3. Receiving a delta moves the last sync time past local edits not yet sent

- **Where:** `lww_sync_bloc.dart:235-236`: every `DeltaReceived` sets the single shared `lww_last_sync_timestamp`. Pinned as `KNOWN ISSUE` (`lww_sync_bloc_test.dart:962`), but not in the backlog.
- **What happens:**
  1. The phone user saves a note at t.
  2. The desktop pushes a delta at t + 0.3 s. Applying it restarts the watcher's 500 ms debounce, and the BLoC sets the last sync time to t + 0.4 s.
  3. The watcher then asks for `updated_at >= t + 0.4 s`, and the note is never sent.
  
  The same mechanism makes a cleared offline queue lose more: on connect, the desktop's delta can land before the phone's own `SyncTriggered` reads the cursor.
- **Fix:** separate "sent up to" from "received up to"; with A2's per-table, ack-driven cursor, receiving never moves the sending cursor.

### A4. A drop right after connecting empties the offline queue

- **Where:** `lww_sync_bloc.dart:270-280` waits 200 ms and calls `flush()` without checking the link again. `offline_queue_service.dart:48-56` counts an item as sent unless `sendData` throws, and A2 shows it never does. The test fake throws `SocketException` on a drop (`lww_sync_test_helpers.dart:60-65`), so the tests exercise a re-queue path the real transport never reaches.
- **What happens:**
  1. The user edits records offline. They are queued, and the last sync time has already moved forward (pinned at `lww_sync_bloc_test.dart:999`).
  2. The phone connects, and the link drops within 200 ms: Wi-Fi flaps, the key is wrong, or the desktop parked the phone as pending (A9).
  3. `flush()` "sends" every delta into nothing and saves an empty queue. The changes are lost without any app restart.
- **Fix:** check the link after the delay, and remove queue entries on `sync.ack`, not on send.

### A5. Sync handlers run concurrently and share one status, so a sync is skipped and then passed over

- **Where:** `lww_sync_bloc.dart:36-41` (no `transformer:`); the guard at `:119` reads a `syncStatus` that `DeltaReceived` (`:206-213,238-244`) and `TableStatusReceived` (`:304-309,331-336`) also set.
- **What happens:**
  1. On connect both sides send `sync.status`. The record counts differ, so the phone's `TableStatusReceived` sets "syncing" and spends seconds embedding attachments.
  2. The phone's own `SyncTriggered` arrives and returns at `:119`; note edits, whose counts match, are not sent.
  3. `TableStatusReceived` then sets the last sync time to now (`:327-328`), so the notes are passed over for good.
  
  The opposite can also happen: a finishing `DeltaReceived` sets "idle" while a sync is still sending, so a tap on Sync Now, a handover result or a saved scan starts a second run that sends the same deltas. With three deltas in flight, the first to finish shows "Last synced" while the others are still being applied.
- **Fix:** `sequential()` for the sync handlers, or one queue for them, and a separate flag for "outgoing sync in flight".

### A6. Reconciliation resends whole tables with every attachment, from both sides, twice per connect

- **Where:**
  - `lww_sync_bloc.dart:303-316`: when counts differ, `computeDelta(..., epoch 0)` runs with its default `embedAttachments: true`. The condition `localCount > 0 && != remote` holds on the side with fewer rows too.
  - `sync.status` goes out on connect (`:273-274`) and again after `SyncTriggered` (`:182-184`).
  - Each data frame is decoded three times on the main isolate (`lww_sync_bloc.dart:65`, `message_router.dart:22`, `backup_bloc.dart:59`) and decrypted in pure Dart there (`tcp_service.dart:720-760`).
- **What happens:** counts differ after any hard delete, which is a known bug, and after every first pairing. Each connection then makes both ends JSON-encode, base64 and encrypt all of `fhir_resource` with every file inline, as one frame, up to twice per side. Take a phone with 2 000 records and 300 MB of scans:
  - The data is held 4–5 times over on the UI isolate (string, UTF-8 bytes, ciphertext and its copy). Both UIs freeze, and iOS can kill the app.
  - A frame over 1 GiB is dropped by the desktop and sent again on every connect.
  - The receiver writes a new copy of every file (records audit B2).
- **Fix:** send `sync.status` once per connect. Reconcile with ids and `updated_at` (or a per-table hash) and send only the rows that differ, without files: the receiver asks for missing files in bounded chunks. Decode once, and encode and decrypt on an isolate.

### A7. Large frames trip the pong timeout and are reassembled in quadratic time

- **Where:**
  - `tcp_service.dart:771-777`: the 5 s pong deadline starts when the ping is queued. The ping then waits on `_writeLock`, which a large write holds through `await flush()` (`:665-668,689-690`). The peer's pong also waits behind any large frame it is sending.
  - `:560-564` copies the whole receive buffer on every chunk.
- **What happens:** the benchmark (64 KiB chunks, Mac, JIT) reassembled 10 MB in 108 ms, 25 MB in 637 ms and 50 MB in 2.4 s, so about 10 s for 100 MB, and longer on a phone.
  1. During the first sync of a real library (A6), a frame takes longer than the pong deadline.
  2. `_handleDisconnect` destroys the socket in the middle of the frame and the buffer is thrown away.
  3. On reconnect the counts still differ, and the same frame is sent again.
  
  The sync never finishes.
- **Fix:** reset the pong deadline whenever bytes arrive and start it only once the ping is written; read the length first and assemble with a `BytesBuilder`; cap frames well below 1 GiB and chunk deltas at the application layer.

### A8. The phone reports "Connected" after a bare TCP handshake

- **Where:** `tcp_service.dart:478` calls `_updateState(connected)` straight after `Socket.connect`, before the hello and before any reply. Client mode has no notion of a verified peer; `unverified` is server-only (`:568`). `communication_bloc.dart:301,323` then adds `CommunicationConnected`.
- **What happens:** the phone shows "Connected to \<desktop\>" and starts syncing as soon as anything accepts a connection: a parked socket on the real desktop (A9), a desktop that will reject the key (A10), another host now at the saved IP, or a spoofed discovery answer (B10). In each case:
  - `LwwSyncBloc` sends `sync.status`, flushes the queue into nothing (A4) and moves its cursor (A2).
  - A handover waits only for this state (`handover_utils.dart:59-60`), so its files go out too.
  
  Nothing leaks, because the frames are encrypted, but the data is lost for sync and the phone stops searching.
- **Fix:** the desktop answers every valid hello with an encrypted `ack` (or the challenge of A15); the phone reports connected only after it decrypts, and treats no reply within about 5 s as a failed connect.

### A9. The desktop gives its slot to the first socket; a reconnecting phone is parked as pending

- **Where:**
  - `tcp_service.dart:301-316`: the first socket becomes `clientSocket` before any hello; later ones go to pending, and nothing is read from them.
  - `:339-357`: `acceptPending` is the only way out of pending, and no reachable UI calls it (the dialog lives on the dead `DesktopPage`).
  - `:260-267`: when the client closes, pending is not promoted.
  - The server never pings and has no idle timeout. A received `kill` doesn't close the isolate's socket (`:639-642,782-785`).
- **What happens:**
  1. The phone loses Wi-Fi for a moment; its ping times out and it reconnects.
  2. The desktop never got a FIN and keeps the half-open socket.
  3. The phone's new socket is parked: its hello and pings go unanswered, but A8 says "Connected". It drops after 15 s, and A10 restarts the cycle.
  
  Meanwhile the desktop shows "Connected" until TCP gives up on the dead socket, which takes minutes, or never if the desktop doesn't write. Someone on the network with no key can do the same on purpose: looping `nc desktop 49152` holds the slot for 15 s per connection.
- **Fix:** track hello state per socket in the isolate; a socket that verifies replaces the current client (newest verified wins), an unverified one never displaces anything; drop a client that sends no ping for about 30 s; close the socket on `kill`.

### A10. The reconnect counter resets on every connect: a rejected key loops, an outage gets one retry

- **Where:**
  - `communication_bloc.dart:335-336`: `_onConnected` resets `_reconnectAttempts`, and A8 fires it on the bare handshake. `:452` resets it too.
  - The back-off and "clear the pairing" path is at `:388-414`.
  - `:366-367` ignores a reconnect that fails, because the status is then `discovering`, not `connected`.
- **What happens:**
  - **Rejected key.** The desktop pressed "New QR code" and the phone still has the old key. Every ~3 s the phone connects, the counter resets, the desktop drops the hello, and a full LWW status, flush and sync runs. The UI flips between Connected and Reconnecting for ever, and `desktopPairingExpired` is never shown.
  - **Real outage** (desktop quit, rebooting, asleep). Exactly one retry 3 s after the drop: saved IP (5 s), discovery (3 s), MPC (10 s on iOS), "Desktop not found", then nothing. Recovery comes only from an app resume, a manual Reconnect or a handover.
  
  The documented "doubling, 5 attempts" back-off, and the pairing being cleared after it, are unreachable.
- **Fix:** reset the counter only after the desktop's answer (A8); schedule the next back-off from the failed attempt as well; show "pairing rejected" on an explicit key failure instead of clearing the pairing after N tries; update `architecture.md`.

### A11. mDNS never resolves a service; SSDP lacks the iOS multicast entitlement

- **Where:** `mdns_service.dart:47-59` waits for `discoveryServiceResolved` but never calls `service.resolve(...)` on `discoveryServiceFound`. bonsoir 5.1 doesn't resolve on its own: its Android plugin only emits "found". SSDP's multicast send (`ssdp_service.dart:124-128`) needs `com.apple.developer.networking.multicast` on iOS 14+, and `ios/Runner/Runner.entitlements` doesn't have it.
- **What happens:** mDNS always times out after 3 s. Suppose the desktop's address changes: a new DHCP lease, another network, or port 49152 taken so it falls back to a random port (`tcp_service.dart:228-233`). Then:
  - An iPhone paired with a **Windows** desktop can't find it at all and shows "Desktop not found".
  - An iPhone paired with a Mac falls back to MPC alone.
  - Android relies on SSDP alone.
- **Fix:** call `resolve` on `discoveryServiceFound`, with an identity check (B10); request the multicast entitlement, or drop SSDP on iOS and rely on Bonjour.

### A12. The Mac accepts any MPC peer, and that peer takes over all its outgoing traffic

- **Where:**
  - In the plugin, `airdrop: macos/Classes/DesktopSyncManager.swift:140-143` accepts every invitation without looking at `context` or `connectedPeer`. Advertising never stops after a connect (`:50-56`). `connectedPeer` is overwritten on every `.connected` (`:109`). `didReceive` doesn't check the sender (`:128-131`).
  - In the app, `communication_bloc.dart:113-116` calls `setUseMpc(true)` and adds `CommunicationConnected(ip: 'mpc')` on any MPC connect. From then on every send goes to MPC (`tcp_service.dart:677-679`), even with a verified TCP phone connected.
- **What happens:**
  1. Phone A is syncing with the Mac over TCP. Phone B, paired with another Mac that is off (a second person in the home), falls through to MPC and invites this Mac, which accepts automatically.
  2. The Mac shows "Connected" before any hello, and sends its hello, deltas, backups and pongs to B, which can't decrypt them.
  3. A's pings get no pong. After 15 s A drops and reconnects, and since its counter resets (A10) it cycles connect, sync, timeout every 15–18 s and never finishes a sync.
  4. When B leaves, the Mac tears MPC down and reports a disconnect while A may still be on TCP.
- **Fix:** natively, stop advertising once connected, accept only invitations that carry a proof of the pairing (an HMAC of a nonce under the pairing key; the Dart API needs to pass a token for it), reject invitations while connected, and drop data from other peers. In Dart, switch to MPC only after a valid hello over it, and never while a verified TCP client is live.

### A13. The iPhone invites every `hw-sync` advertiser and counts as connected before a hello

- **Where:** `airdrop: ios/Classes/desktop_sync/DesktopSyncManager.swift:138-145` invites every peer it finds while `connectedPeer == nil`, ignoring `discoveryInfo`; `:96` overwrites `connectedPeer`; `:115-118` accepts data from any peer. App: `communication_bloc.dart:277-282` (`_tryMpc` succeeds on the native connect) and `:352-359` (hello sent, no ack awaited). MPC has no ping (the ping timer starts only in `connectToServer`, `tcp_service.dart:497`).
- **What happens:** with two Macs in range (office, family), the phone invites both, both accept, and the phone binds to whichever connected last. If that is the wrong Mac, it drops the phone's frames. The paired Mac's frames still arrive and decrypt, but the replies go elsewhere, so sync is half-duplex and broken with nothing to notice it. With only a stranger's Mac in range, the phone stays "connected" to it and takes over its traffic as in A12.
- **Fix:** the Mac advertises a token derived from the pairing (a rotating HMAC, not the raw device id); the phone invites only a matching peer and stops browsing once it has; MPC counts as connected only after the peer's hello or ack within a timeout; run ping/pong over MPC.

### A14. When MPC drops, the transport still reports connected, so changes are neither sent nor queued

- **Where:**
  - A valid MPC hello sets `ConnectionState.connected` (`tcp_service.dart:655`).
  - On MPC loss only `setUseMpc(false)` runs (`communication_bloc.dart:117-118,378`). The desktop branch (`:384-387`) restarts MPC but never resets `TcpService`.
  - `ChangeWatcherService` and `LwwSyncBloc` read `_tcpService.isConnected` (`change_watcher_service.dart:72`, `lww_sync_bloc.dart:56-59,122,315`).
  - With MPC off and no socket, `sendMessage` does nothing (`tcp_service.dart:677-694`).
- **What happens:** the iPhone leaves range, or iOS backgrounds the app and MPC drops. On the Mac, `isConnected` stays true:
  1. A desktop edit or a handover result is "sent", so it isn't queued.
  2. The cursor moves (A2), and the phone never gets the change.
  3. When the phone comes back over MPC, its hello sets a state that is already "connected". So the desktop's LWW gets no `ConnectionChanged(true)`: no `sync.status`, no queue flush.
- **Fix:** have `TcpService` follow the MPC transport's state and call `_handleDisconnect()` when MPC drops while it is in use, or give "connected" one owner across both transports; make sends without a live transport throw (A2).

### A15. Captured frames replay: the hello has no freshness and frames have no counter or direction

- **Where:**
  - The hello check only compares `pairing_key_hash` with a SHA-256 of the key (`tcp_service.dart:594-604,617-629,765-769`).
  - GCM runs with empty AAD, no sequence number and no direction byte, with one key both ways (`:706-724`).
  - Over MPC, data frames are accepted before any hello (`:144-158`, pinned by `tcp_service_test.dart:708-724`).
- **What happens:** someone records one session's traffic: on the same Wi-Fi with the WPA2 handshake captured, on an open network, or as the stray MPC peer of A12/A13. They learn nothing from it, but later, while the phone is away, they can:
  1. Resend the captured hello byte for byte. The desktop shows "Connected to \<the user's phone\>" and flushes its offline queue into the attacker's socket, and those changes are lost (A4).
  2. Replay captured phone frames. A `sync.delta` brings back rows the user has since deleted. A `handover.offer` with its `handover.file` frames makes the desktop run the AI extraction again and create duplicate records. Each `backup.request` writes another snapshot. A `kill` disconnects.
  3. Hold the slot with a verified socket for as long as they like (A9).
- **Fix:** a challenge–response hello (the server sends a nonce, the client returns an HMAC of it); per-session, per-direction keys derived from it (HKDF); a direction byte and a monotonic counter in the AAD, rejecting counters that don't increase. This is the same protocol change as A12/A13.

### A16. Any phone that scans the desktop's QR receives every paired phone's records

- **Where:**
  - The desktop shows the same pairing QR, which contains the AES key, whenever no phone is connected, including full screen (`connection_dialog.dart:346-364,411-447`, `connection_card.dart:36-50`).
  - The key changes only on "New QR code", and any number of phones holding it are trusted alike.
  - The desktop pushes whole tables to any peer whose counts differ (`lww_sync_bloc.dart:303-316`), and there is one global cursor, nothing per peer (`lww_sync_service.dart:16`).
- **What happens:** person A's phone is paired. While A is away, person B opens the desktop app and scans the QR on screen, or a screenshot or screen share of it. B connects with no prompt, because the slot is free, and the count mismatch sends all of A's records, notes and attachment files to B's phone. B's records go to A on A's next connect, and both phones now mix two people's records.
- **Fix:** hide the QR once a phone is paired, and show it again only on "New QR code" (quick). Then a one-time pairing token that expires or is used up on the first hello, a key and device id per phone, sync state per peer, and a confirmation on the desktop before a new phone receives existing data.

---

## B. Medium

| ID  | Issue                                                                                       | Area               | Confidence     | Decision |
| --- | ------------------------------------------------------------------------------------------- | ------------------ | -------------- | -------- |
| B1  | Incoming column names are pasted into SQL; a newer peer's column aborts the delta            | Engine             | Verified       |          |
| B2  | The tie-break always lets the incoming row win, and a tie re-stamps the row                  | Engine             | Verified       |          |
| B3  | A device whose clock is behind loses its edits; one ahead makes rows echo                    | Engine             | Traced, device |          |
| B4  | Sync state is never reset on re-pairing, unpairing or a backup restore                       | Engine, BLoC       | Verified       |          |
| B5  | A delta isn't applied in a transaction; quitting the desktop mid-sync leaves it half applied | Engine, desktop    | Traced         |          |
| B6  | `sync.file_request` serves any file in Documents and reads it whole into memory              | Engine             | Traced         |          |
| B7  | An attachment with a space or a non-ASCII name is fetched again on every verify, never linked | Engine            | Verified       |          |
| B8  | Applying a delta and repairing URLs run on the UI isolate, row by row                        | Engine             | Traced         |          |
| B9  | Over MPC each frame is one message: no chunking, no size cap on receive                      | MPC                | Verified, device |        |
| B10 | Discovery saves an address before verifying it; mDNS checks no identity; SSDP trusts `LOCATION` | Transport       | Verified       |          |
| B11 | The phone accepts 1 GiB frames from a server that has proven nothing                        | Transport          | Verified       |          |
| B12 | The desktop server stays bound to its startup IP, or to loopback                            | Transport, desktop | Traced, device |          |
| B13 | Windows: no firewall rule; on a Public network the phone can't reach the desktop             | Desktop            | Device         |          |
| B14 | Scanning a new desktop's QR while connected keeps syncing with the old one                   | Pairing            | Verified       |          |
| B15 | A failed reconciliation leaves the UI on "Syncing" and blocks every later sync               | BLoC               | Verified       |          |
| B16 | The sync UI reports success, "just now" and rows sent when nothing was delivered             | UI                 | Verified       |          |
| B17 | Sync and transport errors are swallowed and never shown                                     | BLoC, transport    | Verified       |          |
| B18 | A backup started from the phone can miss the phone's latest changes                         | BLoC, backup       | Traced         |          |
| B19 | Windows: no tray icon, and a second instance shares the database                            | Desktop            | Device         |          |
| B20 | A timed-out MPC attempt keeps browsing, and a late connect hijacks a working TCP link        | MPC, iOS           | Verified       |          |
| B21 | The pairing key sits in plain preferences and backups, and a scanned key isn't validated    | Pairing            | Verified       |          |
| B22 | Every change from the other device clears "in sync" until the next manual sync or reconnect | BLoC, UI           | Verified       |          |

- **B1.** `_upsertRow` (`lww_sync_service.dart:212-227`) builds the column list and `SET k = excluded.k` from the peer's `row.keys`. A peer holding the key can send a key that is itself SQL. In the probe:
  - one key copied the local-only `processing_sessions` (unsaved scans, patient details, file paths) into a synced row, and a far-future `updated_at` sent it back in every delta;
  - another rewrote every `fhir_resource` row in one statement, skipping the LWW check.
  
  The same code makes a newer app's extra column throw at the first row, which aborts the delta partway (pinned, `lww_sync_service_test.dart:537`; it breaks backlog rule 4 as soon as either side adds a column). Fix: keep only incoming keys that are columns of the table (`PRAGMA table_info`), quote them, and log what was dropped. This also makes newer peers compatible.
- **B2.** `_shouldApplyIncoming` (`lww_sync_service.dart:154-157`) compares the sender's id with the row's stored `device_id`. Only the v10 backfill ever set that column, and `INSERT OR REPLACE` (records audit B1) clears it. So in every table the incoming row wins a tie, and the trigger re-stamps the winner with the wall clock. With whole-second stamps (A1), two edits in the same second swap, and each side keeps the other's version for good. Every duplicate delivery (queue, full resend) also looks like a new edit. Pinned at `lww_sync_service_test.dart:304,334`. Fix: skip identical rows; break real ties with `delta.deviceId` against `getLocalDeviceId()`, which gives the same answer on both ends.
- **B3.** The triggers stamp `now` even when it is earlier than `OLD.updated_at` (`app_database.dart:255-261,302-309`), and incoming `updated_at` has no bound (`lww_sync_service.dart:104,151`).
  - **Clock behind.** The desktop runs two minutes ahead. A phone edit after a desktop edit is stamped lower and rejected; the devices differ for good, and equal counts hide it.
  - **Clock ahead.** A phone whose clock is a day ahead leaves rows stamped tomorrow. They match every desktop delta, attachments included, for a day.
  
  Fix: stamp `MAX(now_ms, OLD.updated_at + 1)` (a hybrid logical clock); reject or clamp incoming times beyond now plus a tolerance.
- **B4.** `resetLastSyncTimestamp` (`lww_sync_service.dart:284`) has no caller. Saving a pairing (`connection_dialog.dart:51,505`), "New QR code" (`communication_bloc.dart:169-197`) and clearing the pairing (`:397`) leave the cursor, the queue and `isSynced` alone. Agreement is judged by counts alone (`lww_sync_bloc.dart:303,357`).
  - A phone that synced with desktop A pairs with B: A's queue goes to B, edits to rows B already has are skipped, and the dialog shows "Last synced 2 days ago · Desktop-B" (`sync_dialog.dart:206-212`).
  - A desktop that restores last week's backup keeps that week's `updated_at`, so the phone's edits from before its cursor never return.
  
  Fix: a cursor per peer device id, reset on pairing and restore; verify with per-table count, `max(updated_at)` and a hash.
- **B5.** `applyDelta` (`lww_sync_service.dart:96-122`) upserts row by row with no transaction. Tray → Quit and the window close call `exit(0)` (`tray_bloc.dart:132-139`, `window_lifecycle_service.dart:47-51`) without a `kill` or waiting for a delta in progress. A quit during a large incoming delta leaves half of it applied, and the phone has already moved its cursor (A2). Fix: one transaction per delta, acknowledged after it commits (step 1); on quit, send `kill` and wait for the delta being applied.
- **B6.** `resolveFileRequests` (`lww_sync_service.dart:325-340`) reads any file that `resolveFile` finds inside Documents (`attachment_sync_service.dart:145-171`) with `readAsBytes`, then base64s it on the UI isolate. Only `db.sqlite*` is refused. The AI models live in `Documents/ai_models/`, so a request for a multi-GB GGUF, or a synced row whose URL names one, crashes the app; such a row crashes it again at every full resend. Fix: serve only paths a live DocumentReference refers to, with a size cap, streamed in chunks.
- **B7.** Extends the skipped `BUG:` test at `lww_sync_service_test.dart:1245` (the backlog's "percent-encoded attachment URL not repointed").
  1. The attachment's URL is stored percent-encoded (`record_attachments_bloc.dart:299`).
  2. The peer sends the file back under its decoded name, but `_updateAttachmentUrls` filters rows with `raw.contains(oldPath)` on the encoded JSON (`lww_sync_service.dart:408`), so the URL is never repointed.
  3. Every `sync.verify` then asks for the file again and saves another `Blood_test_<8>.pdf`. Disk use grows without limit and the attachment never shows. "Analize sânge.pdf" behaves the same (`\w` is ASCII only).
  
  Fix: compare decoded URLs and drop the `contains` pre-filter.
- **B8.** The database is opened with `NativeDatabase(file)` on the UI isolate (records audit B5). Applying a delta takes up to three statements per row:
  - `_localHasBrokenAttachment` asks for the documents directory once for each row that loses (`:180`).
  - `fixBrokenAttachmentUrls` runs after every `fhir_resource` delta, decodes every DocumentReference and lists Documents for each missing file (`:486`).
  
  With thousands of rows the UI freezes for seconds on both ends. Fix: open the database in the background, apply in one transaction, repair only the rows just applied.
- **B9.** Each encrypted frame is one `session.send(..., .reliable)` (`airdrop: ios/…/DesktopSyncManager.swift:65`, `airdrop: macos/…/DesktopSyncManager.swift:78`), copied through the method channel on the main thread. The receive path has no counterpart to the TCP caps (`tcp_service.dart:144-158`).
  - A first sync of a real library (A6) is one message of tens to hundreds of MB. Apple recommends resources or streams for that size, and a failed send is swallowed (C6), so the table never syncs.
  - Any MPC peer (A12) can send a large blob, which is copied into Dart and run through GCM before the tag fails.
  
  Fix: chunk frames above about 256 KiB with sequence numbers, or use `sendResource`; drop received frames above a cap natively.
- **B10.** `discovery_service.dart:97-106` saves the first discovery result as `lastIp` before any connect. `mdns_service.dart:48-59` takes the first `_healthwallet._tcp` service, whose name is a fixed "HealthWallet Desktop" with no device id. SSDP filters on the device id (`ssdp_service.dart:98-101`), but the desktop multicasts it every 30 s (`:146-153`), and the phone takes the IP from the `LOCATION` payload, not the datagram's sender (`:192-201`). A host on the network answers faster with its own address, the phone saves it, and A8 makes the saved address "work". From then on the phone never reaches the real desktop. Fix: save an address only after the authenticated answer (A8); put an HMAC of the device id in the mDNS TXT record and filter on it; use the datagram's source address.
- **B11.** In client mode the frame cap is 1 GiB from the first byte (`tcp_service.dart:568-569`, pinned by `tcp_service_test.dart:289`). Any host at the saved or discovered address (B10) announces a frame just under 1 GiB and streams junk. The phone grows its buffer toward 1 GiB with quadratic copying (A7), until iOS kills the app or Android runs out of memory. Fix: keep the 64 KiB cap on the client until the first frame from the server decrypts.
- **B12.** The server binds to the address it finds at startup (`tcp_service.dart:221-233`), or `127.0.0.1` when no interface is up (`:407`). SSDP's `LOCATION` is fixed when the server starts (`communication_bloc.dart:214-218`), and nothing listens for network changes. A laptop that moves networks or gets a new lease refuses connections on its new address, and keeps advertising the old one. A desktop started before Wi-Fi is up advertises loopback and puts it in the QR. Either way it stays unreachable until a restart. Fix: bind `anyIPv4`, or restart the server and advertising on network changes; never advertise or encode loopback or link-local addresses.
- **B13.** Nothing in `windows/`, `scripts/` or CI adds a firewall rule; TCP 49152 and UDP 1900 inbound depend on the first-run prompt, which by default allows private networks only, while Windows 11 marks new networks Public. On such a network the phone can't reach the desktop and the desktop shows no error. Fix: inbound rules in the installer; a hint on the desktop when no phone has connected for a while.
- **B14.** The scanner is reachable while connected (`sync_section.dart:107-110` → `connection_dialog.dart:37-63`). `_onPairingCompleted` → `_onConnectionRequested` returns early when already connected (`communication_bloc.dart:233-243`), so the snackbar says "Paired with B" while the socket and `_pairingKey` stay on A until the link drops. Fix: disconnect TCP and MPC first whenever the device id or key changed.
- **B15.** `_onTableStatusReceived` (`lww_sync_bloc.dart:292-345`) has no try/catch around `computeDelta` or `sendData`. If either throws (a reset socket, a file that can't be embedded), the idle emit is skipped, so:
  - Sync Now stays "Syncing…" and disabled (`sync_dialog.dart:177-185`).
  - Every `SyncTriggered` returns at `:119`.
  - The tray shows "Syncing".
  
  This lasts until another status or delta arrives. Fix: catch, emit the error and return to idle; send `sync.verify` only on success.
- **B16.** The offline path of `SyncTriggered` (`lww_sync_bloc.dart:168-178`) sets `lastSyncTime: now`, counts queued rows as `sentRows` and sets `isSynced: totalSent == 0`. It runs whenever a scan is saved or a handover returns while the desktop is unreachable (`processing_page.dart:206`, `handover_sender_service.dart:200,225`).
  - The dialog then shows "Last synced: just now · 5 sent" while nothing left the phone.
  - When connected, the green check (`sync_section.dart:494-510`) means only equal row counts (`:351-366`).
  - "{count} changes" is fed the number of queued *tables* (`offline_queue_service.dart:82`).
  
  Fix: move the last sync time and the sent count only on acknowledged delivery; show "queued" separately; count rows, with an ICU plural.
- **B17.** Errors are swallowed in three places:
  - **Dropped messages:** a `sync.*` message that fails to parse, such as a row from a newer schema, is dropped without a log, an ack or a state change (`lww_sync_bloc.dart:104`).
  - **Empty catches:** `lww_sync_bloc.dart:188,275,343,379,388,394`.
  - **File requests and file data:** handled outside the BLoC, unawaited, with errors dropped (`:96,102`).
  
  On the desktop the server isolate runs in `runZonedGuarded(..., (_, _) {})` (`tcp_service.dart:211`). If the bind or `NetworkInterface.list` throws there, `startServer` never completes (`:179-207`) and the desktop has no server and no error. The user sees only a missing attachment, or a desktop no phone can find. Fix: log with `logger`; route file messages through BLoC events with a sequential transformer; emit an error state when a `sync.*` message can't be processed; report isolate errors and fail `startServer`.
- **B18.** The Backup button (`sync_section.dart:549-560`) fires `SyncTriggered` and immediately sends `backup.request` from the widget through `getIt<TcpService>()`. On the desktop, the backup handler (`backup_bloc.dart:368-388`) starts its own outgoing sync, waits a fixed 2 s and snapshots. With 30 new records and their PDFs, the phone's deltas take longer than that, so "Backup done" shows for a backup without the newest records. Fix: snapshot after the phone's deltas are acknowledged; move the request into `BackupBloc`.
- **B19.** `tray_service.dart:38-40` passes the same `.png` on both platforms; tray_manager on Windows loads it with `LoadImage(IMAGE_ICON, …)`, which needs a `.ico`, so the tray icon is empty. Closing the window hides to the tray by default (`window_lifecycle_service.dart:54-59`), leaving nothing visible to restore or quit. Launching again starts a second process with no single-instance guard. Port 49152 is taken, so it binds a random port and saves that into the pairing (`communication_bloc.dart:205-212`), and two LWW engines now write one SQLite file. Fix: a `.ico` for Windows; a single-instance guard that brings the window forward.
- **B20.** When `_tryMpc` times out (`communication_bloc.dart:284-285`) it doesn't stop MPC. The iPhone keeps browsing, since browsing stops only on `.connected` (`airdrop: ios/…/DesktopSyncManager.swift:97`), and invites any `hw-sync` peer it finds later. If the user has meanwhile connected over TCP, a late MPC connect switches every send to MPC while the TCP socket stays open (`:113-116`). Fix: disconnect MPC when `_tryMpc` times out and when TCP succeeds; ignore an MPC connect while another transport is up.
- **B21.** The pairing, key included, is stored as plain JSON in SharedPreferences (`pairing_storage_service.dart:16-19`). That puts it in iCloud and iTunes backups, in Google auto-backup (`AndroidManifest.xml` sets no `allowBackup`) and in a JSON file under `%APPDATA%` on Windows. Combined with A15 and A16, it is a permanent bearer secret.

  The scanned `pairing_key` isn't validated either (`connection_dialog.dart:40-48,477-485`, `sync_page.dart:121-129`):
  - An empty or short key is zero-padded into a weak AES key (`tcp_service.dart:750-758`).
  - A key that isn't valid base64 makes every encrypt throw, and the open socket leaks for 15 s.
  
  Fix: Keychain/Keystore through `flutter_secure_storage`, excluded from backups; require a key that decodes to exactly 32 bytes when scanning; destroy the socket on a failed connect.
- **B22.** `isSynced` is set to true only by a `sync.verify` with equal counts (`lww_sync_bloc.dart:362-366`), or by a `SyncTriggered` that sent nothing (`:175`), even offline. A peer sends `sync.verify` only in reply to a `sync.status` (`:338-344`). That reply comes on connect, or after a `SyncTriggered` (Sync Now, a handover result, a saved scan).

  Every `DeltaReceived` sets `isSynced` to false (`:210`), and so does the start of every `SyncTriggered` (`:129`). The change watcher sends a `sync.delta` 500 ms after any edit (`change_watcher_service.dart:86-89`), but never a `sync.status`, so no verify follows and nothing sets it back. What each screen shows after the phone edits a note while connected:
  - **Desktop, top card:** turns red with "just now" (`home_page.dart:598-606`: red whenever not `isSynced` and nothing is queued). It stays red until someone presses Sync Now or the link reconnects.
  - **Phone, sync row in the settings sheet:** after a desktop edit, it drops from "In sync" to a second green "Connected" (`sync_section.dart:489-492`).
  
  If any table's counts never match, nothing on either screen ever shows "in sync". That happens when a row fails to apply (B1, B17), with a v11 peer that rejects the notes `uuid`, or with records from another phone (A16). Each connect and Sync Now then resends that whole table (A6).

  The rest of the state drifts the same way:
  - The watcher's sends move the stored last sync time but not `state.lastSyncTime`, so the sending device's "Last synced" lags.
  - What the watcher queues offline never updates `pendingChangeCount`, which changes only at start-up, at the end of a `SyncTriggered` and on connect.
  - On the phone, "x min ago" doesn't refresh while the sheet is open (no periodic rebuild, unlike the desktop card).
  - A connect runs `TableStatusReceived` and `SyncTriggered` at the same time, so the label can go Connected → Syncing → Connected → Syncing → In sync in a few seconds (A5).

  Fix: compute "in sync" from facts, not from the last event: connected, nothing queued or unacknowledged (A2), and the last verify matching. Have the receiver of a `sync.delta` answer with its counts, as it does for `sync.status`. Emit state from the change watcher's sends and queueing. Rebuild relative times periodically on mobile. Show "Connected" in the connection row only.

---

## C. Low

| ID  | Issue                                                                                                                                                                                                                                                                                              | Area             | Decision |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | -------- |
| C1  | Disconnect on the desktop is undone about 3 s later: the phone treats the `kill` as a drop and reconnects, and the server doesn't close its socket on `kill` (`communication_bloc.dart:390-434`, `tcp_service.dart:639-642,818-825`). Desktop Reconnect leaves the dialog on "Reconnecting…" until a phone connects (`:248-258`) | Transport        |          |
| C2  | If the desktop closes the socket during the hello, the phone ends on "Connected" with no socket: `CommunicationConnected` is added after the `Disconnected` event, and resume and Reconnect then do nothing (`tcp_service.dart:478-497`, `communication_bloc.dart:243,301`)                                   | Transport        |          |
| C3  | MPC native state: callbacks from a torn-down session aren't filtered, so a late `.notConnected` can end the new link; `connectedPeer` and `session` are read on MPC's queue and written on main; a manual disconnect on the phone leaves MPC up (`DesktopSyncManager.swift` both, `communication_bloc.dart:418-434`) | MPC              |          |
| C4  | `MCPeerID(displayName:)` throws on a name over 63 UTF-8 bytes. The Mac uses `Host.current().localizedName` at plugin registration, so a long or non-ASCII Mac name may crash the desktop at launch (device). On iOS 16+ every phone is "iPhone"                                                                       | MPC              |          |
| C5  | Advertise and browse failures only log; `startDesktop*` reports success at once, so with Local Network permission denied `_tryMpc` waits the full 10 s and the Mac's MPC is dead without a sign. `Info.plist` lists `_hw-sync._tcp` but not `_hw-sync._udp` (check on a device)                                   | MPC              |          |
| C6  | Native MPC send failures report success: no peer or a throwing `send` returns `result(nil)`, and `MpcTransport.send` swallows errors too, so the queue fallback is never reached (`DesktopSyncManager.swift` iOS `:61-69`, macOS `:74-82`; `mpc_transport.dart:67-73`). Part of A2's fix                   | MPC              |          |
| C7  | The Mac advertises its computer name and `{"app":"healthwallet"}` to anyone nearby the whole time it runs; native code logs peer names in release (`NSLog`, and macOS forwards every line to `debugPrint`); `sync_page.dart:111-113` prints the raw QR, pairing key included, in debug and profile builds          | MPC, pairing     |          |
| C8  | Progress and status are off: the progress bar and counts are set only by local syncs (`sync_dialog.dart:170-174`); the desktop home's sync badge is red for "not connected" (`home_page.dart:598-606`); "2 min ago" never refreshes in one layout (`:359`); the tray says "Up to date" with no phone ever paired       | UI               |          |
| C9  | A received file's extension comes from the dots in its title, ignoring `contentType`, so "photo 1.5" becomes `.5` and an untitled image `.bin`, and opens in the PDF viewer (`attachment_sync_service.dart:105-112`); a failed restore keeps the base64 inside `resource_raw` (`:53-59`)                         | Engine           |          |
| C10 | Desktop sends cross the isolate as `frame.toList()`, a boxed list of about 8 bytes per byte (measured 153 ms and about 400 MB for a 50 MB frame), rebuilt again on the other side (`tcp_service.dart:197-199,322-324,687`). Fix: `TransferableTypedData`                                                       | Transport        |          |
| C11 | macOS App Nap may throttle a desktop hidden in the tray, delaying pongs and sync (no `beginActivity` anywhere; device)                                                                                                                                                                                | Desktop          |          |
| C12 | Conventions: no `transformer:` in `LwwSyncBloc`, `CommunicationBloc` or `TrayBloc`; raw `OutlinedButton`/`ElevatedButton`/`TextButton`, `Colors.white`, numeric `EdgeInsets` and `fontSize` in `sync_section.dart` and `sync_dialog.dart`; sync and backup protocol in a widget (`sync_section.dart:549-560`); `getIt` in `HandoverSenderService` (data layer) | All              |          |

## T. Test gaps

| ID  | Gap                                                                                                                                                                                                                                                                                                   | Decision |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| T1  | The fakes don't behave like the real transport. `FakeTcpService` throws on a drop where the real one returns silently, so the re-queue paths are tested but never reached in production (A2, A4). Several tests pin the wrong behaviour: data frames before the MPC hello, swallowed MPC send errors, the 1 GiB client cap | |
| T2  | `CommunicationBloc` has no tests: discovery order, back-off and the counter reset, clearing the pairing, re-pairing while connected, the MPC branch, the zombie "connected" state (A8, A10, A14, B14, C2)                                                                                                    |          |
| T3  | Engine:<br>• a write in the same second after the cursor (A1, fails today)<br>• the cursor when delivery fails (A2)<br>• a column allowlist and injection (B1)<br>• clock skew (B3)<br>• the cursor per peer and its reset (B4)<br>• `file_request` limits (B6)<br>• a reconciliation's size and the absence of embedded files (A6)<br>• Windows paths across `PathResolver` and `LwwSyncService` |          |
| T4  | `LwwSyncBloc` concurrency:<br>• `SyncTriggered` during `TableStatusReceived` (A5)<br>• two statuses per connect (A6)<br>• a drop before `flush()` (A4)<br>• a failing reconciliation (B15)<br><br>There are no widget tests for `SyncDialog`, `DeviceSyncDialog`, the mobile sync section or the desktop sync card |          |
| T5  | Transport:<br>• a phone reconnecting while the server holds its half-open socket (A9)<br>• replaying a captured hello or data frame (A15)<br>• large frames together with ping and pong (A7; the largest payload tested is 2 MB)<br>• `MdnsService` (A11)<br>• the socket closing on `kill`<br>• a malformed scanned key (B21) |          |
| T6  | The plugin has no native tests, so nothing covers invitation policy, peer binding or send failures. On devices:<br>• two Macs or two iPhones in range<br>• the size at which an MPC send fails<br>• Mac sleep and wake<br>• a long or non-ASCII Mac name<br>• iOS multicast<br>• Windows firewall, tray and second instance<br>• App Nap<br>• the first sync of a library of several hundred MB |          |

## Known issues

Status of the items already tracked that the reviewers passed through:

| Item                                                                 | Status                                                                                                                                                                         |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Deletes don't sync (backlog §9)                                      | Still present: nothing sets `deleted_at`, repositories hard-delete, and the count mismatch triggers A6's full resend, which brings the row back                                |
| LWW offline queue cleared on every mobile start (backlog §9)         | Still present (`lib/main.dart:28-30`); A2–A4 lose queued changes even without a restart                                                                                        |
| TCP `stopServer` kills the isolate too early (backlog §9)            | Still present (`tcp_service.dart:803-806`; skipped test at `tcp_service_test.dart:1408`). The replaced client socket and server buffer fixes hold                               |
| A second phone gets no accept/reject dialog; `DesktopPage` is dead (backlog §9) | Still present. A9 shows the same phone reconnecting is parked as pending too                                                                                         |
| Handover result clears every pending session (backlog §9)            | Still present (`handover_sender_service.dart:188-197,212-221`)                                                                                                                 |
| Records audit A13, notes sync on `uuid`                              | Fix holds. With a v11 peer, its new note becomes `legacy-<id>` and can overwrite a different old `legacy-<id>`; documented as "both apps need v12"                              |
| Records audit A18, change watcher and queue size                     | The watcher and the queue without file bytes hold. "An offline sync moves the last sync time" is still open (part of A2 and B16)                                                 |
| Records audit B1, `INSERT OR REPLACE` on Fasten sync                 | Still present; it also clears `device_id`, which empties the tie-break (B2)                                                                                                    |
| Records audit B2, received attachments written again on every sync   | Still present (`lww_sync_service.dart:92-94` writes files before the LWW check). Amplified: `_updateAttachmentUrls` re-stamps the row, so the next delta sends it back with the file |
| Records audit B3, `fixBrokenAttachmentUrls` matches by part of a name | Still present (`lww_sync_service.dart:477-498`)                                                                                                                               |
| Records audit B4, `sources.updated_at` in seconds                    | Still present (`sync_local_data_source.dart:133,251,284,309`; pinned at `lww_sync_service_test.dart:823`)                                                                       |
| Records audit B10, Windows paths disagree                            | Still present. Restored attachments look missing on Windows, so they are requested after every verify, and `_localHasBrokenAttachment` lets an older phone copy overwrite a newer desktop edit |
| Records audit B16, sync events reload the Records list               | Still present (`records_page.dart:363-369`); Home has the same listener (`home_page.dart:91-99`)                                                                                |
