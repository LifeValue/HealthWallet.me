---
title: 'Translate every user-visible string in the mobile app and fit the tab bar in every language'
type: 'bugfix'
created: '2026-10-27'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: '49fd6d53a3d228c82a62319065681f814e4b2d19'
context:
  - '{project-root}/_bmad-output/planning-artifacts/mobile-stabilization.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** About 220 user-visible strings in the mobile app are hardcoded in English. They include "Show All", "Patient:", vital, specialty, category and record-type names, dialogs, SnackBars, BLoC status and error messages, notifications, settings, sync, share, the privacy policy and wallet-pass text. There are also about 257 distinct record-detail field labels and 240 country names. Seven ARB keys are untranslated in es/ro and eleven in de. In German, the dashboard tab label wraps and overflows the 60 px tab bar by 8 px.

**Approach:** Route every user-visible string through the four ARB files (en, es, de, ro), or through locale data for country names. Translate display names that double as stored keys only at display time. Fit tab labels on one line by shrinking them. Ship it as one change, guarded by tests written first.

**Decisions (2026-10-27):** Claude writes the de, es and ro texts, and a native speaker on the team reviews them in the MR. The MR description lists the medical terms and the privacy policy for focused review. The German dashboard tab becomes "Übersicht". A tab label that doesn't fit is scaled down onto one line (never cut, never two lines). All slices ship in one change.

## Boundaries & Constraints

**Always:** Every new key goes into all four ARB files, then run `fvm flutter gen-l10n`. `untranslated_messages.json` ends empty. Tests are written first and fail before the fix. English stays identical, so existing English UI and tests are unchanged. Desktop screens that share mobile code keep compiling and are translated as a side effect.

**Never:** Change values used as lookup or persistence keys: `PatientVitalType.title`, `MedicalSpecialty.displayName`, `HomeRecordsCategory.display`, the `'All'` source id, and stored FHIR data such as the default patient "Health Wallet Holder". Changing them breaks saved dashboard layouts and specialty matching. Don't translate units, brand names, language endonyms, national ID names, AI prompts or demo data. Don't touch the debug log sheets (`debug_log_sheet.dart`, `share_debug_log_sheet.dart`); security item S3 removes them from release builds. Don't use any l10n-based string as program logic.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Translated app | Locale ro, de or es | No English on any mobile screen except the exclusions | N/A |
| Saved layout | Vitals and category order saved in English before the change | Same order, localized labels | Unknown saved key is ignored, as today |
| Unmapped vital | Observation title outside `PatientVitalType` | Raw title shown | No crash |
| Long tab label | de locale, 390 px wide, text scale 1.0 and 1.3 | One line, no overflow | N/A |
| Unsupported locale | Device locale fr | English, as today | N/A |
| BLoC message | Share, sync or model-download status in ro | Romanian text | N/A |

</frozen-after-approval>

## Code Map

