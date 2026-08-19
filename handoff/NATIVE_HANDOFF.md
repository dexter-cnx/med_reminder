# Native Handoff

Native companion features are intentionally separated from the tested Flutter baseline.

## iOS Live Activity / Dynamic Island

1. Bootstrap the iOS project.
2. Add a Widget Extension target named `MedWidgets`.
3. Enable ActivityKit and the required App Group for both Runner and extension.
4. Move/adapt `handoff/ios/MedWidgetsLiveActivity.swift` into the extension target.
5. Wire `med_reminder/live_activity` in `AppDelegate.swift` for `start`, `update`, and `end`.
6. Validate on a supported physical iPhone.

## watchOS

Create a watch target and wire `WCSession`. The Flutter method channel `med_reminder/watch_sync` should pass a compact medication snapshot to the iOS host, which then transfers it through WatchConnectivity. No server is required.

## Android ongoing experience / Wear OS

Wire `med_reminder/live_activity` in `MainActivity` or a dedicated plugin. For Wear OS, use the Wearable Data Layer (`DataClient`) to send compact medication state to the watch app. This work remains handoff scope until device-tested.

## Notification actions

System-tray actions such as Taken/Snooze/Skip are not enabled in the current baseline because correct handling requires a background-safe callback path that can update persistent dose state. The in-app Taken/Snooze/Skip behavior is implemented now; notification actions should only be marked complete after foreground/background/terminated-state tests pass.
