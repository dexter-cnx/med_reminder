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

### Screenshot evidence

No screenshot is committed yet because the Android fallback is not wired to a device build. Do **not** use a design mock as validation evidence. After native wiring, capture and commit a real-device screenshot showing the fallback ongoing notification and link it here.

Suggested evidence path:

`docs/evidence/android-ongoing-notification.png`

## Wear OS

Use the Wearable Data Layer (`DataClient`) to send compact medication state to the watch app. Define a versioned payload and verify reconnect/update behavior on a physical Wear OS device before marking complete.

## Notification actions

System-tray actions such as Taken/Snooze/Skip are not enabled in the current baseline because correct handling requires a background-safe callback path that can update persistent dose state. The in-app Taken/Snooze/Skip behavior is implemented now; notification actions should only be marked complete after foreground/background/terminated-state tests pass.