- `lib/core/l10n/arb/app_{en,es,de,ro}.arb`, `l10n.yaml` -- reuse existing keys (`cancel`, `ok`, `patient`, `records`, `attachments`, `specialty`, `organization`, `practitioner`, `allergiesLabel`, `shareAccept`, `shareDecline`). `ios/untranslated_messages.json` is a stale copy; delete it.
- Precedent for l10n outside widgets: `mapping_*.dart` `localizedLabels(AppLocalizations l10n)`, `gender_mapper.dart:7` and `patient_edit_service.dart:511` take an `AppLocalizations` parameter. Follow it.
- Display names that are also keys: `home/domain/entities/patient_vitals.dart:22` (also duplicated in `fhir_observation_extractor.dart:293-317` and `home_data_handler.dart:302`), `medical_specialty.dart`, `overview_card.dart`, `records/domain/entity/i_fhir_resource.dart:107` `FhirType.display` (fix "MedicationStatement" → "Medication Statement" in the localized names only).
- Record-detail labels: `List<RecordInfoLine> get additionalInfo` and `additionalInfoForRegion` on all 28 entities in `records/domain/entity/`, plus `createSectionHeader`. Read at `record_detail_page.dart:85,88,352`, `records_page.dart:1015,1100`, `resource_info_content.dart:37`, `recent_records_section.dart:36` and `share_records/.../record_selection_view.dart:84` / `ephemeral_viewer_view.dart:249` (search text). Domain formatters: `fhir_patient_extractor.dart:122,143,217,318`, `fhir_temporal_extractor.dart:15-66`, `blood_observation_utils.dart:25,92`, `date_format_utils.dart:49-55`, `date_filter.dart:89-168`, month abbreviations in `date_range_filter_model.dart:62`, `records_filter_bottom_sheet.dart:653` and `date_filter.dart:128`.
- Strings used as logic today: `validator.dart:3`, compared at `resources_form.dart:325`; "Model file not found", matched at `processing_mapping_section.dart:100,117`. Replace them with typed checks.
- BLoC, service and notification messages: `load_model_bloc.dart:157,243,345,371,383,420,434`, `processing_handler.dart:95,165,222,412`, `session_handler.dart:89,114,299`, `dashboard_page.dart:70,79`, `sync_bloc.dart:142,163-172`, `onboarding_bloc.dart:71`, `record_attachments_bloc.dart:222`, `receive_mode_manager.dart:208,277,284,313,359,390`, `share_records_bloc.dart`, `share_records_session_handler.dart`, `share_records_transfer_handler.dart` (about 50 status strings), `ProcessingOrigin`/`ProcessingStatus.toString()` (`processing_session.dart:148-201`), `biometric_auth_service.dart:38`.
- Widgets: home (`vitals_section`, `home_overview_toggle`, `home_patient_bar`, `home_greeting_title`, `home_dialog_controller`, `specialty_picker`, `section_info_modal`, `source_list_dialog`, `source_selector_widget`), core dialogs (`delete_confirmation_dialog`, `app_dialog`, `app_simple_dialog:297`, `record_filter_header:258`, `overlay_controllers:128`, `pdf_preview_service`), records (`records_view_toggle`, `attachment_browse_view`, `attachment_detail_panel`, `resource_card`), processing and capture (`processing_mapping_section:86`, `processing_resources_section:291`, `resources_form:164,244`, `preview_card`, `summary_card`, `patient_selector`, `create_encounter_dialog:61`, `ai_settings_vision_toggle`, `document_handler:86,146`, `image_preview_page`, `onboarding_navigation:368`), user (`storage_section`, `ai_model_section:277`, `sync_section`, `share_proximity_row`, `biometric_toggle_button`, `receive_mode_toggle_button`, `settings_section:149`, `user_section:84`, `id_card_scan_mixin`, `form_fields:88`, `unified_patient_card:45`, `privacy_policy_page.dart:73-342`), sync (`qr_scanner_widget`, `sync_page`, `sync_placeholder_widget`), share (`share_permissions_helper.dart:115-149`), misc getters (`peer_device.dart:39`, `source_type_service.dart:31,75`, `source_mapper.dart:50`, `region_preset.dart`, `ai_model_config.dart:64-159`, `gender_mapper.dart:22`).
- Wallet pass: `ApplePassLabels` is already built from l10n in `share_options_sheet.dart:113`; mirror that for `google_pass_builder.dart:59-108` and `apple_pass_builder.dart:61`.
- Tab bar: `dashboard_page.dart:594` `_buildNavItem`; its `Text` at :618 has no line limit.
- Country names: `country_names.dart` (`Map<IsoCode, String>`), used by `phone_input_field.dart:39`.

## Tasks & Acceptance

