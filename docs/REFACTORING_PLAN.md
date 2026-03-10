# HealthWallet.me — Refactoring Plan

**Date:** 2026-03-10
**Scope:** lib/ codebase cleanup — dead code, duplication, architecture fixes
**Estimated total effort:** ~2-3 weeks

---

## Phase 1: Dialog Consolidation (1 day)

**Goal:** Remove 3 duplicate dialog implementations, keep only `AppDialog`.

### Current state
All 4 classes implement the same pattern: `BackdropFilter(blur 5x5) → Dialog(transparent) → Container(surface + border)`.

| File | Lines | Action |
|------|-------|--------|
| `lib/core/widgets/dialogs/app_dialog.dart` | 518 | KEEP — extend with modes |
| `lib/core/widgets/dialogs/confirmation_dialog.dart` | 144 | DELETE — migrate callers |
| `lib/core/widgets/dialogs/success_dialog.dart` | 113 | DELETE — migrate callers |
| `lib/core/widgets/dialogs/alert_dialogs.dart` | 150+ | DELETE — migrate callers |

### Steps
1. Grep all usages of `ConfirmationDialog`, `SuccessDialog`, `AlertDialogs` across the codebase
2. Add `AppDialog.showConfirmation()` and `AppDialog.showSuccess()` static methods if not present
3. Migrate each caller to use `AppDialog` equivalents
4. Delete the 3 redundant files
5. Verify no broken imports

### Acceptance criteria
- Only `app_dialog.dart` and `delete_confirmation_dialog.dart` remain in `lib/core/widgets/dialogs/`
- All dialog UIs render identically to before
- No unused imports

---

## Phase 2: DocumentHandler Mixin Refactor (2 days)

**Goal:** Move business logic out of the presentation-layer mixin into BLoC.

### Current state
`lib/features/scan/presentation/helpers/document_handler.dart` is a mixin on StatefulWidgets that directly calls:
- `scanRepository.checkModelExistence()`
- `SourceTypeService`
- `SyncRepository`
- Encounter creation logic
- Navigation logic

### Steps
1. Identify all business logic methods in the mixin
2. Create corresponding BLoC events/handlers in `ScanBloc` (or a new dedicated BLoC if ScanBloc is already too large)
3. Replace direct repository/service calls in the mixin with BLoC event dispatches
4. Keep only navigation and UI-coordination code in the mixin
5. Update all widgets that use the mixin

### Acceptance criteria
- Mixin has zero direct repository/service calls
- All business logic testable via BLoC unit tests
- Existing behavior unchanged

---

## Phase 3: Naming & Structure Standardization (1 hour)

**Goal:** Consistent naming across all features.

### Steps
1. Rename `lib/features/records/data/datasource/` → `lib/features/records/data/data_source/`
2. Update all imports referencing the old path
3. Verify auto_route and injectable codegen still works

### Acceptance criteria
- All features use `data_source/` (not `datasource/`)
- No broken imports

---

## Phase 4: Move Misplaced Services (1 day)

**Goal:** Services in presentation layer belong in data or domain layer.

### Files to move

| Current location | New location | Reason |
|-----------------|-------------|--------|
| `scan/presentation/services/pdf_generation_service.dart` | `scan/data/services/` | Data transformation, not presentation |
| `scan/presentation/helpers/ocr_processing_helper.dart` | `scan/data/utils/` | Data processing, not UI |

### Steps
1. Move each file to correct layer
2. Update all imports
3. Verify DI registration still resolves

### Acceptance criteria
- `presentation/services/` directory is empty or removed
- `presentation/helpers/` contains only UI helpers (no repository/service calls)

---

## Phase 5: Split Oversized Files (2-3 days)

**Goal:** No source file exceeds ~500 lines.

### 5a. FhirFieldExtractor (1,581 lines → ~4 files)

**Current:** One massive utility class handling extraction for all FHIR resource types.

