# Native Handoff

Native companion features are intentionally separated from the tested Flutter baseline.

## iOS host lifecycle baseline

The current Runner deliberately uses the classic `FlutterAppDelegate` lifecycle and does **not** contain `UIApplicationSceneManifest`.

During physical-device bootstrap validation with the Flutter 3.47 baseline, the generated UIScene host built successfully and started the Dart VM, but UIKit could not resolve `Runner.SceneDelegate` at runtime. The device therefore showed a black screen while Xcode reported:

```text
could not load class with name "Runner.SceneDelegate"
There is no scene delegate set.
flutter: The Dart VM service is listening on ...
```

Reverting Runner to classic `FlutterAppDelegate` + `UIMainStoryboardFile = Main` restored rendering on the physical iPhone.

This is documented in detail in `docs/iphone_black_screen_issue.md`. Do not reintroduce UIScene as incidental generated-project churn. If PR #2 or a later Flutter baseline requires UIScene, make it an explicit migration and validate Debug/Profile first frame on a physical iPhone before keeping it.

## iOS Live Activity / Dynamic Island

Requirements:

1. Start from the current validated classic iOS host. Do not silently replace it with a generated UIScene manifest.
2. Set the Runner deployment target as required by the app, and set the Live Activity Widget Extension deployment target to **iOS 16.1+**.
3. Add a Widget Extension target named `MedWidgets` with Live Activity support.
4. Enable the same App Group (planned: `group.med.reminder`) for Runner and `MedWidgets`.
5. Add the App Group entitlement to both targets and ensure signing/provisioning includes it.
6. Add the ActivityKit attributes/content state implementation to the extension target.
7. Wire MethodChannel `med_reminder/live_activity` in `AppDelegate.swift` for `start`, `update`, and `end` without breaking the validated application lifecycle.
8. Validate start/update/end, lock-screen presentation, Dynamic Island presentation, app termination, and reboot behavior on a supported physical iPhone.
9. If native changes require UIScene, validate scene-class runtime resolution and the Flutter first frame separately before testing Live Activity behavior.

Do not mark Live Activity complete from a simulator-only run.

## watchOS

1. Add a watchOS app/extension target.
2. Activate `WCSession` on both phone and watch sides.
3. Wire Flutter MethodChannel `med_reminder/watch_sync` to the iOS host.
4. Transfer a compact medication snapshot using WatchConnectivity (`updateApplicationContext` or `transferUserInfo` depending on delivery semantics).
5. Verify disconnected/reconnected phone-watch behavior and duplicate delivery handling.

No server is required for the baseline watch sync.

## Local reminder scheduling and reboot recovery

Medication reminders must remain **local-first**. The persistent reminder records in the local database are the source of truth; OS-level scheduled alarms/notifications are derived state that may be rebuilt at any time.

Target architecture:

```text
Local reminder DB (source of truth)
        ↓
ReminderScheduler / ReminderReconciler
        ↓
OS scheduled notifications / alarms
```

The scheduling contract should remain platform-agnostic, for example:

```dart
abstract interface class ReminderScheduler {
  Future<void> reconcile();
  Future<void> schedule(Reminder reminder);
  Future<void> cancel(String reminderId);
  Future<void> cancelAll();
}
```

`reconcile()` must be idempotent. Re-running it must not create duplicate dose notifications. Notification/alarm identifiers should be deterministically derived from stable reminder/occurrence identifiers so obsolete schedules can be cancelled and active schedules recreated safely.

### Android reboot recovery

`flutter_local_notifications` currently owns Android alarm restoration. The Android manifest must contain:

- `android.permission.POST_NOTIFICATIONS` for Android 13+ runtime notification permission;
- `android.permission.SCHEDULE_EXACT_ALARM` for the exact-alarm permission path;
- `android.permission.RECEIVE_BOOT_COMPLETED`;
- `ScheduledNotificationReceiver`;
- `ScheduledNotificationBootReceiver`;
- boot/package-replaced/quick-boot intent filters.

`tool/bootstrap_platforms.sh` installs the plugin receiver declarations. A separate WorkManager task is intentionally not added while the plugin receiver is sufficient.

After reboot, Android must restore active future reminder schedules from persistent reminder data. Treat restored plugin alarms as an optimization, not as the only recovery path. The application should also reconcile reminder state after launch/resume so the local database can repair stale, missing, duplicated, or obsolete OS schedules.

Required reconcile triggers:

1. Android boot completion / quick boot where supported.
2. App package replacement/update (`MY_PACKAGE_REPLACED`) where applicable.
3. App cold launch.
4. App resume/foreground transition when reminder state or relevant system settings may have changed.
5. Reminder create/update/delete.
6. Timezone/time-setting change when detected or on the next foreground reconciliation.
7. Notification or exact-alarm permission changes when detected or on the next foreground reconciliation.

