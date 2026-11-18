# Story 1.4: Communication — QR Pairing, Discovery & Encrypted TCP

Status: ready-for-dev

## Story

As a user,
I want to pair my phone with my desktop via QR code and have them find each other automatically,
so that I can transfer health data securely without internet or cloud.

## Acceptance Criteria

1. Desktop displays QR code with pairing info (device ID, IP, port, pairing key)
2. Mobile scans desktop QR → both devices confirm pairing within 30 seconds
3. Paired devices on same WiFi: discovery < 200ms (mDNS + SSDP parallel)
4. No shared WiFi: hotspot fallback connects within 8 seconds
5. Saved IP reconnection < 1 second
6. All TCP communication encrypted with AES-256-GCM
7. Auto-reconnect after connection loss, IP change, or app restart
8. Connection status indicator on both devices (connected / connecting / offline)

## Tasks / Subtasks

- [ ] Task 1: DevicePairing model + secure storage (AC: #1, #2)
  - [ ] Create `lib/features/backup/data/models/device_pairing.dart` — Freezed model with: deviceId, deviceName, pairingKey, lastIp, lastPort, lastSsid, lastPassword, pairedAt
  - [ ] Create `lib/features/backup/data/services/pairing_storage_service.dart` — save/load pairing to `flutter_secure_storage`
  - [ ] Generate UUID for deviceId, generate cryptographic random pairing key (32 bytes)

- [ ] Task 2: QR pairing flow (AC: #1, #2)
  - [ ] Add `qr_flutter` to `pubspec.yaml`
  - [ ] Desktop: generate pairing info (deviceId, local IP, port 49152, pairing key) and display QR code on Backup page
  - [ ] Mobile: add "Pair Desktop" button that opens `mobile_scanner` (already in app) to scan QR
  - [ ] Both: parse QR JSON, save DevicePairing to secure storage, confirm pairing on screen

- [ ] Task 3: SSDP service (~80 lines) (AC: #3)
  - [ ] Create `lib/features/backup/data/services/ssdp_service.dart`
  - [ ] Desktop: broadcast `NOTIFY` with URN `urn:healthwallet:device:desktop:1` via `dart:io` `RawDatagramSocket` (multicast 239.255.255.250:1900)
  - [ ] Mobile: send `M-SEARCH` for `urn:healthwallet:device:desktop:1`, parse response to get IP+port

- [ ] Task 4: mDNS service (AC: #3)
  - [ ] Add `bonsoir` to `pubspec.yaml`
  - [ ] Desktop: advertise `_healthwallet._tcp` service with port 49152
  - [ ] Mobile: browse for `_healthwallet._tcp` service, extract IP+port from discovered service

- [ ] Task 5: Discovery orchestrator (AC: #3, #4, #5)
  - [ ] Create `lib/features/backup/data/services/discovery_service.dart`
  - [ ] Run all discovery methods in parallel, first response wins:
    1. Try saved IP (TCP connect to lastIp:lastPort, verify pairingKey) — ~0ms
    2. mDNS + SSDP in parallel — ~200ms
    3. Hotspot fallback — ~3-5s
    4. Manual QR fallback (show "Desktop not found. Scan QR to reconnect.")
  - [ ] Return discovered IP+port on success, or null/error on all-fail

- [ ] Task 6: Encrypted TCP service (AC: #6, #7)
  - [ ] Add `pointycastle` to `pubspec.yaml`
  - [ ] Create `lib/features/backup/data/services/tcp_service.dart`
  - [ ] Desktop: TCP server on port 49152 via `dart:io` `ServerSocket`
  - [ ] Mobile: TCP client connects to discovered IP:port
  - [ ] AES-256-GCM encryption using pairingKey as key material (derive via HKDF or use directly)
  - [ ] Message framing: 4-byte length prefix + encrypted payload
  - [ ] Protocol messages: HELLO→ACK, PING→PONG, DATA→ACK, KILL→ACK
  - [ ] Connection monitoring: periodic PING, detect disconnect, auto-reconnect via discovery orchestrator

- [ ] Task 7: Hotspot fallback (AC: #4) — DEFER TO v1.1 if complex
  - [ ] Desktop hotspot creation via platform channels: macOS (`CWWiFiClient`), Windows (Mobile Hotspot API), Linux (`nmcli`)
  - [ ] iPhone joins hotspot: reuse `NEHotspotConfiguration` pattern from Airdrop iOS
  - [ ] Android creates `LocalOnlyHotspot`: reuse `HotspotManager.kt` pattern from Airdrop Android
  - [ ] SSDP on hotspot network → discover → TCP connect
  - [ ] NOTE: This is the most complex subtask. If platform channel work is excessive, defer to v1.1 and rely on same-WiFi discovery + manual QR fallback

- [ ] Task 8: Connection status + BackupBloc integration (AC: #8)
  - [ ] Extend `BackupBloc` with connection state events: ConnectionRequested, DeviceDiscovered, Connected, Disconnected, PairingCompleted
  - [ ] Extend `BackupState` with: connectionStatus (disconnected/discovering/connected), pairedDevice (DevicePairing?), error
  - [ ] Update `BackupPage` to show: QR code when unpaired, connection status when paired, "Pair Desktop" prompt on mobile
  - [ ] Mobile: show connection status in app bar or Backup-related UI area

- [ ] Task 9: macOS entitlements for networking (AC: prerequisite)
  - [ ] Add network client/server entitlements to `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`
  - [ ] Entitlements needed: `com.apple.security.network.client`, `com.apple.security.network.server`

## Dev Notes

### Architecture — Where Communication Code Lives

All communication code lives under `lib/features/backup/` since backup is the desktop-only feature that owns the device pairing relationship:

```
lib/features/backup/
├── data/
│   ├── models/
│   │   └── device_pairing.dart         (Freezed model)
│   └── services/
│       ├── pairing_storage_service.dart (flutter_secure_storage)
│       ├── ssdp_service.dart            (dart:io RawDatagramSocket, ~80 lines)
│       ├── mdns_service.dart            (bonsoir wrapper)
│       ├── discovery_service.dart       (orchestrator: saved IP → mDNS+SSDP → hotspot → QR)
│       ├── tcp_service.dart             (ServerSocket/Socket, AES-256-GCM, protocol)
│       └── hotspot_service.dart         (platform channels — defer if complex)
├── domain/
│   └── repositories/
│       └── backup_repository.dart       (abstract interface — later stories)
└── presentation/
    ├── bloc/
    │   ├── backup_bloc.dart             (extend with connection events/states)
    │   ├── backup_event.dart
    │   └── backup_state.dart
    └── pages/
        └── backup_page.dart             (QR display, connection status)
```

### Protocol Stack (from planning doc)

```
APPLICATION: Backup · Processing Handover · Sync
TRANSPORT: Encrypted TCP (AES-256-GCM, key from pairing)
DISCOVERY: Saved IP → mDNS + SSDP parallel → Hotspot → Manual QR
PAIRING: QR code (first time only) → secure storage (persisted)
```

### QR Code Payload Format

```json
{
  "device_id": "uuid",
  "ip": "192.168.1.100",
  "port": 49152,
  "pairing_key": "base64-encoded-32-bytes",
  "device_name": "MacBook Pro",
  "os": "macos"
}
```

### TCP Message Protocol

```
Frame: [4 bytes: payload length (big-endian)] [N bytes: AES-256-GCM encrypted payload]
Payload: [1 byte: message type] [N bytes: message data]

Message types:
  0x01 HELLO { device_id, pairing_key_hash }  →  0x02 ACK
  0x03 PING                                     →  0x04 PONG
  0x05 DATA { type, payload }                   →  0x02 ACK
  0xFF KILL                                     →  0x02 ACK
```

### Reusable Code from Airdrop Package

| Component | Airdrop source | Reusable pattern |
|-----------|---------------|------------------|
| iPhone joins WiFi by SSID | `NEHotspotConfiguration` | SSID from saved pairing instead of BLE |
| Android creates hotspot | `HotspotManager.kt` → `LocalOnlyHotspot` | Direct reuse |
| TCP send/receive | `SendManager.swift`, `HotspotTransferManager.kt` | Chunked transfer pattern |
| Kill signal | Int32 value -1 over TCP | Direct reuse |

### New Dependencies

| Package | Purpose | Version |
|---------|---------|---------|
| `qr_flutter` | QR code display on desktop | latest stable |
| `bonsoir` | mDNS advertise/browse (wraps native Bonjour/Avahi/NsdManager) | latest stable |
| `pointycastle` | AES-256-GCM encryption | latest stable |
| `flutter_secure_storage` | Already in pubspec — pairing key storage | existing |

### Previous Story Intelligence

- Story 1.1: macOS build validated, no crashes. Platform guards work.
- Story 1.2: `AppPlatform` enum in DI, `main_desktop.dart` entry point, BackupPage scaffold exists, Dashboard tabs swap Scan↔Backup on desktop.
- `BackupBloc` exists with minimal initial state — extend it, don't replace.
- `mobile_scanner` already in app (used for QR scanning in sync feature) — reuse for pairing.

### Critical Reminders

- Pre-commit hook rejects ALL comments
- All services should be registered via `@injectable` or `@lazySingleton` in DI
- Freezed models need code gen: `dart run build_runner build --delete-conflicting-outputs` (user handles)
- TCP server port 49152 is in the dynamic/private range — safe for local use
- Never hardcode IPs — always discover via mDNS/SSDP or use saved pairing

### References

- [Source: _bmad-output/planning-artifacts/prd.md — FR7-FR13, FR39-FR42, NFR1-NFR3, NFR9-NFR12]
- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.4]
- [Source: wp_3/docs/planning/desktop-flutter-implementation.md — Phase 2]
- [Source: wp_3/docs/planning/healthwallet-planning.md — Communication Protocol section]
- [YouTrack: HM-159]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
