---
title: 'Profile saves without delay, failed name saves shown, gender kept in patient dialogs'
type: 'bugfix'
created: '2026-11-03'
status: 'done'
route: 'dispatch'
review_loop_iteration: 0
baseline_commit: 'b079f4f5b097bbb7b2d2b679f00894e7e5b65b6c'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:**
- Every profile change waits one second for nothing: theme, name and Share Proximity all go through `MockUserRemoteDataSource`, which only sleeps.
- A failed name save still shows the new name, and the error escapes the BLoC.
- The Preferences snackbar fires for any user failure, says "Failed to update display name", appends the raw exception, and renders under the modal's blur.
- Both patient dialogs reset the chosen gender when the theme or language changes.

**Approach:**
- Drop the mock so saves are local and immediate.
- Save the name before showing it, and keep the old name on failure.
- Mark every success and failure with the setting it belongs to, so the screen shows a translated message naming that setting, inside the modal.
- Keep the gender as a normalized FHIR code in dialog state and turn it into a label only in `build`.

## Boundaries & Constraints

**Always:**
- Write a failing test first, and un-skip the `BUG:` test in `user_bloc_test.dart`.
- Use fake repositories, not mocks.
- Use `context.l10n`, `AppSnackBar` and the theme tokens.
- Add new strings to all four ARBs and run `fvm flutter gen-l10n`.
- Run `fvm dart run build_runner build` after changing `UserStatus` or the DI registrations.
- Log every user-save failure with `logger`.
- A save handler applies its one field to the current `state.user` right before writing, and emits `state.copyWith(user: state.user.copyWith(<field>))` after the write. It never writes back a copy of `state.user` taken before an `await`, so concurrent theme and name saves keep each other's change.
- The biometric handler keeps `droppable()`. Theme, name and receive mode get `sequential()`.

**Never:**
- Change the `User` entity, its storage format, or what syncs to the desktop.
- Change the FHIR gender codes written to patients.
- Change `PatientEditService`; map the code to a label at the call site instead.
- Edit the `sourceId:` lines of the `PatientEditSaved` and setup-save calls (setup `:223`, edit `:437`), which `feature/holders-and-sources` removes.
- Change the records page's receive-mode toggle (`records_page.dart:554`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Theme toggle | User taps theme switch | Theme changes; repository has no fixed delay | N/A |
| Name saved | ✓ with "Maria" | loading → success(name) with "Maria"; field closes | N/A |
| Name save fails | Local save throws | Old name kept; failure(name) | Logged; snackbar "Failed to update display name"; field stays in edit mode with "Maria" so ✓ retries |
| Theme save fails | Save throws | Old theme kept | Logged; snackbar "Couldn't save “Theme”. Try again." |
| Share Proximity fails | Save or `startListening` throws | State keeps old value | Logged; snackbar names Share Proximity |
| Biometric | Auth throws | Old value kept | Logged; snackbar names Biometric Authentication. A declined or cancelled prompt shows nothing (success, value unchanged) |
| Snackbar placement | Preferences modal open, phone or desktop | Snackbar visible inside the modal, above the blur | N/A |
| Theme and name at once | Toggle theme while the name saves | Both the new theme and the new name end up in state and storage | N/A |
| Setup dialog | Gender picked or filled by ID scan, then theme or language changes | Same gender stays, label in the new language | N/A |
| Edit dialog | Gender edited, then theme or language changes | Edited gender stays | N/A |
| Stored or scanned `other`/`unknown`/null | Dialog opens | Shown as "Prefer not to say"; saving writes `unknown` exactly as today | N/A |

**Decisions (2026-11-03):**
- Failures name the setting, using its existing label (`theme`, `shareProximityTitle`, `biometricAuthentication`), in a new key `failedToSaveSetting` that quotes the label:
  - en: "Couldn't save “{setting}”. Try again."
  - de: "„{setting}“ konnte nicht gespeichert werden. Versuche es erneut."
  - es: "No se pudo guardar «{setting}». Inténtalo de nuevo."
  - ro: "Nu s-a putut salva setarea „{setting}”. Încearcă din nou."
- The name keeps `failedToUpdateDisplayName`. Exception text only goes to `logger`.
- A failed name save leaves the field in edit mode with the typed text. A successful save closes it.
- The mock remote data source is removed, along with `deleteUser`, `updateProfilePicture`, `verifyEmail` and `fetchFromNetwork`, which had no callers.
- Snackbars from the Preferences modal show inside the modal, on mobile and desktop.

</frozen-after-approval>

## Code Map

