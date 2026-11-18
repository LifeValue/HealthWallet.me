---
project_name: 'HealthWallet.me'
user_name: 'LifeValue'
date: '2026-03-17'
sections_completed: ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'code_quality', 'workflow_rules', 'critical_rules']
status: 'complete'
rule_count: 45
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

- **Flutter 3.38.7** (FVM-managed) / **Dart SDK >=3.10.7 <4.0.0**
- iOS 16.0+ / Android SDK 24+, compile SDK 36
- **State:** flutter_bloc ^8.1.4, bloc ^8.1.3, bloc_concurrency ^0.2.5
- **DI:** get_it ^7.6.7, injectable ^2.3.5
- **Routing:** auto_route ^7.8.4 (v7, NOT v11)
- **Database:** drift ^2.15.0 (schema v8, step-by-step migrations)
- **Code gen:** freezed ^2.4.6, json_serializable ^6.7.1, build_runner ^2.4.8
- **Network:** dio ^5.9.2
- **FHIR:** fhir_r4 ^0.4.2, fhir_ips_export (private git, SSH key required)
- **AI/Vision:** llamadart ^0.6.6 (on-device VLM inference)
- **P2P:** airdrop (private git, SSH key required)
- **Env:** envied ^1.3.3 (obfuscated values)
- **Biometric:** local_auth ^2.1.7
- **Wallet:** passkit ^1.1.0, flutter_google_wallet ^0.2.1

### Version Constraints

- auto_route_generator ^7.3.2 pins analyzer <7.0.0 — blocks upgrade to Flutter 3.41+ until auto_route v11 migration
- flutter_gen_runner removed (incompatible with dart_style in Dart 3.10.7)
- custom_lint + bloc_lint removed (incompatible with Dart 3.10.7)

## Critical Implementation Rules

### Dart/Flutter Language Rules

- All models use **Freezed** for immutable data classes — never create plain mutable model classes
- Events and states are Freezed union types with `factory` constructors
- Generated files (`*.freezed.dart`, `*.g.dart`, `*.config.dart`, `*.gr.dart`) — never edit manually
- Run `dart run build_runner build --delete-conflicting-outputs` after changing models, routes, DI, DB schemas, or env
- Relative imports within features, package imports across features — no barrel files
- No `// ignore_for_file:` directives allowed (pre-commit hook rejects them)
- `invalid_annotation_target: ignore` set globally in analysis_options.yaml
- Use `BuildContextExtension` helpers: `context.l10n`, `context.appRouter`, `context.theme`, `context.isDarkMode`, `context.closeKeyboard()` — never use direct `Theme.of(context)` or `AppLocalizations.of(context)`
- Localization: access strings via `context.l10n.stringKey`, ARB files in `core/l10n/arb/` (EN template, ES, DE)

### Framework Rules (Flutter/BLoC/Clean Architecture)

- **Clean Architecture:** Presentation → Domain → Data — never bypass layers
- Business logic belongs in BLoC/Repository/Service/UseCase — NEVER in widgets
- Data transformations, calculations, validations = business logic (not UI)
- Each feature has its own BLoC with Freezed events/states
- BLoCs registered via `@injectable` or `@LazySingleton()` — constructor injection only
- Event handlers use `transformer:` for concurrency control (`restartable()`, `sequential()`, `droppable()`)
- Large event logic encapsulated in **mixins** (e.g., `ScanSessionHandler`, `HomeDataHandler`)
- Global BLoCs (e.g., ScanBloc) initialized at app startup in `main.dart`
- DI entry point: `configureDependencies()` in `core/di/injection.dart` — never call `getIt<T>()` directly in feature code
- Module registrations in `core/di/register_module.dart` using `@module`, `@lazySingleton`, `@preResolve`
- Routes in `core/navigation/app_router.dart` (AutoRoute v7) — pages annotated with `@RoutePage()`, navigate via `context.appRouter`
- Dashboard is parent route with nested children (Home, Records, Scan, Import)
- Drift schema version 8, step-by-step migrations in `app_database.dart`
- Tables: FhirResource, Sources, RecordNotes, ProcessingSessions
- DB optimizations: WAL mode, cache 10K, temp in memory
- New schema changes require: migration step, version bump, drift_schemas export

