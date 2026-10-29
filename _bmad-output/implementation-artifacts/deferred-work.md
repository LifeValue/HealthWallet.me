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
  evidence: Done for the desktop LWW sync, backup and handover errors. Still open on mobile: syncErrorGeneric, scanFailedWithError, failedToImportDocument and PipelineStatus.failure append English technical detail.
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
