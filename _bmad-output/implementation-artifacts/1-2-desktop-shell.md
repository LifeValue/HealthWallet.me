# Story 1.2: Desktop Shell — Enable Platforms & Entry Point

Status: done

## Story

As a user,
I want to launch HealthWallet.me as a desktop application,
so that I can access my health records on a bigger screen with a desktop-optimized layout.

## Acceptance Criteria

1. Given the desktop app is launched, when the user sees the main screen, then 4 tabs are visible: Home, Records, Import, Backup
2. Given `main_desktop.dart` exists, when it runs, then `AppPlatform.desktop` is injected through DI and accessible to all widgets/blocs
3. Given the desktop window opens, when the user resizes it, then minimum size is 900x600 and last size/position is remembered
4. Given the user is on desktop, when they view Records, then a 4-column layout with wider cards is displayed
5. Given the user is on desktop, when Scan-related UI would normally appear, then it is hidden (no camera on desktop)
6. Given macOS entitlements are configured, when the app launches, then network, file access, and keychain permissions work

## Tasks / Subtasks

- [ ] Task 1: Create AppPlatform enum and register in DI (AC: #2)
  - [ ] Create `lib/core/config/app_platform.dart` with `AppPlatform` enum (mobile/desktop) and extension methods `isDesktop`/`isMobile`
  - [ ] Register `AppPlatform` in DI — pass it to `configureDependencies()` or register manually in `RegisterModule`
  - [ ] Replace `_isMobile` getter in `main.dart` and `app.dart` with DI-injected `AppPlatform`

- [ ] Task 2: Create `main_desktop.dart` entry point (AC: #2)
  - [ ] Create `lib/main_desktop.dart` that registers `AppPlatform.desktop` in GetIt before calling `configureDependencies()`
  - [ ] Existing `main.dart` registers `AppPlatform.mobile`
  - [ ] Both entry points share the same `App` widget — platform difference is only in DI

- [ ] Task 3: Create Backup feature scaffold (AC: #1)
  - [ ] Create `lib/features/backup/presentation/pages/backup_page.dart` — empty scaffold with `@RoutePage()` annotation
  - [ ] Create `lib/features/backup/presentation/bloc/backup_bloc.dart` — minimal BLoC with Freezed events/states, registered via `@injectable`
  - [ ] Add `BackupRoute` to `app_router.dart` as a Dashboard child route

- [ ] Task 4: Swap tabs based on AppPlatform (AC: #1, #5)
  - [ ] Modify `dashboard_page.dart` PageView.builder: inject `AppPlatform` from DI
  - [ ] Mobile tabs (index 0-3): Home, Records, Scan, Import (unchanged)
  - [ ] Desktop tabs (index 0-3): Home, Records, Import, Backup (Scan replaced by Backup)
  - [ ] Update bottom nav bar items to match: swap Scan icon/label for Backup icon/label on desktop
  - [ ] Use `Assets.icons.cloudDownload` for Backup tab icon (reuse existing asset)

- [ ] Task 5: Window sizing constraints (AC: #3)
  - [ ] Add `window_manager` or platform-specific code to set min window size 900x600 on desktop
  - [ ] Remember last window size/position (persist via SharedPreferences or window_manager)

- [ ] Task 6: Desktop responsive layout hints (AC: #4)
  - [ ] Extend `ResponsiveExtension` in `lib/core/utils/responsive.dart` to detect desktop (existing `isTablet` uses width threshold)
  - [ ] Add `isDesktop` getter that checks `AppPlatform` from DI or uses width-based detection
  - [ ] Records grid and Home grid can use 4 columns when `isDesktop` (currently 2-3 columns for mobile/tablet)

## Dev Notes

### Previous Story Intelligence (Story 1.1)

- macOS build validated: compiles, launches, Drift DB inits, no crashes
- Platform guards added to `main.dart` (`_isMobile` getter) and `app.dart` — these should be replaced with DI-injected `AppPlatform`
- `mobile_scanner` has macOS support (unexpected)
- `register_module.dart` has comments that will be rejected by pre-commit hook (lines 5, 24) — fix when touching this file

### Architecture Compliance

- **Clean Architecture:** Backup feature follows standard structure: `presentation/` (pages, bloc), `domain/` (entities, repos), `data/` (impl) — but for this story only scaffold the presentation layer
- **BLoC pattern:** BackupBloc with Freezed events/states, `@injectable` registration
- **DI:** AppPlatform registered via GetIt — accessible everywhere via `getIt<AppPlatform>()`
- **AutoRoute:** BackupPage annotated with `@RoutePage()`, added to Dashboard children in `app_router.dart`
- **Code gen required after:** Adding BackupRoute (AutoRoute), BackupBloc (Injectable), BackupEvent/State (Freezed)

### File Structure

```
lib/
├── main.dart                          (MODIFY — register AppPlatform.mobile)
├── main_desktop.dart                  (NEW — register AppPlatform.desktop)
├── core/
│   ├── config/
│   │   └── app_platform.dart          (NEW — AppPlatform enum)
│   ├── di/
│   │   └── register_module.dart       (MODIFY — if needed for AppPlatform registration)
│   ├── navigation/
│   │   └── app_router.dart            (MODIFY — add BackupRoute to Dashboard children)
│   └── utils/
│       └── responsive.dart            (MODIFY — add isDesktop getter)
├── features/
│   ├── backup/
│   │   └── presentation/
│   │       ├── pages/
│   │       │   └── backup_page.dart   (NEW — empty scaffold)
│   │       └── bloc/
│   │           ├── backup_bloc.dart   (NEW — minimal BLoC)
│   │           ├── backup_event.dart  (NEW — Freezed events)
│   │           └── backup_state.dart  (NEW — Freezed states)
│   └── dashboard/
│       └── presentation/
│           └── dashboard_page.dart    (MODIFY — conditional tab swap)
```

### Critical Reminders

- Pre-commit hook rejects ALL comments — do not add any `//` or `///` to new files
- Run `dart run build_runner build --delete-conflicting-outputs` after creating BackupBloc, BackupRoute, and Freezed classes (user handles this)
- Do NOT use `getIt<AppPlatform>()` in widgets — inject through constructor or access via `context.read()` if provided as BLoC/service
- Actually, since AppPlatform is a simple enum value (not a service), registering as a singleton in GetIt and accessing via `getIt<AppPlatform>()` is acceptable for this case — similar to how constants are registered

### References

- [Source: _bmad-output/planning-artifacts/prd.md — FR1-FR6]
- [Source: _bmad-output/planning-artifacts/epics.md — Story 1.2]
- [Source: _bmad-output/project-context.md — Framework Rules, Code Quality]
- [YouTrack: HM-158]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
