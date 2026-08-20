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
- Hive boxes `meds` and `logs` for medication state plus a small `settings` box for local app flags such as first-run onboarding completion.
- One editable CSV localization source: `assets/translations.csv` (`key,en,th,...`). `make l10n-generate` validates it and generates compact per-locale JSON plus `generated_locales.dart`; only generated JSON is bundled and loaded at runtime.
- Local scheduled notifications using timezone-aware `zonedSchedule`.
- First-run onboarding explains offline storage, medication reminders, and stock tracking before any permission prompt is shown.
- Notification permission is user-driven from onboarding on both Android and iOS; startup initializes the plugin without displaying permission UI.
- Android exact-alarm access is an optional onboarding action. Without it the app uses `inexactAllowWhileIdle` rather than blocking startup or forcing the system settings screen.
- Finite `days` schedules are anchored to the medication `createdAt` date, so timezone refresh/rescheduling cannot extend the treatment course.
- Independent dose state per scheduled time (`scheduledAt`), so 08:00 and 20:00 do not share one taken flag.
- Taken-dose reconciliation runs only after the dose log is persisted successfully; a failed write rolls back presentation state and does not mutate stock/reminder side effects.
- Medication modes: `forever`, finite `days`, and `untilEmpty`.
- Package photos copied into application documents storage instead of retaining an image-picker cache path.
- UI actions: Taken, Skip, Snooze 10 minutes with explicit semantics labels and a wrapping action layout for larger text.
- Android 13+ notification permission and exact-alarm declarations are present in the app manifest.
- The current iOS bootstrap uses the classic `FlutterAppDelegate` lifecycle after a physical-device UIScene/`SceneDelegate` resolution failure was reproduced with the Flutter 3.47 baseline. See `docs/iphone_black_screen_issue.md`.
- Native Live Activity / Watch integration is kept as an explicit handoff and is not reported as complete until platform targets are wired and device-tested.

## First-run onboarding and permissions

The first launch uses a three-step onboarding flow:

1. Welcome and offline-first feature summary.
2. Notification explanation with an explicit **Enable notifications** action and **Not now** fallback.
3. On Android, an optional **Enable precise reminders** action for the system Alarms & reminders permission. On iOS, the third step is a normal ready screen.

Completing onboarding stores `onboarding_completed = true` in the local Hive `settings` box, so subsequent launches go directly to Home. Camera/photo-library permissions are intentionally not requested during onboarding; they remain just-in-time permissions when the user chooses to capture/select medication packaging.

Permission prompts must not be moved back into `NotificationService.init()`. A physical Samsung Android 16 run demonstrated that requesting notification/exact-alarm permission during startup can background the Flutter activity and interfere with the launch/debug-attach path. Interactive permission calls are therefore allowed to wait for the user's decision instead of using the five-second native startup timeout.

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

For the current iOS baseline, do not blindly restore a generated `UIApplicationSceneManifest` after bootstrap. The physical-device black-screen incident and the verified classic-lifecycle configuration are documented in `docs/iphone_black_screen_issue.md`.

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

Physical-device iOS AOT validation helpers are available with an explicit device ID:

```bash
make ios-device-profile DEVICE=<device-id>
make ios-device-release DEVICE=<device-id>
```

When using FVM, override the tool commands without changing the Makefile:

```bash
make android FLUTTER="fvm flutter" DART="fvm dart"
make ios FLUTTER="fvm flutter" DART="fvm dart"
```

Accessibility regression tests include explicit Semantics labels for the dose actions and a 1.3x text-scale layout check.

## iPhone black-screen troubleshooting

If an iPhone builds successfully but displays a black screen, run from `ios/Runner.xcworkspace` and inspect the Xcode console before assuming a Dart bootstrap failure. In the reproduced incident, the decisive log was:

```text
could not load class with name "Runner.SceneDelegate"
There is no scene delegate set.
flutter: The Dart VM service is listening on ...
```

A running Dart VM service together with the native scene error showed that Dart had started but the iOS scene/window was not attached. The verified fix for this repository is documented in `docs/iphone_black_screen_issue.md`.

## Roadmap / release baseline

- PR #2: native companion work from `handoff/NATIVE_HANDOFF.md`.
- PR #3: offline ZIP export/import backup and restore. See `docs/BACKLOG.md` for the versioned archive contract and acceptance criteria.
- After PR #1 is merged with required CI green, tag `main` as `v0.1.0-bootstrap-fixed` and use that tag as the baseline reference for PR #2.

See `handoff/CODE_WALKTHROUGH.md` for architecture, `handoff/CSV_LOCALIZATION.md` for the CSV-to-JSON pipeline, `handoff/NATIVE_HANDOFF.md` for Live Activity / watch work, `docs/iphone_black_screen_issue.md` for the physical-iPhone lifecycle incident, and `docs/BACKLOG.md` for planned offline backup/restore.
