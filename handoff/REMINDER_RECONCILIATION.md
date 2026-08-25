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
- PRN/as-needed, expired, and empty `untilEmpty` medications are not scheduled.

## Reliability invariants

1. A lifecycle trigger must not run multiple reconciliation transactions concurrently.
2. A medication/dose mutation that overlaps reconciliation must force a queued rerun.
3. A transient native scheduling failure gets an immediate retry before lifecycle repair is considered finished.
4. Reconciliation never persists its stale source collection over newer medication mutations.
5. Schedules created for a medication that changed or disappeared during reconciliation are cancelled.
6. Notification IDs remain rebuildable derived state; medication and dose-log repositories remain the source of truth.

## Next slices

1. Detect timezone/system-setting changes and route them through the same reconciliation controller.
2. Reconcile after notification/exact-alarm permission changes where platform APIs expose the transition.
3. Validate reboot, force-stop recovery, timezone changes, and long-idle behavior on physical Android/iOS devices.
4. Define and validate the rolling scheduling-window policy before relying on bounded future schedules for long-idle devices.