**Execution:**
- [x] `test/core/l10n/arb_parity_test.dart` -- every key in `app_en.arb` exists in es, de and ro with the same placeholders. Fails today.
- [x] `test/core/l10n/display_names_test.dart` -- every vital, specialty, category, `FhirType`, origin and status value has a non-empty localized name in each locale, and the de and ro names differ from the English key where the words differ.
- [x] `test/features/dashboard/presentation/dashboard_nav_item_test.dart` -- four de items in a 390×60 bar at text scale 1.0 and 1.3 cause no overflow. Reproduces the 8 px overflow.
- [x] `test/features/records/domain/entity/additional_info_l10n_test.dart` -- a Condition and an Observation render ro labels.
- [x] `test/core/l10n/no_hardcoded_text_test.dart` -- scans mobile `lib/` (excluding desktop, debug sheets and generated files) for `Text('`/`Text("` with a letter literal, and for `label:`, `title:`, `message:`, `hintText:` with a literal. An allowlist covers units and brands.
- [x] `lib/core/l10n/display_names.dart` -- `localizedName(AppLocalizations)` extensions for the key enums, plus a raw-vital-title helper with fallback.
- [x] `lib/core/l10n/app_strings_provider.dart` -- injectable singleton holding the current `AppLocalizations`, updated by `app.dart` from the active locale. BLoCs, services and notifications get it through the constructor.
- [x] `records/domain/entity/**` -- change `additionalInfo` and `additionalInfoForRegion` to take `AppLocalizations`, and update the call sites.
- [x] `lib/features/dashboard/presentation/widgets/dashboard_nav_item.dart` -- extract the nav item, with `FittedBox(fit: BoxFit.scaleDown)` and `maxLines: 1`.
- [x] Code Map files -- replace the literals; make the two string comparisons typed.
- [x] `country_names.dart` -- per-locale maps for en, es, de and ro, generated from CLDR territory names by a script in `tool/`. Look them up by the app locale.
- [x] ARB files -- add the keys, fill the missing ones, set `dashboardTitle` in de to "Übersicht", run `fvm flutter gen-l10n`, delete `ios/untranslated_messages.json`.
- [x] Units -- `localizedUnit` with tests in `display_names_test.dart` and `fhir_observation_extractor_test.dart`.
- [x] Region units -- title normalization and inch conversion, `test/features/home/domain/factory/patient_vitals_factory_test.dart` with the demo vitals in Europe and the US.
- [x] Desktop -- replace the literals in `lib/features/desktop/`, type the handover failures, add the wire codes; tests in `test/features/desktop/` (backup error codes, tray menu, connection chip, handover failures on both sides) and `test/core/l10n/app_strings_provider_test.dart`.
- [x] `no_hardcoded_text_test.dart` -- scan the whole `lib/` including desktop, and also `subtitle:`, `description:`, `content:`, `errorText:`, `helperText:` and semantic labels.
- [x] `integration_test/app_l10n_test.dart` -- boots the app in German, checks the tab bar and that nothing overflows, switches to Romanian and checks that °C is shown and no English or imperial vital unit with the Europe region.
- [x] Handover status texts -- moved from the two screens to `HandoverStatusL10n.localizedLabel` and `phoneHandoverStatusText` in `display_names.dart`, with tests, since both screens take their blocs and services from `getIt`.

**Acceptance Criteria:**
- Given the ro, de or es locale, when each mobile tab, its dialogs and settings are opened, then no English text appears outside the exclusions.
- Given `fvm flutter gen-l10n`, when it runs, then `untranslated_messages.json` is `{}`.
- Given an existing install with a saved dashboard order, when the app updates, then the order and visibility are unchanged.
- Given the Europe region, when the dashboard shows weight, height and temperature recorded in pounds, inches and °F, then they show in kg, cm and °C.
- Given the ro, de or es locale on the desktop, when the From Phone tab, the tray menu, pairing and backup are used, then no English text appears outside the brand name.

## Implementation Notes

