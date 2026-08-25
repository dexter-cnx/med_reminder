# Reminder Reconciliation

## Status

Medication reminder reconciliation is now a medication-level repair path rather than a backup-specific operation.

Current behavior:

- persistent medication and dose-log data remain authoritative;
- OS notification IDs are derived operational state;
- Home triggers reconciliation after first operational mount and on app resume;
- interactive reminder-affecting mutations (take, skip, snooze, medication add/delete, and refill) trigger the same reconciliation controller after persistence;
- overlapping triggers are coalesced into one queued rerun so a mutation that lands during lifecycle repair is reconciled from the latest state afterward;
- lifecycle repair retries once immediately after a failed reconciliation before giving up for that trigger;
- partial schedules created by a failing per-medication native scheduling call are cancelled before the failure escapes;
- medication collection changes during reconciliation are merged against the latest repository state so newly added medications are not deleted and removed medications are not resurrected;
- PRN/as-needed, expired, and empty `untilEmpty` medications are not scheduled;
- foreground system refresh reads timezone state before reconciliation instead of calling the legacy `rescheduleAll()` path directly;
- notification-permission and Android exact-alarm permission requests reconcile after the native permission API returns, regardless of whether permission was granted or denied, so the current scheduling mode is reflected immediately;
- Android foreground refresh reads `areNotificationsEnabled()` and `canScheduleExactNotifications()` before reconciliation, so permission changes made in System Settings are observed without requiring another in-app permission request;
- Android exact-alarm capability is projected into `AndroidScheduleMode.exactAllowWhileIdle` or `inexactAllowWhileIdle` before schedules are rebuilt;
- finite `MedicationMode.days` courses are projected into a 14-calendar-day rolling native scheduling window before reaching `NotificationService`;
- in-progress finite courses restart their scheduling projection from the current calendar date while preserving the original persisted course definition;
- future finite courses consume the days before their start from the same 14-day horizon, and courses starting outside the horizon are not scheduled yet;
- `forever` and `untilEmpty` schedules retain their repeating-notification behavior and are not expanded into per-day future notifications.

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
10. Finite courses must never expand unboundedly into native pending notifications; only the configured rolling calendar window may be scheduled.
11. Rolling-window projection must never rewrite the persisted medication course start date or duration.
12. Calendar-day calculations must not depend on elapsed wall-clock hours, so DST transitions cannot move a finite course by one day.

## Next slices

1. Validate reboot, force-stop recovery, timezone changes, permission transitions, rolling-window refill, and long-idle behavior on physical Android/iOS devices.
2. Add Android boot/package-replaced integration where app-owned native receivers are still required beyond the notification plugin's own rescheduling receiver behavior.
3. Add global pending-notification budget allocation if physical iOS validation shows that per-course rolling windows can still exceed the platform queue under high medication/time counts.
4. Consider consolidating duplicate resume observers after physical lifecycle validation confirms ordering across supported platforms.
