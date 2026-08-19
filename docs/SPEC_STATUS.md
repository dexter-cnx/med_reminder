# Spec Status

| Area | Status | Notes |
|---|---|---|
| Offline Hive storage | Implemented | `meds` + `logs` behind repository/data-source abstractions |
| Repository errors | Implemented | core `Result<T>` / `Failure`; Hive/mapper exceptions do not leak through repository contracts |
| CSV localization source | Implemented | `assets/translations.csv` remains the single editable source and is not bundled at runtime |
| Generated JSON localization | Implemented | compact per-locale JSON + generated locale list; runtime never parses CSV |
| CSV validation | Implemented | CI checks duplicate keys, empty fallback/rows, placeholder mismatch, and stale generated output |
| Persistent package photo | Implemented | copied to app documents; deletion removes owned file |
| Photo orphan cleanup | Implemented | startup prune after successful medication repository read |
| Multiple doses per day | Implemented | per-`scheduledAt` dose log |
| Immutable domain | Implemented | final fields + defensive unmodifiable collection copies |
| Remaining stock | Implemented | `initialAmount - takenCount * dosagePerTime`; skipped/snoozed do not consume stock |
| Forever reminders | Implemented | daily timezone-aware schedule |
| N-day reminders | Implemented | finite one-shot schedules |
| Until-empty reminders | Implemented | recurring reminders cancelled from DoseLog-derived remaining stock |
| Android reboot restore | Implemented in platform bootstrap | plugin `ScheduledNotificationBootReceiver` + `RECEIVE_BOOT_COMPLETED` |
| Timezone changes | Implemented | app-resume timezone detection + medication/log-aware reschedule |
| In-app Taken/Skip/Snooze | Implemented | snooze = 10 minutes |
| Low-stock notification | Implemented | threshold crossing from DoseLog-derived remaining stock |
| iOS Live Activity | Handoff | Widget Extension/App Group/channel wiring + Android/iOS evidence matrix required |
| watchOS sync | Handoff | WatchConnectivity target required |
| Android native ongoing UI | Handoff | `MainActivity.kt`/plugin wiring and real-device screenshot evidence required |
| Wear OS sync | Handoff | Wear Data Layer target required |
| Notification action buttons | Deferred | background-safe state mutation not yet wired |