- Split across six agents by area (home/core foundation, records domain, records UI, processing, user/sync/wallet, share). Each worked in its own worktree from `8120255f`, wrote its keys to a fragment, and was cherry-picked; ARB conflicts were resolved by re-applying the fragments and regenerating.
- Three ways to reach strings: widgets use `context.l10n`; domain code takes `AppLocalizations` (`additionalInfo(l10n)`, extractors with an optional `l10n`); BLoCs and services use the injected `AppStringsProvider`, updated in `MaterialApp.builder`, which also sets `Intl.defaultLocale`.
- String logic made typed: `PipelineFailureReason.modelNotFound` / `ModelNotFoundException` (its `toString()` keeps "Model file not found" for the desktop handover), `FieldValidationError`, `DateField` in the date picker, `ShareSessionEndReason` for the declined screen, and gender saved as a FHIR code.
- Bugs found and fixed on the way: gender saved as `unknown` in es/de/ro; the year and day pickers chosen by English label; the declined-share screen chosen by searching the status text; the MedicationRequest refills line never shown; the sync success message typo.
- Kept in English as stored or wire data: the default patient and source names, the FHIR titles stored by attachments and received shares, `HealthWallet Device` sent to peers, and the desktop's model-not-found error text.
- Units (added after the simulator review, see the change log): `localizedUnit` in `display_names.dart` translates units that FHIR data spells out in English (`beats/min`, `breaths/min`, `pounds`, `inches`, `kilograms`, `centimeters`) at display time, on the vital cards and in record details. Symbols (mmHg, %, kg, °C, mg/dL, kg/m²) and `BPM` stay as they are, so English is unchanged.
- Region units (bug found during the simulator review): `PatientVital.fromObservation` looked up the vital type by the raw FHIR title, so "Body Weight", "Body Height" and "Body Temperature" were never converted and Europe showed 200 pounds, 70 inches and 98.6 °F. The title is now normalized first (`PatientVitalTypeX.normalizeTitle`, moved from the factory). Inches were treated as "ft/in" and never converted; they are now their own unit (`UnitConverter.heightInCm`), converted to cm for Europe and to feet and inches for the US, on the dashboard and in record details. A height stored as "centimeters" now shows the region's "cm".
- Desktop (scope extension, see the change log): about 40 strings in `lib/features/desktop/` and the tray menu. Part of that folder runs on the phone (the Data Sync & Backup section, pairing, the backup card, sending to the desktop), so the phone still showed English there and the guard test, which excluded the folder, could not see it.
  - Widgets use `context.l10n`; `BackupBloc` and `TrayService` take `AppStringsProvider` by constructor; `CommunicationBloc` (built by hand in both `main` files) reads it through `getIt`.
  - `AppStringsProvider` is now a `ChangeNotifier` that notifies only when the language changes, so the tray menu, which stays on screen, rebuilds in the new language.
  - Errors are no longer shown raw. LWW sync and backup failures show a localized message and log the exception. Handover failures are typed (`HandoverFailure`: notAccepted, fileNotFound, cancelled, modelNotFound, failed) and `HandoverSession.error` stays as technical detail.
  - Wire changes are additive, so old peers keep working: `backup.error` carries `code: no_backup_location` next to the English `error` (a phone treats a missing code as that case), and a `handover.progress` error carries `reason: model_not_found` (a phone still recognizes the old text through `ModelNotFoundException.message`).
  - `desktopSyncAndBackup` had been renamed in English to "Data Sync & Backup" while es, de and ro kept the old meaning or English text; all three are updated.
- End-to-end test: `integration_test/app_l10n_test.dart` boots the real app, loads the demo data when there are no records, checks German and then Romanian, and fails on any Flutter error, an overflow included. `bootstrap()` silences Flutter errors, so the test puts the test binding's handler back before the first frame. It must run on a simulator kept for tests: restoring the user's language afterwards does not work, because iOS loses preference writes made just before the runner closes the app (verified: the restored value read back in the test but was gone on the next launch). It catches regressions: with the region fix undone it fails on the missing °C.
- Bug found by the end-to-end test on a fresh install: `App._startSymmetricDiscovery` called `getCurrentUser()`, which throws before onboarding creates the user, on start and on every resume, leaving an unhandled exception. It now logs and returns. Fixed in a separate commit.
- `ios/Podfile.lock` and `macos/Podfile.lock` are not committed: a local `pod install` with CocoaPods 1.17.0 rewrites only the CocoaPods version and the Podfile checksum, while the repo is on 1.16.2.

## Spec Change Log

