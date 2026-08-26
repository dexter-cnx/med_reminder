# Reminder Reconciliation

## Status

Medication reminder reconciliation is now a medication-level repair path rather than a backup-specific operation.

Current behavior:

- persistent medication and dose-log data remain authoritative;
- OS notification IDs are derived operational state;
- Home triggers reconciliation once after first operational mount to repair cold-launch state;
- `BesyuApp` is the single foreground lifecycle owner: resume refreshes timezone and platform permission/capability state before reconciliation;
- interactive reminder-affecting mutations (take, skip, snooze, medication add/delete, and refill) trigger the same reconciliation controller after persistence;
- overlapping triggers are coalesced into one queued rerun so a mutation that lands during lifecycle repair is reconciled from the latest state afterward;
- lifecycle repair retries once immediately after a failed reconciliation before giving up for that trigger;
- runtime reconciliation and backup reminder rebuild now execute through the same reminder transaction core;
- backup restore keeps its `backup_restore_*` failure semantics while inheriting the same scheduling, concurrency merge, cleanup, and persistence rules as runtime reconciliation;
- partial schedules created by a failing per-medication native scheduling call are cancelled before the failure escapes;
- medication collection changes during reconciliation are merged against the latest repository state so newly added medications are not deleted and removed medications are not resurrected;
- PRN/as-needed, expired, and empty `untilEmpty` medications are not scheduled, including after backup restore;
- foreground system refresh reads timezone state before reconciliation instead of calling the legacy `rescheduleAll()` path directly;
- notification-permission and Android exact-alarm permission requests reconcile after the native permission API returns, regardless of whether permission was granted or denied, so the current scheduling mode is reflected immediately;
- Android foreground refresh reads `areNotificationsEnabled()` and `canScheduleExactNotifications()` before reconciliation, so permission changes made in System Settings are observed without requiring another in-app permission request;
- Android exact-alarm capability is projected into `AndroidScheduleMode.exactAllowWhileIdle` or `inexactAllowWhileIdle` before schedules are rebuilt;
- Android native reminder recovery relies on `flutter_local_notifications`' `ScheduledNotificationBootReceiver` for reboot/package-replace restoration, with `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`, and HTC quick-boot actions declared in the app manifest;
- `RECEIVE_BOOT_COMPLETED` and both plugin notification receivers are protected by regression tests so manifest refactors cannot silently remove reboot recovery;
- finite `MedicationMode.days` courses are projected into a 14-calendar-day rolling native scheduling window before reaching `NotificationService`;
- in-progress finite courses restart their scheduling projection from the current calendar date while preserving the original persisted course definition;
- future finite courses consume the days before their start from the same 14-day horizon, and courses starting outside the horizon are not scheduled yet;
- `forever` and `untilEmpty` schedules retain their repeating-notification behavior and are not expanded into per-day future notifications;
- a dedicated read-only physical-device probe can snapshot timezone, native pending notification IDs/count, and Android notification/exact-alarm capability without emitting medication names, notification content, or repository health data;
- the physical validation matrix is documented in `handoff/REMINDER_PHYSICAL_VALIDATION.md` and is the evidence gate before introducing platform-specific global notification-budget policy.

## Reliability invariants

1. A lifecycle trigger must not run multiple reconciliation transactions concurrently.
2. A medication/dose mutation that overlaps reconciliation must force a queued rerun.
3. A transient native scheduling failure gets an immediate retry before lifecycle repair is considered finished.
4. Reconciliation never persists its stale source collection over newer medication mutations.
5. Schedules created for a medication that changed or disappeared during reconciliation are cancelled.
6. Notification IDs remain rebuildable derived state; medication and dose-log repositories remain the source of truth.
7. Timezone and permission transitions must route through the same reconciliation controller rather than independent scheduling code.
8. Permission request results must be preserved for onboarding UX while reconciliation repairs derived notification state afterward.
9. External Android notification/exact-alarm permission changes must be sampled before foreground reconciliation so the rebuilt schedule uses current platform capability.
10. Android reboot/package-replace recovery must retain the plugin boot receiver, its supported system broadcast actions, and `RECEIVE_BOOT_COMPLETED` permission.
11. Finite courses must never expand unboundedly into native pending notifications; only the configured rolling calendar window may be scheduled.
12. Rolling-window projection must never rewrite the persisted medication course start date or duration.
13. Calendar-day calculations must not depend on elapsed wall-clock hours, so DST transitions cannot move a finite course by one day.
14. Foreground reminder repair has one lifecycle owner. `HomeScreen` may perform cold-launch repair after mount but must not register its own resume observer.
15. Backup reminder rebuild must not maintain an independent scheduling algorithm; it must reuse the medication reminder transaction core so PRN and future scheduling rules cannot drift.
16. Physical reliability diagnostics must remain read-only and metadata-only: no permission mutation, reconciliation, medication names, notification title/body/payload, or repository health data may be emitted by the probe.
17. A global pending-notification allocator must be justified by physical iOS evidence rather than an assumed queue limit.

## Recovery model

Android reboot/package replacement does not start the Flutter application to perform repository-level reconciliation. Instead, the notification plugin restores its persisted native schedules through `ScheduledNotificationBootReceiver`. The next Besyu cold launch or foreground transition then runs the application reconciliation path and re-derives the authoritative schedule from medication/dose-log storage, including rolling-window refill and current permission/timezone state.

Android force-stop remains a platform limitation: alarms/notifications may be suppressed until the user launches the app again. Besyu repairs reminder state on that next launch/resume rather than claiming background recovery while force-stopped.

## Physical validation

Run the read-only probe on a physical device with:

```bash
flutter run -t lib/reminder_reliability_probe_main.dart -d <device-id>
```

The full reboot, package replacement, force-stop, permission, timezone, rolling-window, long-idle, and high queue-pressure procedure is maintained in `handoff/REMINDER_PHYSICAL_VALIDATION.md`.

## Next slices

1. Execute the physical validation matrix on Android and iOS and retain before/after JSON snapshots for each case.
2. Add a global pending-notification budget allocator only if physical iOS evidence shows that per-course rolling windows still cause dropped or unavailable near-term reminders under high medication/time counts.
3. If physical validation reveals platform-specific ordering or recovery gaps, repair the shared reconciliation/system-trigger path first rather than adding parallel scheduling logic.