### Testing Rules

- Tests in `/test` — widget tests with `flutter_test` + `mockito`, BLoC tests with `bloc_test`
- Use **fake repository implementations** (e.g., `FakeUserRepository`, `FakeRecordsRepository`) — fakes preferred over mocks for repository layer
- `mockito ^5.4.4` for targeted mocking where needed
- Database migration tests in `/test/drift/my_database/` using Drift's `SchemaVerifier`
- Migration tests required when adding new schema migration steps — validate data integrity across versions
- Golden tests available via `golden_toolkit ^0.15.0`
- CI runs `flutter test --coverage` on PRs to master

### Code Quality & Style Rules

- **Pre-commit hook rejects ALL comments** (`//`, `///`, `/* */`) in staged code — including `// ignore_for_file:` directives
- When removing comments, grep the entire file for `^\s*(//|///)` — the hook only reports the first batch
- Replace useful comments with `debugPrint()` if info is needed at runtime, otherwise delete entirely
- Always check `/lib/core/` for existing components before creating new ones
- **AppButton** for all buttons (variants: primary, secondary, transparent, outlined, tinted — with fontSize, height, padding params)
- **AppDialog** for dialogs — pattern: `BackdropFilter(blur 5x5) → Dialog(transparent) → Container(surface + border)`
- **AppColors** for all colors (primary, secondary, success, error, warning, info + light/dark variants)
- **AppTextStyle** for all text (title/body/label/button in Large/Medium/Small) — "Matter" font family
- **AppInsets** for spacing (extraSmall 4, smaller 6, small 8, smallNormal 12, normal 16, medium 24, large 32, extraLarge 48, huge 64)
- Files: snake_case with role suffix (`*_bloc.dart`, `*_repository.dart`, `*_page.dart`, `*_service.dart`, etc.)
- Classes: PascalCase with role suffix (Bloc, Event, State, Repository, Service, Page)
- Feature structure: `presentation/` (pages, widgets, bloc), `domain/` (entities, repositories, services), `data/` (repository_impl, data_sources, DTOs)

### Development Workflow Rules

- **Branches:** `master` (prod, auto-deploys), `develop` (staging, auto-deploys), `dev/*`/`feature/*`/`fix/*` (dev), `release/*` (release staging), `hotfix/*` (urgent)
- PRs to master: CI runs `flutter analyze --no-fatal-infos` + `flutter test --coverage`
- Push to master/develop: parallel iOS (Fastlane → TestFlight) + Android (Fastlane → Play Store internal)
- CI restores `.env`, SSH keys, certificates, keystores from GitHub Secrets at build time
- Self-hosted macOS runners for iOS builds
- **NEVER commit** `.pem`, `.p8`, `.p12`, `.key`, `.jks`, `.keystore`, `service-account*.json`, `.env`
- Verify before every commit: `git diff --cached --name-only | grep -iE '\.(pem|p8|p12|key|jks|keystore)$|service-account|\.env$'`
- Private deps (`fhir_ips_export`, `airdrop`) require SSH key access (`SSH_PRIVATE_KEY` secret in CI)

### Critical Don't-Miss Rules

- NEVER put business logic in widgets — if a widget does more than display data and call callbacks, it's wrong
- NEVER create new UI components without first checking `/lib/core/widgets/` and `/lib/core/theme/`
- NEVER use raw colors/text styles — always use AppColors/AppTextStyle
- NEVER write comments in code — pre-commit hook will reject the commit
- NEVER call `getIt<T>()` in feature code — constructor injection only
- NEVER edit generated files (`*.freezed.dart`, `*.g.dart`, `*.config.dart`, `*.gr.dart`)
- All env values obfuscated via Envied — never hardcode API keys
- FHIR data is patient health records — handle with care, offline-first architecture
- App initialization order matters — see `main.dart` for exact sequence (DI → services → ScanBloc → splash removal → bootstrap)
- App widget implements `WidgetsBindingObserver` — starts/stops P2P discovery on resume/pause
- `MultiBlocProvider` wraps all BLoCs at App root level

---

## Usage Guidelines

**For AI Agents:**
- Read this file before implementing any code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Update this file if new patterns emerge

**For Humans:**
- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time

Last Updated: 2026-03-17
