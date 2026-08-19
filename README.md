# Med Reminder

Offline-first Flutter medication reminder. All medication data, dose logs, photos, and reminder scheduling stay on-device; there is no application server.

## Current baseline

- Riverpod `StateNotifier` for medications and dose logs.
- Hive boxes `meds` and `logs` for local persistence.
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