The current app falls back to `AndroidScheduleMode.inexactAllowWhileIdle` if exact-alarm permission is not granted, so reminder functionality must not depend on exact alarms being available. The UI may explain reduced timing precision when exact scheduling is unavailable, but medication reminders must continue to function.

Android force-stop is a distinct system state: if the user explicitly uses Settings → Apps → Force stop, the OS may suppress alarms/receivers until the user launches the app again. On the next launch, run a full reconciliation immediately.

### iOS reboot behavior

iOS scheduled local notifications are managed by the OS and normally survive app termination and device restart; there is no Android-style boot receiver. Still, do not assume the pending notification queue is permanently authoritative.

Run reconciliation on app launch/resume and after reminder/timezone changes so the local database remains the source of truth. Reconciliation should query pending requests when practical, remove obsolete requests, and replenish the desired future window.

### Rolling scheduling window

Do not schedule an unbounded number of future medication occurrences. Use a rolling window so schedule count stays bounded and compatible with platform limits, especially iOS pending-notification limits.

Recommended initial policy:

- schedule approximately **7–30 days** ahead;
- choose the exact window through configuration so it can be tuned without domain changes;
- replenish the window on launch/resume and after reminder mutations;
- always prioritize the nearest upcoming dose occurrences;
- never rely on a year-long or effectively infinite pre-scheduled notification list.

If the user does not open the app for longer than the rolling window, recurring reminder strategy must still avoid silently losing critical reminders. Before implementation is considered complete, validate whether the selected notification plugin/platform recurrence APIs can safely cover that case; otherwise extend the window or add a background-safe replenishment mechanism with explicit platform validation.

### Reconciliation correctness requirements

The reconciler must handle at least:

- device reboot;
- app update/reinstall boundary where persistent app data remains available;
- timezone changes;
- manual clock changes where platform APIs expose the event;
- daylight-saving transitions in supported locales;
- reminder edits/deletes;
- notification permission revocation/restoration;
- exact-alarm permission denied/restored on Android;
- duplicate scheduling attempts;
- past occurrences after a long period without opening the app.

Past dose occurrences must never be recreated as future alarms merely because reconciliation runs after reboot or resume.

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

- Android 13: notification permission, scheduled reminder, reboot restore, exact/inexact alarm behavior, ongoing fallback notification.
- Android 14: notification permission, exact-alarm permission path, reboot restore, ongoing fallback notification.
- iOS 17: local reminder, timezone-change reschedule, Live Activity start/update/end, lock screen and Dynamic Island where supported.
- iOS 18: the same Live Activity and local-reminder lifecycle checks, including foreground/background/terminated transitions.
- Current physical-iPhone toolchain: app first-frame launch remains healthy after any native host changes; no `SceneDelegate` resolution regression.

A newer OS version may be added, but it does not replace the minimum matrix above unless this document is intentionally revised.

For reminder reliability, add explicit device tests for:

- reminder fires with app foregrounded, backgrounded, and terminated;
- reminder still fires after normal device reboot;
- cold launch after reboot performs reconciliation without duplicate notifications;
- app update/package replacement preserves/restores active reminders;
- timezone change moves wall-clock reminders according to the selected product semantics;
- exact-alarm denial on Android falls back without silently disabling reminders;
- long-idle/rolling-window behavior does not silently exhaust future reminders.

## Evidence checklist before PR #2 can be called complete

Create `docs/evidence/` and commit real-device evidence for each applicable item:

- `android-13-reminder.png` — scheduled reminder visible on a physical Android 13 device.
- `android-13-reboot.md` — device/model, reboot steps, expected schedule, actual delivery result.
- `android-14-reminder.png` — Android 14 permission/alarm path validated.
- `android-ongoing-notification.png` — native ongoing fallback notification from the real app build.
- `ios-17-live-activity.png` — lock-screen or Dynamic Island Live Activity from a physical iOS 17 device.
- `ios-18-live-activity.png` — equivalent evidence on iOS 18.
- `timezone-reschedule.md` — before/after IANA timezone, configured local dose time, and observed rescheduled delivery.
- `ios-host-launch.md` — Flutter/toolchain version, device/OS, lifecycle configuration, first-frame result, and confirmation that the prior black-screen signature is absent.
- `native-test-matrix.md` — device model, OS version, app commit SHA, pass/fail for every required scenario.

Do **not** use design mocks, simulator-only screenshots, or screenshots from another app as validation evidence.

## Wear OS

Use the Wearable Data Layer (`DataClient`) to send compact medication state to the watch app. Define a versioned payload and verify reconnect/update behavior on a physical Wear OS device before marking complete.

## Notification actions

System-tray actions such as Taken/Snooze/Skip are not enabled in the current baseline because correct handling requires a background-safe callback path that can update persistent dose state. The in-app Taken/Snooze/Skip behavior is implemented now; notification actions should only be marked complete after foreground/background/terminated-state tests pass.