- 2026-10-27, after the simulator review, requested by the user: translate units that the data spells out in English ("beats, breaths are not translated to romanian"). This reverses the frozen "Don't translate units" for spelled-out words; symbols stay untranslated.
- 2026-10-27, found by the user: the Europe region (°C, cm, kg) was not applied to weight, height and temperature. Fixed in the same branch as a separate commit; not a translation change.
- 2026-10-27, requested by the user ("check thing on desktop to not have hardcoded text"): extend the change to `lib/features/desktop/` and the tray menu, and the guard test to the whole `lib/`. This reverses the frozen Boundaries line that left desktop screens to be translated only as a side effect. Review row 35 (desktop errors shown in its own language) is superseded: those errors are now typed and localized on the phone.
- 2026-10-27: added an end-to-end test (`integration_test/app_l10n_test.dart`) that boots the app on a simulator in German and Romanian.

## Review Triage Log

| # | Source | Finding | Verdict | Evidence | Route |
|---|--------|---------|---------|----------|-------|
| 1 | blind, edge | Fixed US date patterns print translated months in US order with AM/PM | medium | `fhir_temporal_extractor.dart:55-73,222-272` and `session_list.dart:97` use `'MMM d, yyyy h:mm a'` while `Intl.defaultLocale` follows the app | patch |
| 2 | edge | Entities format dates with the default locale, not `l10n` | low | `DateFormat.yMMMMd()` in `additionalInfo(l10n)` ignores `l10n.localeName`; this only differs before the first App build or in tests | patch (grouped with 1) |
| 3 | edge | Tab bar overflows vertically at text scale ≥1.5 | medium | `FittedBox` wraps only the label; the icon+label column is unbounded in the 52 px height | patch |
| 4 | edge | Localized "unknown patient" stored in the synced source name | medium | `document_handler.dart:89,149` passes `l10n.unknownPatient` into `getWritableSourceForPatient`; the baseline stored English | patch |
| 5 | edge | "Passport" shown in English in the review form | low | `mapping_patient.dart:86` builds the label without `l10n`, and `:208` translates only the generic label | patch |
| 6 | blind, edge | Patient extractor fallbacks 'N/A', 'Unknown', 'ID' stay English | low | `fhir_patient_extractor.dart:109,113,126` ignore `l10n` | patch |
| 7 | blind | `statusDisplay` 'Active'/'Inactive' shown in English | medium | Shown on the dashboard (`recent_records_section.dart:137`) and in the media viewer; the getter also feeds search | patch (translate at display) |
| 8 | blind | Plural gaps: `pagesAvailableForProcessing`, en `ageYears` "1 years", en "{type} delete" | low | ARB values confirmed: ro "25 pagini" should be "25 de pagini" | patch |
| 9 | edge | Country search doesn't fold diacritics | low | `country_picker_dialog.dart:42-52`: sorting folds diacritics, `contains()` doesn't | patch |
| 10 | edge | Unbalanced `**` bolds the rest of the sentence | low | `bold_markup.dart:6-13` splits on `**` without a parity check | patch |
| 11 | verification-gap | No test runs the bloc for the model-not-found reason | medium | Filed evidence: only `PipelineFailureReason.of()` and a hand-built state are tested | patch (test) |
| 12 | verification-gap, blind | Nothing tests that App applies the locale to `AppStringsProvider` and `Intl.defaultLocale` | medium | Filed evidence: the App smoke test only finds `MaterialApp` | patch (test) |
| 13 | verification-gap | `ModelNotFoundException.toString()` cross-device contract not pinned | medium | Filed evidence: no test asserts the text the desktop handover dialog matches | patch (test) |
| 14 | verification-gap | `SessionEndedView` declined branch never rendered | low | Filed evidence: the bloc emits the reason, but no widget test exists | patch (test) |
| 15 | verification-gap | Patient dialogs' gender-code save not tested at the call site | medium | Filed evidence: only `GenderMapper` is tested; the dialogs have no harness | defer |
| 16 | edge | Gender selection resets in `didChangeDependencies` | low | The same reset exists at baseline `49fd6d53` in both dialogs; pre-existing | defer |
| 17 | blind | Gender saved by comparing translated labels | false | On a language change `didChangeDependencies` re-maps the label, so the comparison always uses the current `l10n`; the stated "saves unknown" outcome does not happen | reject |
| 18 | blind | Guard test misses getters, `text:`, `TextSpan` and similar | low | The regex is narrow and let item 7 through; a wider pattern needs an allowlist design | defer |
| 19 | blind | Parity test skips plural categories and translation-only keys; stale `counterAppBarTitle` in es | low | `app_es.arb:3` confirmed; pre-existing | defer |
| 20 | blind | AI model sizes duplicated between `description` and `localizedDescription` | low | Two sources will drift when a model changes size | defer |
| 21 | blind | Day picker starts the week on Sunday in de/es/ro | low | US layout at baseline; pre-existing | defer |
| 22 | blind, edge | Google pass object id unchanged, so a re-added pass may keep its old language | maybe-false (medium if true) | Whether a save JWT updates an existing object is unverified; content staleness predates this change | defer |
| 23 | blind | `displayTitle` falls back to the English type name | low | Only when a record has neither title nor code; 41 call sites | defer |
| 24 | blind | Optional `l10n` on extractors falls back to English silently | low | A design choice that keeps English tests stable; callers can forget it | defer |
| 25 | blind | Raw exception text inside translated messages | low | `e.toString()` appended in a few errors; English technical detail predates this change | defer |
| 26 | blind | No governing-language clause in the translated privacy policy | maybe-false | Legal decision for the product owner, not a code defect | defer |
| 27 | blind | Global `Intl.defaultLocale` set inside `build` | false | Idempotent per rebuild and set before children build; desktop backup names are display-only | reject |
| 28 | blind | "Lite"/"Ultra" not translated | false | Tier names, as intended | reject |
| 29 | blind | Strings concatenated from pieces | low | "Patient: X", "Type (n)" and the privacy intro read correctly in all four languages | reject |
| 30 | blind | Sorting with `compareTo` and an incomplete fold table | low | Rare letters; the fix needs a collation helper | reject |
| 31 | blind | `FittedBox` undoes larger text; nav test copies the layout | low | Shrinking was the user's decision (2026-10-27); test fidelity is cosmetic | reject |
| 32 | blind | Translation wording (ro ON/OFF, de "Aufzeichnungen") | low | Covered by the planned native-speaker review | reject |
| 33 | blind | `app_es.arb` re-encoding mixed into the commit | low | The history is already committed; noted for the reviewer | reject |
| 34 | blind | `_originName` reuses `fhirTypeDocumentReference`; deviceName null vs fallback | low | Both render correctly | reject |
| 35 | verification-gap | Desktop sends errors in its own language to the phone | low | Other errors are shown verbatim; model-not-found stays English | reject |
| 36 | blind | Emergency pass readers may not speak the patient's language | false | The intent includes wallet-pass text; product note raised with the user | reject |