- DI and repository:
  - `lib/features/user/data/data_source/remote/user_remote_data_source.dart` -- the mock. Delete it.
  - `lib/core/di/register_module.dart:22-23` -- the mock's registration. Remove it. The generated `injection.config.dart` updates through build_runner.
  - `lib/features/user/data/repository/user_repository_impl.dart`, `lib/features/user/domain/repository/user_repository.dart` -- drop the remote parameter and the remote-only methods. `updateUser` saves locally only.
- `lib/features/user/presentation/bloc/user_bloc.dart`:
  - `:30-41` registrations.
  - `:51-53,99-101` `_getCurrentUser(fetchFromNetwork)`. Drop the parameter.
  - `:146-161` theme.
  - `:164-232` biometric.
  - `:234-244` name: emits before saving, no try/catch.
  - `:260-290` receive mode: saves at `:269` before `startListening` at `:274`.
  - No `logger` import yet.
- `lib/features/user/presentation/bloc/user_state.dart:17-22`:
  - The cases are private (`_Failure`), so match with `whenOrNull`/`maybeWhen`.
  - Add a `UserSetting` enum (name, theme, receiveMode, biometric). Make it `failure(Object exception, UserSetting setting)`, and add an optional `UserSetting? setting` to `success`, set only by the name handler.
- `lib/features/user/presentation/preferences_modal/preference_modal.dart`:
  - `:28-47` shows the modal in a `BackdropFilter`.
  - `:53` `build` returns a `Dialog`.
  - `AppSnackBar.show` uses `ScaffoldMessenger.maybeOf(context)` (`lib/core/widgets/app_snack_bar.dart:26-42`).
  - Wrap the dialog child in its own `ScaffoldMessenger` and a transparent `Scaffold`, and put the `failedToSaveSetting` listener here. Desktop opens the same modal (`home_greeting_title.dart:197`).
- `lib/features/user/presentation/preferences_modal/sections/user/user_section.dart`:
  - `:59-73` is the failure listener. Replace it with a name-only listener: `success(setting: name)` closes the field; `failure(_, name)` shows `failedToUpdateDisplayName` and stays in edit mode.
  - `:39-50` `_saveName` stops leaving edit mode before the result.
- Patient dialogs:
  - `lib/core/widgets/patient_setup_dialog.dart` -- `_selectedGender` at `:71-72,118-120,153-156,201,227,319-337`. `genderChanged` at `:201` becomes `code != 'unknown'`.
  - `lib/features/user/presentation/preferences_modal/sections/patient/patient_edit_dialog.dart` -- `:83-84,142-145,180-188,237,333,383-445,546-569`. At `:333`, pass `GenderMapper.mapFhirGenderToDisplay(code, l10n)` to `PatientEditService.hasPatientChanges(newGender:)` (`patient_edit_service.dart:505-526`), which compares labels.
  - `lib/features/user/domain/utils/gender_mapper.dart` -- reuse it. Normalize every incoming code to `male`, `female` or `unknown`.
- Tests that will break and must change:
  - `test/features/user/presentation/bloc/user_bloc_test.dart`:
    - `:27` the fake `getCurrentUser`
    - `:88-92` `_isFailure` (`maybeWhen` with one argument)
    - `:463-471` the name test now expects `[loading, success(name)]`
    - `:490-508` the `BUG:` skip
  - `test/features/user/presentation/preferences_modal/sections/user/user_section_test.dart`:
    - `:75-86` the field closing right away
    - `:101-119` `failure('disk full')` and the exception text
  - `test/widget_test.dart:58`, `test/features/app_lock/app_lock_test_fakes.dart:67` -- the fakes.
- Dialog widget tests use `MockBloc` for `PatientBloc` and `HomeBloc` (as `test/features/user/presentation/preferences_modal/preference_modal_test.dart:46` does), a `Fake implements PatientEditService` registered in `getIt`, and `SharedPreferences.setMockInitialValues`. Don't build them on the services `test/widget_test.dart` wires up: holders changes those constructors and deletes some of the services.
- The `gender:` arguments at setup `:227-230` and edit `:443-447` are 3–5 lines from holders' deleted `sourceId:` lines. Change only the expression.

## Tasks & Acceptance

**Execution:**
- [x] `test/features/user/data/repository/user_repository_impl_test.dart` (new) -- With a fake `UserLocalDataSource` and mock prefs, `updateUser` completes within `fakeAsync` without time passing and saves the user. This test fails today.
- [x] Remove the remote source: the data source, `register_module.dart`, the repository and its interface, the three test fakes. Then run build_runner.
- [x] `test/features/user/presentation/bloc/user_bloc_test.dart`:
  - Un-skip `:490-508`. Update `_isFailure` and `:463-471`.
  - Add tests: name success; theme, receive-mode and biometric failures carry their `UserSetting`; a decline emits no failure; concurrent theme and name keep both values.
