- source_spec: none
  summary: Fix the security items S1–S5 of the mobile stabilization backlog (signing keys in the app, biometric lock bypass, share debug log in release, plain-text share JSON left in temp, share encryption).
  evidence: Split from the mobile stabilization request on 2026-10-27; the user chose to fix missing translations first and treat security next.
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
  summary: Widen no_hardcoded_text_test to getters, text:/description:/subtitle: arguments and TextSpan, with an allowlist for keys.
  evidence: The current regex let statusDisplay 'Active'/'Inactive' through.
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
  evidence: syncErrorGeneric, scanFailedWithError, failedToImportDocument and PipelineStatus.failure append English technical detail.
- source_spec: `_bmad-output/implementation-artifacts/spec-translate-mobile-app.md`
  summary: Decide whether the translated privacy policy needs a clause naming the authoritative language version.
  evidence: Legal question for the product owner (maybe-false as a defect); the policy now exists in four languages.
