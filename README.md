# Med Reminder

Offline-first Flutter medication reminder. All medication data, dose logs, photos, and reminder scheduling stay on-device; there is no application server.

## Architecture

The project uses pragmatic Clean Architecture + MVVM with Riverpod for dependency injection.

- `domain`: pure entities, repository contracts, and service ports. No Flutter, Riverpod, or Hive dependencies.
- `data`: Hive/local data sources, persistence records/mappers, repository implementations, and local service adapters.
- `presentation`: Riverpod-backed ViewModels and UI-facing state.
- `main.dart`: composition root that injects concrete implementations through `ProviderScope.overrides`.

Hive is therefore one storage implementation rather than a dependency of medication business/presentation logic. Repository providers can be overridden with in-memory, SQLite, or other implementations without changing the ViewModel.

## Current baseline

- Riverpod `StateNotifier` ViewModels for medications and dose logs.
- Abstract `MedicationRepository` / `DoseLogRepository` contracts with Hive-backed local implementation.
- Hive boxes `meds` and `logs` for current local persistence.
- One editable CSV localization source: `assets/translations.csv` (`key,en,th,...`). `make l10n-generate` validates it and generates compact per-locale JSON plus `generated_locales.dart`; only generated JSON is bundled and loaded at runtime.
- Local scheduled notifications using timezone-aware `zonedSchedule`.
- Independent dose state per scheduled time (`scheduledAt`), so 08:00 and 20:00 do not share one taken flag.
- Medication modes: `forever`, finite `days`, and `untilEmpty`.
- Package photos copied into application documents storage instead of retaining an image-picker cache path.
- UI actions: Taken, Skip, Snooze 10 minutes with explicit semantics labels and a wrapping action layout for larger text.
- Native Live Activity / Watch integration is kept as an explicit handoff and is not reported as complete until platform targets are wired and device-tested.

## Localization workflow

```bash
# edit assets/translations.csv
make l10n-generate
```

Generated runtime files live under `assets/translations/`. CI runs `make l10n-check` so stale JSON or locale metadata cannot be merged accidentally.

## Bootstrap platform folders

This repository keeps generated Flutter platform scaffolding reproducible rather than committing guessed generated files from an environment without Flutter installed.

```bash
./tool/bootstrap_platforms.sh
flutter pub get
flutter run
```

The bootstrap command creates Android and iOS folders using your installed Flutter SDK while preserving `lib/`, `assets/`, tests, and documentation.

## Validation and test suites

```bash
make l10n-check
make format-check
make analyze
make test

# Focused suites
make test-domain
make test-data
make test-presentation
make test-suites

# Full platform validation + debug build
make android
make ios
```

`make android` runs localization validation, format-check, analyze, all Flutter tests, then builds a debug APK. `make ios` runs the same validation and tests, then builds a debug iOS Simulator app; iOS builds require macOS/Xcode.

Build-only and test/build aliases are also available:

```bash
make android-build
make android-test
make ios-build
make ios-test
```

When using FVM, override the tool commands without changing the Makefile:

```bash
make android FLUTTER="fvm flutter" DART="fvm dart"
make ios FLUTTER="fvm flutter" DART="fvm dart"
```

Accessibility regression tests include explicit Semantics labels for the dose actions and a 1.3x text-scale layout check.

## Roadmap / release baseline

- PR #2: native companion work from `handoff/NATIVE_HANDOFF.md`.
- PR #3: offline ZIP export/import backup and restore. See `docs/BACKLOG.md` for the versioned archive contract and acceptance criteria.
- After PR #1 is merged with required CI green, tag `main` as `v0.1.0-bootstrap-fixed` and use that tag as the baseline reference for PR #2.

See `handoff/CODE_WALKTHROUGH.md` for architecture, `handoff/CSV_LOCALIZATION.md` for the CSV-to-JSON pipeline, `handoff/NATIVE_HANDOFF.md` for Live Activity / watch work, and `docs/BACKLOG.md` for planned offline backup/restore.