- [x] `user_state.dart`, `user_bloc.dart`:
  - Add `UserSetting`, the failure and success shapes, and the per-field read-modify-write rule.
  - Add the `logger` calls and the transformers.
  - Run build_runner.
- [x] ARBs, then `fvm flutter gen-l10n` -- Add `failedToSaveSetting` right after `failedToUpdateDisplayName` (en `:65`; in the other files next to the same key, never at the end, where holders appends its keys). Use the Decisions text, with `@failedToSaveSetting` placeholder metadata in `app_en.arb`.
- [x] `preference_modal.dart` -- Inner `ScaffoldMessenger` and `Scaffold`, and the setting-failure listener.
- [x] `user_section.dart` -- The name-only listener and the edit-mode handling.
- [x] `test/features/user/presentation/preferences_modal/preference_modal_test.dart`, `user_section_test.dart` -- A theme failure shows the quoted message inside the modal; a name failure shows the display-name message with no exception text and keeps the field editable; a name success closes the field.
- [x] `patient_setup_dialog.dart`, `patient_edit_dialog.dart` -- Hold a normalized code, map it in `build`, remove the `didChangeDependencies` reset, and map at the `:333` call.
- [x] `test/core/widgets/patient_setup_dialog_test.dart`, `test/features/user/presentation/preferences_modal/sections/patient/patient_edit_dialog_test.dart` (both new) -- The gender survives a locale or theme change; `other`/null shows "Prefer not to say" and saves `unknown`; saved codes are unchanged.

**Acceptance Criteria:**
- Given the rebuilt app, when `fvm flutter analyze` runs, then nothing references `UserRemoteDataSource` and there are no issues.
- Given the Preferences modal on a phone, when a setting fails, then the snackbar is readable above the blur. This is checked on a device.

## Implementation Notes

- Choices that don't block the work and aren't settled by this spec may be decided during implementation; record each one here with its reason.
- Profile part (main checkout, 2026-11-03):
  - Saves wait for each other (`_queueUserSave` in `UserBloc`). Per-event `sequential()` still let a theme save and a name save overlap, and the later full-user write erased the earlier field. Each queued save reads `state.user` right before writing. Verified: with the queue bypassed, the three concurrent-save tests fail.
  - Share Proximity starts or stops listening before saving. If `startListening` throws, nothing is saved. If the save fails after listening changed, listening is restored, and a failed restore is logged.
  - `preference_modal.dart` wraps the whole screen inside the blur in its own `ScaffoldMessenger` and a transparent `Scaffold`; wrapping only the card stretched the modal. A full-screen tap catcher behind the dialog keeps tap-outside-to-close working.
  - The en text uses a straight apostrophe ("Couldn't"), as most of `app_en.arb` does.
  - `fake_async: ^1.3.3` is a new direct dev dependency, for `user_repository_impl_test.dart` (it was already in the lock as a transitive dependency).
  - Known limits:
    - The modal barrier's "Dismiss" screen-reader label is no longer reachable; tap-outside and Escape still close the modal.
    - Setting failures show a snackbar only while the Preferences modal is open. Onboarding's biometric switch shows none, as before.
    - The device check that the snackbar is readable above the blur is still to do.
- Patient dialogs (parallel package, worktree, applied to the branch 2026-11-03):
  - New `GenderMapper.normalizeFhirGenderCode` turns anything but `male`/`female` into `unknown`. `PatientEditService` is untouched.
  - Both dialogs hold `_selectedGenderCode` and map it to a label in `build`. The `didChangeDependencies` overrides are removed.
  - Setup: `genderChanged` is `code != 'unknown'`.
  - Edit: `hasPatientChanges(newGender:)` receives the mapped label; the dialog's own change check compares normalized codes; `gender:` is `genderChanged ? code : null`.
  - A stored `other` is shown as "Prefer not to say". It is left as stored unless the user changes the gender; switching to "Prefer not to say" writes `unknown`. This is today's behaviour.
  - Tests: `test/core/widgets/patient_setup_dialog_test.dart` (10) and `.../patient/patient_edit_dialog_test.dart` (9). The language, theme and scan survival cases fail on the old code. `gender_mapper_test.dart` is extended.

## Spec Change Log

## Review Triage Log

