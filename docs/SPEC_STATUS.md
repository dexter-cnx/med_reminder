# Spec Status

| Area | Status | Notes |
|---|---|---|
| Offline Hive storage | Implemented | `meds` + `logs` behind repository/data-source abstractions |
| Single CSV localization | Implemented | header auto-detect + English fallback |
| Persistent package photo | Implemented | copied to app documents; deletion removes owned file |
| Multiple doses per day | Implemented | per-`scheduledAt` dose log |
| Remaining stock | Implemented | `initialAmount - takenCount * dosagePerTime`; skipped/snoozed do not consume stock |
| Forever reminders | Implemented | daily timezone-aware schedule |
| N-day reminders | Implemented | finite one-shot schedules |
| Until-empty reminders | Implemented | recurring reminders cancelled from DoseLog-derived remaining stock |
| Android reboot restore | Implemented in platform bootstrap | plugin `ScheduledNotificationBootReceiver` + `RECEIVE_BOOT_COMPLETED` |
| Timezone changes | Implemented | app-resume timezone detection + full active-reminder reschedule |
| In-app Taken/Skip/Snooze | Implemented | snooze = 10 minutes |
| Low-stock notification | Implemented | threshold crossing from DoseLog-derived remaining stock |
| iOS Live Activity | Handoff | Widget Extension/App Group/channel wiring + physical-device test required |
| watchOS sync | Handoff | WatchConnectivity target required |
| Android native ongoing UI | Handoff | `MainActivity.kt`/plugin wiring and real-device screenshot evidence required |
| Wear OS sync | Handoff | Wear Data Layer target required |
| Notification action buttons | Deferred | background-safe state mutation not yet wired |
