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
- One CSV localization source: `assets/translations.csv` (`key,en,th,...`) with locale discovery from the header and English value fallback.
- Local scheduled notifications using timezone-aware `zonedSchedule`.
- Independent dose state per scheduled time (`scheduledAt`), so 08:00 and 20:00 do not share one taken flag.
- Medication modes: `forever`, finite `days`, and `untilEmpty`.
- Package photos copied into application documents storage instead of retaining an image-picker cache path.
- UI actions: Taken, Skip, Snooze 10 minutes.
- Native Live Activity / Watch integration is kept as an explicit handoff and is not reported as complete until platform targets are wired and device-tested.

## Bootstrap platform folders

This repository keeps generated Flutter platform scaffolding reproducible rather than committing guessed generated files from an environment without Flutter installed.

```bash
./tool/bootstrap_platforms.sh
flutter pub get
flutter run
```

The bootstrap command creates Android and iOS folders using your installed Flutter SDK while preserving `lib/`, `assets/`, tests, and documentation.

## Validation

```bash
make format-check
make analyze
make test
```

See `handoff/CODE_WALKTHROUGH.md` for architecture and `handoff/NATIVE_HANDOFF.md` for Live Activity / watch work.