| # | Source | Finding | Verdict | Evidence | Route |
|---|---|---|---|---|---|
| 1 | blind | Biometric failure path never runs: `BiometricAuthService.authenticate` catches and returns false | medium | `biometric_auth_service.dart:47-50` catches every exception; lockout or not-enrolled turns the lock off silently, as before this change | defer |
| 2 | blind, edge | Failures outside the Preferences modal (records page receive mode, onboarding biometric) show no message | medium | Only `PreferenceModal` listens; `records_page.dart:554` and onboarding had no message before either | defer |
| 3 | blind, edge | Sync reload not queued behind saves, can emit a stale user | low | `_onUserDataUpdatedFromSync` calls `_getCurrentUser` outside `_queueUserSave`; the fix is one wrap | patch |
| 4 | blind, edge | Receive-mode service lookup and `isListening` read outside `try` | medium | `user_bloc.dart:576-586`; a throw leaves the status loading with no failure | patch |
| 5 | blind | Missing queue tests (throw past handler, after-failure base, restore on off) | low | Edge paths; the main concurrency paths are tested and mutation-checked | reject |
| 6 | blind | `async.elapsed == Duration.zero` assertion is vacuous; `fake_async` added for it | low | The `done` check carries the test (it failed against the mock); the extra assertion is harmless | reject |
| 7 | blind | Name failure uses its own string; dead `UserSetting.name` arm in `_settingLabel` | low | The arm is required for an exhaustive switch; the separate string follows the spec's Decisions | reject |
| 8 | blind, edge | `success(setting)` set only by the name save | low | Matches the Code Map (optional, name only); no listener keys on other successes | reject |
| 9 | blind | Picker still passes labels; label round trip for `hasPatientChanges` | low | The spec forbids changing `PatientEditService`; behaviour is correct | reject |
| 10 | blind | `normalizeFhirGenderCode` repeats the display mapper's switch; bare `'unknown'` literal | low | Duplication, no wrong result | reject |
| 11 | blind | Setup dialog turns a scanned `other` into `unknown` | low | Same as before: `other` mapped to "Prefer not to say", saved as `unknown` | reject |
| 12 | blind, edge | No saving feedback; repeated taps or typing after ✓ queue duplicate saves | low | Duplicate saves write the same value; adds UI state to fix | reject |
| 13 | blind, edge | Full-screen Scaffold hides the barrier's "Dismiss" semantics action | medium | `preference_modal.dart:708-716`: the bare `GestureDetector` has no `Semantics`. Fixed differently: the route barrier's Dismiss node was still present, and a wrapper would have announced Dismiss twice. The tap catcher now uses `excludeFromSemantics: true`, with a test asserting exactly one Dismiss node that closes the modal | patch |
| 14 | blind | `User` keeps `email`, `photoUrl`, `isEmailVerified`, unused now | low | Unused fields, no behaviour harm; outside this change | reject |
| 15 | blind | Dialog tests duplicate setup; `ValueNotifier` never disposed | low | Test-only duplication | reject |
| 16 | blind | Test name credits the queue for what `sequential()` does | low | Cosmetic | reject |
| 17 | verification | No test covers the wallet instance as the edit dialog's gender source | medium | Every test stubs empty `patientGroups`; a regression to `widget.patient` would pass | patch |
| 18 | verification | Outer catch log text "Failed to save the new user" | low | That catch is reached when the fallback save fails; the text fits | reject |
| 19 | edge | Restore of listening fails after a failed save, so state and service disagree | low | Needs a save failure and a restart failure together; fixing adds a branch | reject |
| 20 | edge | Two queued theme toggles with the first failing end opposite to the user's intent | low | Rare; fixing changes the event shape | reject |
| 21 | edge | Enter fires both `onEditingComplete` and `onSubmitted`, so two saves | low | `user_section.dart:127-128`; the fix is a one-line deletion | patch |
| 22 | edge | Setup dialog overwrites a stored male or female with `unknown` when only other fields change | medium | Before this change it also started at "Prefer not to say" and wrote that code; existing behaviour | defer |
| 23 | edge | Claim: edit dialog doesn't turn a stored `other` into `unknown` | false | The matrix says "exactly as today"; today's edit dialog also sent `gender: null` for an unchanged `other` | reject |

## Verification

**Commands:**
- `fvm dart run build_runner build` -- expected: succeeds
- `fvm flutter test test/features/user test/core/widgets test/features/app_lock test/widget_test.dart` -- expected: all pass, no `BUG:` skip left in `user_bloc_test.dart`
- `scripts/check.sh` -- expected: no issues

**Manual checks (if no CLI):**
- On a phone and on macOS: make a setting fail (debug override) with Preferences open, and check that the snackbar shows inside the modal.
