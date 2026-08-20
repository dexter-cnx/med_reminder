# Patrol E2E Handoff

## Status

Planned only. Do **not** implement Patrol inside the current App Theme System PR.

Start this work after the App Theme System is merged and the core UI/navigation/permission flows are stable enough to avoid brittle end-to-end locators.

## Goal

Add Patrol as Besyu's top-level integration/end-to-end test layer for flows that cross multiple screens, app lifecycle boundaries, native permission UI, and real device behavior.

Patrol complements the existing test pyramid; it does not replace unit, repository, ViewModel, widget, accessibility, or theme contract tests.

## Recommended milestone order

1. Finish and merge App Theme System.
2. Create a dedicated Patrol / E2E foundation PR.
3. Establish emulator/simulator smoke flows first.
4. Add physical-device-only flows separately.
5. Use the resulting E2E harness before expanding native companion work such as notification actions, ongoing UI, Live Activity, and watch integrations.

## Initial scope

### Foundation

- Add Patrol dependency and repository configuration.
- Add a dedicated `patrol_test/` suite.
- Add Makefile targets for Patrol setup/run.
- Define deterministic test reset/setup for local Hive state.
- Add stable keys/semantics only where necessary for robust locators; prefer user-visible text/semantics when practical.
- Keep test data isolated from normal developer/user data.
- Document Android emulator, iOS Simulator, and physical-device commands separately.

### Phase 1 — emulator/simulator smoke flows

Cover stable app-owned UI first:

- first-run onboarding navigation;
- EN/TH language switching from the onboarding globe control;
- bottom navigation: Today / Medications / Settings;
- Settings profile age/sex persistence;
- Settings language persistence;
- Settings Theme row -> modal bottom sheet -> code-rendered preview -> select theme;
- selected theme persists across app restart;
- add medication -> configure time -> save -> medication appears in app state;
- Today screen shows the expected scheduled dose;
- Taken / Skip / Snooze user flows where deterministic without depending on OS notification delivery.

### Phase 2 — native permission flows

Keep native permission tests separate because OS versions and prior permission state affect behavior.

- Android notification permission;
- Android Alarms & reminders / exact-alarm special access;
- iOS notification permission;
- reopening OS App Settings after a denied permission;
- app resumes correctly after leaving for a system permission/settings screen.

Tests must reset or explicitly document prerequisite permission state. Do not make the entire fast CI suite depend on mutable system permission history.

### Phase 3 — reminder/device evidence

Physical-device validation should cover behavior that emulator/widget tests cannot prove:

- schedule a near-future medication reminder;
- background/lock the app;
- verify notification delivery;
- verify exact vs inexact Android behavior where applicable;
- reboot Android device and verify scheduled reminders are restored;
- timezone-change/resume rescheduling behavior;
- notification tap opens the expected Besyu destination when that navigation contract is implemented.

## CI strategy

Do not put every Patrol scenario into the normal fast PR gate initially.

Recommended split:

- `patrol-smoke`: deterministic emulator/simulator flows suitable for CI;
- `patrol-native`: permission/system UI flows on controlled runners/devices;
- `patrol-device`: explicit physical-device/manual-trigger evidence suite.

Keep the existing fast gates (`l10n-check`, format, analyze, unit/widget tests, Android debug build) intact.

A Patrol failure should provide useful screenshots/logs/artifacts where supported so failures are diagnosable without rerunning the full suite blindly.

## Testability requirements

Before writing a Patrol test for a flow, make the application state deterministic:

- provide an explicit test reset path for Hive boxes;
- avoid relying on wall-clock values unless the test controls the schedule window;
- do not depend on pre-existing medications/profile/settings;
- use stable medication names and schedule fixtures;
- isolate permission-sensitive scenarios from ordinary smoke tests;
- avoid fixed pixel coordinates where semantic/widget locators are available.

## Theme-system coverage

The Patrol milestone should explicitly validate the App Theme System added immediately before it:

1. Open Settings.
2. Confirm Theme is represented as one Settings item.
3. Open the theme modal.
4. Confirm all five presets are available:
   - Besyu Blue
   - Warm Sand
   - Sage Care
   - Lavender Calm
   - Midnight
5. Confirm each preset exposes a preview rendered by Flutter widgets/code rather than an image asset.
6. Select another preset and confirm the app updates live.
7. Restart the app and confirm the selected `app_theme_id` is restored.

The existing Dart/widget theme tests remain responsible for direct `ThemeData` contract assertions; Patrol verifies the real user flow.

## Out of scope for the first Patrol PR

- replacing existing widget/unit tests;
- exhaustive visual/golden coverage for every theme;
- full native companion implementation;
- cloud/device farm infrastructure unless required later;
- flaky sleep-based waiting where Patrol/native synchronization can be used instead.

## Acceptance criteria for Patrol foundation PR

- Patrol project configuration builds on supported Android/iOS test targets.
- At least one complete onboarding -> Home smoke flow passes.
- Settings Theme modal flow passes end to end.
- A medication can be created and observed from a user-visible screen.
- local app state can be reset deterministically between runs.
- fast CI remains independent from physical-device-only scenarios.
- Makefile commands and troubleshooting steps are documented.
- handoff and CODE_WALKTHROUGH are updated when the foundation lands.

## Physical-device boundary

Do not mark reminder delivery, reboot restoration, exact-alarm behavior, iOS permission behavior, or other native lifecycle behavior complete solely from emulator/widget evidence. Those items require recorded physical-device validation before being reported as complete.