**Plan:**
1. Create `lib/features/records/domain/utils/extractors/` directory
2. Split by resource category:
   - `patient_extractor.dart` — patient, practitioner, care team
   - `clinical_extractor.dart` — condition, procedure, allergy, adverse event
   - `diagnostic_extractor.dart` — observation, diagnostic report, specimen
   - `medication_extractor.dart` — medication statement, immunization
   - `administrative_extractor.dart` — encounter, claim, coverage, organization
3. Keep `fhir_field_extractor.dart` as a facade that delegates to sub-extractors
4. Consolidate the 3 duplicate `extractHumanName*()` methods into one with a `HumanNameFormat` enum parameter

### 5b. ShareRecordsBloc (1,421 lines → 2-3 files)

**Plan:**
1. Extract PDF generation handler methods into a separate `ShareRecordsPdfHandler` or move to a use case
2. Extract FHIR export logic into `ShareRecordsFhirHandler`
3. Keep core BLoC with event routing and state management only

### 5c. ScanBloc (1,021 lines)

**Plan:**
1. Extract session management handlers (create, activate, clear) into `ScanSessionHandler`
2. Extract processing pipeline (mapping, patient extraction, resource processing) into `ScanProcessingHandler`
3. Keep BLoC as orchestrator

### 5d. ProcessingPage (810 lines → page + extracted widgets)

**Plan:**
1. Extract `_buildMappingSection` → `MappingSectionWidget`
2. Extract `_buildResourcesSection` → `ResourcesSectionWidget`
3. Extract `_buildScannedBasicButtons` → `ScannedBasicActionsWidget`
4. Extract `_buildCapacityFailure` → `CapacityFailureWidget`
5. Keep `ProcessingPage` as layout orchestrator (~200 lines)

---

## Phase 6: Remove Direct getIt Usage in Widgets (ongoing)

**Goal:** Widgets receive dependencies through constructors or BLoC, not service locator.

### Common offenders
- `processing_page.dart` — `getIt<ScanRepository>()`, `getIt<SharedPreferences>()`
- `document_handler.dart` — `getIt<ScanRepository>()`
- Various settings widgets

### Steps (per widget)
1. Identify `getIt<>()` calls in build/init methods
2. If the data is needed for state: move to BLoC, expose via state
3. If the data is a one-time config: pass through widget constructor
4. Remove direct getIt imports from presentation files

### Acceptance criteria
- Presentation layer files have zero `getIt<>()` calls (except page-level BLoC creation, which is the standard pattern)

---

## Phase 7: Duplicate Method Cleanup (0.5 day)

### Human name extraction consolidation

**Current (3 methods in fhir_field_extractor.dart):**
- `extractHumanName()` — "Given Family"
- `extractHumanNameForHome()` — "Given Family" (same but different null handling)
- `extractHumanNameFamilyFirst()` — "Family, Given"

**Target (1 method):**
```dart
enum HumanNameFormat { givenFirst, familyFirst }

String extractHumanName(
  Map<String, dynamic> resource, {
  HumanNameFormat format = HumanNameFormat.givenFirst,
})
```

### Steps
1. Create unified method with format parameter
2. Grep all callers of the 3 methods
3. Migrate each caller to use the unified method with appropriate format
4. Delete the 2 redundant methods

---

## Priority Order

| Phase | Priority | Effort | Impact |
|-------|----------|--------|--------|
| 1. Dialog consolidation | Critical | 1 day | Removes 400+ lines of duplication |
| 2. DocumentHandler refactor | High | 2 days | Fixes architecture violation |
| 3. Naming standardization | High | 1 hour | Consistency |
| 4. Move misplaced services | High | 1 day | Correct layer separation |
| 5. Split oversized files | Medium | 2-3 days | Maintainability |
| 6. Remove getIt in widgets | Low | ongoing | Testability |
| 7. Duplicate methods | Low | 0.5 day | Code clarity |

---

## Out of Scope

- Adding unit tests (separate initiative)
- FHIR entity structure (intentional 1:1 spec mapping, not refactored)
- Generated files (freezed, auto_route, drift — managed by tooling)
- AI model pipeline (recently refactored in HM-180/HM-181)
