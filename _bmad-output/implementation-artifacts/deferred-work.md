- source_spec: none
  summary: Fix the security items S1 and S5 of the mobile stabilization backlog (signing keys in the app, share encryption); S2–S4 were done in `spec-security-hardening.md`.
  evidence: Split from the mobile stabilization request on 2026-10-27; S1 needs a signing server and S5 needs changes in the `airdrop` package, so both stayed out of the security hardening work.
- source_spec: none
  summary: Raise mobile test coverage per section 6 of the stabilization backlog (BLoC tests for the main flows, critical areas, widget tests, a simulator integration test, per-area coverage ratchet).
  evidence: Split from the mobile stabilization request on 2026-10-27; each fix carries its own tests, while the broader coverage work is a separate deliverable.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Add widget tests for PatientEditDialog and PatientSetupDialog that save a localized gender and assert the FHIR code sent to PatientBloc.
  evidence: Only GenderMapper is tested; the dialogs have no test harness (they need PatientBloc, HomeBloc and PatientEditService).
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Stop both patient dialogs resetting the selected gender in didChangeDependencies.
  evidence: The reset exists at baseline 49fd6d53; any Theme or Localizations change while the dialog is open discards the user's choice.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Widen no_hardcoded_text_test further, to getters, switch arms returning text and TextSpan, with an allowlist for keys.
  evidence: The regex let statusDisplay 'Active'/'Inactive' through. The desktop extension added subtitle:, description:, content:, errorText:, helperText: and semantic labels; a trial of switch arms and returned sentences found only the GeneralResource 'Resource' fallback and the unused JwtService.getExpirationDescription.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Make arb_parity_test check plural categories per locale and flag translation-only keys; remove the stale counterAppBarTitle from app_es.arb.
  evidence: app_es.arb:3 still has counterAppBarTitle; the parity test checks keys and placeholders only.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Keep each AI model's size in one field used by both description and localizedDescription.
  evidence: The sizes are hardcoded twice in ai_model_config.dart and will drift.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Start the date picker's week on Monday for de, es and ro (MaterialLocalizations.firstDayOfWeekIndex).
  evidence: date_wide_dropdown.dart keeps the US Sunday-first layout from before the change.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Verify whether re-adding a Google Wallet pass updates the existing object (same id emergency_<patientId>_v2); if not, version the id by content or language.
  evidence: Unverified (maybe-false); would be medium if true. Settle it by saving a pass, changing the language or allergies, saving again, and checking the pass content.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Translate the displayTitle fallback (fhirType.display / 'Resource') for records without a title or code.
  evidence: Shown in English only for records lacking both; 41 call sites read displayTitle.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Make the l10n parameter required on the display paths of FhirTemporalExtractor and FhirPatientExtractor.
  evidence: An optional l10n falls back to English silently when a caller forgets it.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Replace raw exception text (e.toString()) in user-facing error messages with localized, user-friendly text.
  evidence: Done for the desktop LWW sync, backup and handover errors. Still open on mobile: syncErrorGeneric, scanFailedWithError, failedToImportDocument and PipelineStatus.failure append English technical detail. Mobile done on `bugfix/record-values-errors-and-deletes` (typed reasons, translated text, cause only logged).
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Decide whether the translated privacy policy needs a clause naming the authoritative language version.
  evidence: Legal question for the product owner (maybe-false as a defect); the policy now exists in four languages.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Detect translations that went stale when an English value changed, for example by storing the English source next to each translation and failing a test when it differs.
  evidence: desktopSyncAndBackup was renamed in English to "Data Sync & Backup" in 00b3afc6 while es, de and ro kept the old meaning; arb_parity_test checks only keys and placeholders.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Delete or translate JwtService.getExpirationDescription.
  evidence: It builds English sentences ("Expires in 3 days") and nothing calls it.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Translate the macOS tray tooltip and native menu items if the app ever localizes its native shell.
  evidence: The tray tooltip is the brand name only; the native macOS app menu follows the system language, not the in-app language.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Test CommunicationBloc and the HandoverPage and HandoverSendDialog widgets.
  evidence: scripts/coverage.sh --files lib/features/desktop/ shows communication_bloc.dart 0/250, handover_send_dialog.dart 0/137 and handover_page.dart 1/115 lines; their texts are tested through the display_names mappings. They read their blocs and services from getIt, so a widget test needs those registered.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Run integration_test/app_l10n_test.dart in CI on a macOS runner with a simulator created for the job.
  evidence: GitLab CI runs only unit and widget tests; the end-to-end test needs an iOS simulator and changes the app's language, so it cannot share a developer's simulator.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Check the desktop app by hand in ro and de (From Phone tab, tray menu, pairing, backup) before release.
  evidence: The desktop texts are covered by unit and widget tests and the macOS build succeeds, but no one has looked at the running desktop app in another language.
