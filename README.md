# Besyu

**Beside You.**  
**อยู่ข้างกาย ในทุกวัน**

Besyu is an offline-first Flutter medication companion. Medication data, dose logs, photos, profile metadata, language choice, and reminder scheduling stay on-device; there is no application server.

## Architecture

The project uses pragmatic Clean Architecture + MVVM with Riverpod for dependency injection.

- `domain`: pure entities, repository contracts, and service ports.
- `data`: Hive/local data sources, persistence records/mappers, repository implementations, and local service adapters.
- `presentation`: Riverpod-backed ViewModels and UI-facing state.
- `main.dart`: composition root that injects concrete local implementations through `ProviderScope.overrides`.

## Current baseline

- Riverpod `StateNotifier` ViewModels for medications and dose logs.
- Hive boxes `meds`, `logs`, and `settings`.
- Generated JSON localization from the canonical `assets/translations.csv` source.
- English and Thai runtime localization.
- If the user has never selected a language, Besyu uses the supported device locale and falls back to English when unsupported.
- Onboarding includes a globe control to switch EN/TH; using it stores an explicit `language_code` override.
- Settings offers English/Thai selection only; there is intentionally no visible System default option.
- Bottom navigation destinations: Today, Medications, Settings.
- Settings contains Language, optional Profile, Permissions, and About.
- Optional age/sex profile remains local and is not used for dose calculation or clinical decision-making.
- Local timezone-aware medication reminders with stable notification IDs.
- Notification permission and Android exact-alarm permission are user-driven rather than startup-driven.
- Android scheduled notification and boot receivers are registered.
- Finite `days` schedules remain anchored to `Medication.createdAt`.
- The current iOS bootstrap uses classic `FlutterAppDelegate` after a physical-device UIScene/SceneDelegate black-screen incident on the Flutter 3.47 baseline. See `docs/iphone_black_screen_issue.md`.

## Language policy

Besyu currently supports:

- English (`en`)
- Thai (`th`)

Startup resolution is deterministic:

1. Use stored Hive `language_code` when one exists.
2. Otherwise use the device locale when it matches a supported language.
3. Otherwise fall back to English.

`EasyLocalization` internal locale persistence is disabled (`saveLocale: false`) so Hive is the single source for an explicit language override.

The onboarding globe toggle and Settings language selector both write the same `language_code` setting.

## First-run onboarding and permissions

The first launch uses a three-step onboarding flow:

1. Besyu welcome / offline-first feature summary.
2. Notification explanation with explicit **Enable notifications** and **Not now** actions.
3. Android optionally offers **Enable precise reminders** for Alarms & reminders; iOS shows a ready screen.

The onboarding screen also provides a globe button for EN/TH switching. If untouched, the initial language remains based on device locale. If the user switches language, that becomes the explicit language override.

Completing onboarding stores `onboarding_completed = true` in Hive. Camera/photo-library permissions remain just-in-time.

## Settings

Settings is the third bottom-navigation destination and includes:

- Language — English / Thai.
- Profile — optional age and sex metadata stored locally.
- Permissions — notification access, Android precise-reminder access, camera/photo guidance, and a direct system App Settings action.
- About — Besyu identity, version, and offline-first status.

See `docs/settings.md` for the detailed contract.

## Localization workflow

```bash
# edit assets/translations.csv
make l10n-generate
```

Generated runtime files live under `assets/translations/`. CI runs `make l10n-check` so stale JSON or locale metadata cannot be merged.

## Git quality hooks

Install the tracked hooks once per clone:

```bash
make setup-hooks
```

After installation:

- `git commit` runs `make format` automatically and re-stages formatted Dart files before the commit is created.
- The pre-commit hook refuses to auto-stage when unrelated unstaged Dart changes exist, preventing accidental commit contamination.
- `git push` runs generated-file preparation plus CI-equivalent checks through the tracked pre-push hook.
- The pre-push hook remains a final guard: if generation or formatting would change committed content, the push stops instead of sending a commit that CI would reject.

This keeps formatting correction before the commit boundary while retaining strict verification before push.

## Validation

```bash
make l10n-check
make format-check
make analyze
make test
make android
make ios
```

Focused suites are also available through `make test-domain`, `make test-data`, `make test-presentation`, and `make test-suites`.

## iPhone black-screen troubleshooting

If an iPhone builds successfully but displays a black screen, inspect the Xcode console before assuming a Dart failure. The reproduced incident showed a running Dart VM together with an unresolved SceneDelegate and no attached UIKit scene. The verified repository baseline and recovery procedure are documented in `docs/iphone_black_screen_issue.md`.

## Roadmap / release baseline

- Next UI milestone: App Theme System with five selectable themes — Besyu Blue, Warm Sand, Sage Care, Lavender Calm, and Midnight. Theme selection will live in Settings and persist locally. See `docs/BACKLOG.md`.
- PR #2: native companion work from `handoff/NATIVE_HANDOFF.md`.
- PR #3: offline ZIP export/import backup and restore from `docs/BACKLOG.md`.
- After PR #1 is merged with required CI green, tag merged `main` as `v0.1.0-bootstrap-fixed` and use that tag as the baseline for PR #2.