## Design Notes

There are three ways to reach a string. Widgets use `context.l10n`. Domain formatters take an `AppLocalizations` parameter, following the existing precedent. BLoCs and services use the injected `AppStringsProvider`, because about 80 status messages make typed states plus UI mapping too large a refactor for flows that are barely tested. A status message keeps the language that was active when it was emitted.

```dart
extension MedicalSpecialtyL10n on MedicalSpecialty {
  String localizedName(AppLocalizations l10n) => switch (this) {
    MedicalSpecialty.cardiology => l10n.specialtyCardiology,
    // ...
  };
}
```

## Verification

**Commands:**
- `fvm flutter gen-l10n && cat untranslated_messages.json` -- expected: `{}`
- `scripts/check.sh` -- expected: format, analyze and tests pass, with no infos
- `fvm flutter analyze lib/main_desktop.dart` -- expected: the desktop still compiles
- `fvm flutter test integration_test/app_l10n_test.dart -d <test simulator id>` -- expected: passes on a fresh install and on one with data; use a simulator kept for tests, since the run changes the app's language
- `fvm flutter build ios --simulator`, `fvm flutter build apk --debug`, `fvm flutter build macos --debug -t lib/main_desktop.dart` -- expected: all build

**Manual checks:**
- On the iOS simulator, in ro, de and es, walk the dashboard, Records, a record detail, Scan, Import, Settings, Sync and Share. Check that there is no English and that the tab bar doesn't overflow.
- On the macOS desktop app, in ro and de, open the From Phone tab and the tray menu, then change the language and reopen the tray menu.