- source_spec: `_bmad-output/implementation-artifacts/spec-security-hardening.md`
  summary: Confine the proximity-share attachment resolver (`FhirBundleMapper._resolveFile`) to the documents directory, like `AttachmentSyncService.resolveFile`.
  evidence: `fhir_bundle_mapper.dart:82-115` still accepts absolute paths, `../` and the Caches/tmp fallbacks and inlines the bytes into the outgoing share; first check whether iOS attachments really live in Caches/tmp.
- source_spec: `_bmad-output/implementation-artifacts/spec-security-hardening.md`
  summary: Make desktop backup restore copy by shared column names so backups from an older schema version can be restored.
  evidence: `backup_service.dart` restore uses positional `INSERT INTO … SELECT *`; a different column count fails (now rolling back cleanly), a different order would put values in the wrong columns.
- source_spec: `_bmad-output/implementation-artifacts/spec-security-hardening.md`
  summary: Make the desktop Reset delete all health data: attachments in documents, `provider_downloads/`, the backups folder, and use `allTables` instead of a hand-kept table list.
  evidence: `AppDataResetService.reset` deletes four tables, prefs, known temp files and `share_sessions` only, as `_performReset` did before.
- source_spec: `_bmad-output/implementation-artifacts/spec-security-hardening.md`
  summary: Harden the deep-link document download: https-only or confirmation before importing, a size cap, and no overwrite of an earlier download with the same name.
  evidence: `deep_link_service.dart` `downloadFile` fetches any `file=` URL with `http.get` into memory and writes `provider_downloads/<name>` over an existing file.
- source_spec: `_bmad-output/implementation-artifacts/spec-security-hardening.md`
  summary: Cover native modals (iOS share sheet, PKAddPassesViewController) when the app lock engages on resume.
  evidence: The lock overlay lives in the Flutter view; a native sheet presented above it, e.g. an IPS PDF preview, stays visible after a resume past 30 s.
