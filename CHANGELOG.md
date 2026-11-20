# Changelog

All notable changes to HealthWallet.me are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Versions without a git tag are dated by their last version bump.

## [1.3.0] - 2026-11-21

The desktop release. HealthWallet.me now runs on **macOS, Windows and Linux** as the phone's trusted companion: a backup hub, a faster AI processor and a sync partner. Everything stays on your local network.

### Added

- **Desktop app** for macOS, Windows and Linux, built from the same codebase as the mobile app, with system tray support and minimize-to-tray.
- **Phone to desktop pairing** by QR code, with automatic discovery and an encrypted connection over Wi-Fi, USB tethering or a hotspot. VPN-aware, with automatic reconnect.
- **Backup and restore**: named local snapshots on the desktop, started from either device, with restore after phone loss.
- **Two-way sync** between phone and desktop, including attachments. The newest change wins.
- **Process on Desktop**: the phone hands documents to the desktop, which runs a larger AI model and sends the structured records back.
- **Specialty classification** for all record types, with specialty icons, home screen cards and multi-specialty filters.
- **Attachment browser** with a timeline scrubber, multi-page preview and multi-file attach.
- Windows OCR, the Microsoft Store package (MSIX) and a portable zip.
- Full localization in English, German, Spanish and Romanian.

### Changed

- The Backup screen is now **Data Sync & Backup**, with connection, backup and sync status cards.
- One QR scanner now handles both desktop pairing and FastenHealth sync.
- Deleting a source now asks you to type its name to confirm, and wallet sources can be deleted.
- The AI pipeline uses a structured output grammar and on-device OCR on macOS and Windows.
- **License:** from this version, HealthWallet.me is source-available under the [Business Source License 1.1](LICENSE.md). It is free for personal use; organizations need a commercial license. Earlier versions remain GPL-3.0.

### Fixed

- FastenHealth sync crash when clearing demo data ([#68](https://github.com/LifeValue/HealthWallet.me/issues/68)).
- Dark mode contrast for PDF pages and attachment previews.
- macOS App Store packaging (ITMS-90291).

## [1.2.1] - 2026-03-26

### Added

- ID card scanning with OCR, a country selector and country profiles.
- Smart patient matching: scanned documents are matched to an existing patient before AI processing.
- Deleting records cascades safely to the records that depend on them.
- Bluetooth state detection for proximity sharing.
- Per-patient wallet sources.
- Over-the-air patches for faster fixes.

### Fixed

- Android 16 KB page alignment for the on-device AI library.
- Date normalization for dates returned by the AI model.
- Several attach-to-encounter and patient editing issues.

## [1.2.0] - 2026-03-18

### Added

- **Share Records**: cross-platform proximity sharing between iOS and Android, view-only on the receiver, with screenshots blocked.
- Responsive tablet layout.
- AI model management: multiple models, parallel downloads and device capability checks.
- Emergency contact on Apple and Google Wallet passes.
- Region-aware units with locale auto-detection.
- Focus mode during document processing.
- LOINC mapping and value normalization for scanned lab results and vitals.

### Changed

- Processing extracts the patient and encounter first, then the rest of the document.
- Metal GPU acceleration on iOS.

### Fixed

- Processing no longer gets stuck, and data is preserved when you cancel.
- Memory checks and crash resilience on lower-RAM iPhones.

## [1.1.1] - 2025-12-12

### Fixed

- Stability fixes for the 1.1 release.

## [1.1.0] - 2025-12-02

### Added

- On-device AI document scanning with processing sessions.
- Attach scanned documents to an encounter.
- Import via the share sheet and deep links.

## [1.0.0] - 2025-09-02

First public release on the App Store and Google Play.

### Added

- Health record management with FastenHealth sync from US providers via FHIR R4, across multiple server URLs.
- International Patient Summary (IPS) export.
- Record notes, attachments and related resources.
- Vital signs on the home screen, with a reorderable home page.
- Light and dark themes.

[1.3.0]: https://github.com/LifeValue/HealthWallet.me/compare/1.2.1...v1.3.0
[1.2.1]: https://github.com/LifeValue/HealthWallet.me/compare/1.2.0...1.2.1
[1.2.0]: https://github.com/LifeValue/HealthWallet.me/compare/1.1.1...1.2.0
[1.1.1]: https://github.com/LifeValue/HealthWallet.me/releases/tag/1.1.1
[1.1.0]: https://github.com/LifeValue/HealthWallet.me/commits/1.1.1
[1.0.0]: https://github.com/LifeValue/HealthWallet.me/commits/1.1.1
