# Native Handoff

Native companion features are intentionally separated from the tested Flutter baseline.

## iOS Live Activity / Dynamic Island

Requirements:

1. Bootstrap the iOS project with `./tool/bootstrap_platforms.sh`.
2. Set the Runner deployment target as required by the app, and set the Live Activity Widget Extension deployment target to **iOS 16.1+**.
3. Add a Widget Extension target named `MedWidgets` with Live Activity support.
4. Enable the same App Group (planned: `group.med.reminder`) for Runner and `MedWidgets`.
5. Add the App Group entitlement to both targets and ensure signing/provisioning includes it.
6. Add the ActivityKit attributes/content state implementation to the extension target.
7. Wire MethodChannel `med_reminder/live_activity` in `AppDelegate.swift` for `start`, `update`, and `end`.
8. Validate start/update/end, lock-screen presentation, Dynamic Island presentation, app termination, and reboot behavior on a supported physical iPhone.

Do not mark Live Activity complete from a simulator-only run.

## watchOS

1. Add a watchOS app/extension target.
2. Activate `WCSession` on both phone and watch sides.
3. Wire Flutter MethodChannel `med_reminder/watch_sync` to the iOS host.
4. Transfer a compact medication snapshot using WatchConnectivity (`updateApplicationContext` or `transferUserInfo` depending on delivery semantics).
5. Verify disconnected/reconnected phone-watch behavior and duplicate delivery handling.

No server is required for the baseline watch sync.

## Android scheduled reminders after reboot

`flutter_local_notifications` owns alarm restoration. The Android manifest must contain:

- `android.permission.RECEIVE_BOOT_COMPLETED`
- `ScheduledNotificationReceiver`
- `ScheduledNotificationBootReceiver`
- boot/package-replaced/quick-boot intent filters

`tool/bootstrap_platforms.sh` installs these declarations. A separate WorkManager task is intentionally not added while the plugin receiver is sufficient.

## Android ongoing notification / Live Activity fallback

Android does not use iOS ActivityKit. The planned fallback is an ongoing/high-importance medication notification driven by native Android code.

Required native wiring:

1. Add the actual MethodChannel handler in `MainActivity.kt` (or move it into a dedicated Flutter plugin).
2. Handle `start`, `update`, and `end` methods from `med_reminder/live_activity`.
3. Create/update/cancel the ongoing notification using a dedicated notification channel.
4. Keep local scheduled dose notifications separate from the ongoing status notification.
5. Add Wear OS Data Layer integration only after the phone-side contract is stable.

## Required real-device validation matrix

PR #2 must not mark native companion work complete until the following physical-device matrix has evidence:

- Android 13: scheduled reminder, reboot restore, exact/inexact alarm behavior, ongoing fallback notification.
- Android 14: notification permission, exact-alarm permission path, reboot restore, ongoing fallback notification.
- iOS 17: local reminder, timezone-change reschedule, Live Activity start/update/end, lock screen and Dynamic Island where supported.
- iOS 18: the same Live Activity and local-reminder lifecycle checks, including foreground/background/terminated transitions.

A newer OS version may be added, but it does not replace the minimum matrix above unless this document is intentionally revised.

## Evidence checklist before PR #2 can be called complete

Create `docs/evidence/` and commit real-device evidence for each applicable item:

- `android-13-reminder.png` — scheduled reminder visible on a physical Android 13 device.
- `android-13-reboot.md` — device/model, reboot steps, expected schedule, actual delivery result.
- `android-14-reminder.png` — Android 14 permission/alarm path validated.
- `android-ongoing-notification.png` — native ongoing fallback notification from the real app build.
- `ios-17-live-activity.png` — lock-screen or Dynamic Island Live Activity from a physical iOS 17 device.
- `ios-18-live-activity.png` — equivalent evidence on iOS 18.
- `timezone-reschedule.md` — before/after IANA timezone, configured local dose time, and observed rescheduled delivery.
- `native-test-matrix.md` — device model, OS version, app commit SHA, pass/fail for every required scenario.

Do **not** use design mocks, simulator-only screenshots, or screenshots from another app as validation evidence.

## Wear OS

Use the Wearable Data Layer (`DataClient`) to send compact medication state to the watch app. Define a versioned payload and verify reconnect/update behavior on a physical Wear OS device before marking complete.

## Notification actions

System-tray actions such as Taken/Snooze/Skip are not enabled in the current baseline because correct handling requires a background-safe callback path that can update persistent dose state. The in-app Taken/Snooze/Skip behavior is implemented now; notification actions should only be marked complete after foreground/background/terminated-state tests pass.