- source_spec: none
  summary: Host the Google Wallet pass logo on a domain we control (for example healthwallet.me) instead of raw.githubusercontent.com.
  evidence: The old link pointed at a deleted feature branch and returned 404; `GooglePassBuilder.logoUrl` now points at the GitHub `master` branch, which works but depends on a repository this project no longer updates. Google also recommends a 660×660 logo; the hosted one is 180×180.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Give record notes ids that are unique across devices (for example a UUID column used as the sync key), so a note created on the phone and one created on the desktop no longer share an id.
  evidence: `record_notes.id` is an autoincrement integer; LWW matches on it, so two notes with the same id overwrite each other and a note tombstone deletes the other device's note. Pinned as a skipped `BUG:` test in `delete_sync_round_trip_test.dart`. Changing the key changes the synced row shape, so both ends must ship together.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Delete the attachment files of tombstoned DocumentReferences (local bulk deletes, incoming tombstones, the 30-day purge) and sweep orphaned files.
  evidence: Only the single-attachment delete in `RecordAttachmentsBloc` removes its file. `deleteResourceWithRelated`, `deleteResourcesByIds`, `softDeleteSource`, `clearDemoData`, the re-processing replacement and incoming tombstones keep the files, and `cleanupTombstones` drops the rows after 30 days without touching them. Hard deletes left the same files behind before this change.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Fix the existing bugs pinned during this work. `DocumentReferenceService` ids collide within one millisecond. Attaching to a record without a subject writes `Patient/`. The out-of-memory scan message tells the user to raise the context size.
  evidence: Each is a skipped `BUG:` test (`document_reference_service_test.dart`, `record_attachments_bloc_test.dart`, `processing_failures_test.dart`); none was in scope.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Throw typed exceptions from the AI engine for "not enough memory" and "model corrupted" instead of matching their English text in `PipelineFailureReason.of`.
  evidence: `ai_inference_data_source.dart` throws plain `Exception`s with fixed English text; the UI is translated now but still depends on that text.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Write `updated_at` in milliseconds in `updateSourceLabel` and `cacheSources`, and stamp edits at millisecond precision so an edit made in the same second as a delete on the other device does not lose to the tombstone.
  evidence: Both write a drift `DateTime` (seconds), already pinned as a KNOWN ISSUE in `lww_sync_service_test.dart`; the triggers stamp whole seconds, documented in the delete contract in `architecture.md`.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Cover the last five changed lines no test can reach: `records_page.dart:595-597` (the share-permission-denied message) and the RAM-read fallbacks in `device_capability_service.dart:55`, `ai_inference_data_source.dart:147` and `ai_settings_dialog.dart:148`.
  evidence: The screens listed here before are now tested (99% of the branch's changed lines are covered). `SharePermissionsHelper` (in `share_records`, not ours to change) grants every request on macOS, Windows and Linux, which every test host is. The RAM fallbacks run only on iOS and Android, or after a failed `/proc/meminfo` read on Linux; both need the platform behind `AppPlatform` or an injectable reader.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: In a tests-only phase, cover the existing code of the files this branch touched. Its changed lines are 99.5% covered, but the touched files as a whole are at 71.8% (8,655 of 12,046 lines), and 25 of the 84 are below 70%. The lowest: `ai_inference_data_source` (0%), `ai_settings_dialog` (0%), `pdf_thumbnail_utils` (18%), `image_preview_page` (26%), `communication_bloc` (31%), `processing_page` (34%), `processing_handler` (36%), `attachment_detail_panel` (41%), `connection_dialog` (46%), `load_model_page` (49%).
  evidence: Measured on 2026-10-30 at 07bd6ca6 with `fvm flutter test --coverage`. Most of these are large screens and services where the branch changed one or two lines (a log, a message). The user chose to cover them in a separate phase that writes only tests.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Run the `checks` job's tests with a non-UTC `TZ` (for example `Europe/Bucharest`), so the local-time tests fail when the conversion to local time is removed.
  evidence: The record-time tests compute their expected text from the same instant in local time. In UTC that equals the recorded time, so CI cannot tell the conversion apart from no conversion; locally (EET) the tests do catch it. The full suite passes in EET.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Check that attachments land in the right documents directory on Windows. `RecordAttachmentsBloc` copies into the platform documents directory, while `PathResolver` uses `HealthWallet/Documents`, so the stored path may stay absolute. Also guard `image_preview_page`, where `lastModifiedSync()` runs after a failed `statSync`.
  evidence: Found while fixing attachments and empty catches; neither is reproduced on a device.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Ship the desktop build together with this mobile change, or note in the release that a desktop build without it keeps showing records deleted on the phone.
  evidence: A peer without the delete contract stores tombstones as ordinary rows and does not filter its reads; its own deletes stay hard and come back from the updated phone (`architecture.md`, LWW section, point 6).
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Stop a Fasten sync from re-inserting records and sources the user deleted (`cacheFhirResources` and `cacheSources` use `insertOrReplace`, which clears `deleted_at`).
  evidence: Review finding 14. Every Fasten sync downloads everything, so a deleted Fasten record comes back and then travels to the desktop; this happened with hard deletes before too, and Fasten work was out of scope.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Decide whether a user delete should strip the health content from the tombstone (`resource_raw`, note text) instead of keeping it for 30 days, in deltas and in desktop backups.
  evidence: Review finding 15. LWW needs only the id, `updated_at` and `deleted_at`. Stripping changes what a desktop build without the delete contract shows, because it does not filter tombstones, so it needs a product decision.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Show `Quantity.comparator` with the value (`< 0.5 mg/L`) in `extractQuantity` and `extractObservationValue`.
  evidence: Review finding 16. The comparator is dropped, so `< 0.5` shows as `0.50`; it was dropped before this branch too.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Check `getWalletApiAvailabilityStatus()` before saving a Google Wallet pass, and report a failure when Wallet is unavailable or the plugin has no activity.
  evidence: Review finding 17, unverified (if true, medium). Settle it by adding a pass on a device without Google Wallet and checking whether anything opens.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Stop `extractDosage` rounding doses to whole numbers (0.5 mg shows as "1 mg"); use the quantity decimals rule.
  evidence: Found while fixing the review findings; it existed before this branch and was not among the section 4 bugs. A wrong dose is a high-impact display error.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Save scanned observations with a UCUM `system` and `code` next to the unit read from the document (`MappingObservation.toFhirResource`), so other FHIR consumers (IPS export, the desktop, providers) can read the unit.
  evidence: Found on 2026-10-29 while fixing the region conversion. Scans store only the written unit; the app no longer converts them, so this affects interoperability, not what the app shows.
- source_spec: `_bmad-output/implementation-artifacts/spec-record-values-errors-and-deletes.md`
  summary: Decide whether the Home vitals card should show a scanned weight, height, temperature or glucose as on the document, like the records screens now do, instead of in the region unit.
  evidence: 2026-10-29: the records screens show scanned values as recorded; `patient_vitals_factory` still converts every source for the card, which is a summary in the region units. Product decision.
