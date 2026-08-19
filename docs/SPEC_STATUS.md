# Spec Status

| Area | Status | Notes |
|---|---|---|
| Offline Hive storage | Implemented | `meds` + `logs` |
| Single CSV localization | Implemented | header auto-detect + English fallback |
| Persistent package photo | Implemented | copied to app documents |
| Multiple doses per day | Implemented | per-`scheduledAt` dose log |
| Forever reminders | Implemented | daily timezone-aware schedule |
| N-day reminders | Implemented | finite one-shot schedules |
| Until-empty reminders | Implemented | daily recurring, cancelled at zero stock |
| In-app Taken/Skip/Snooze | Implemented | snooze = 10 minutes |
| Low-stock notification | Implemented | threshold crossing |
| iOS Live Activity | Handoff | target/channel wiring + device test required |
| watchOS sync | Handoff | WatchConnectivity target required |
| Android native ongoing UI | Handoff | native host wiring required |
| Wear OS sync | Handoff | Wear Data Layer target required |
| Notification action buttons | Deferred | background-safe state mutation not yet wired |
