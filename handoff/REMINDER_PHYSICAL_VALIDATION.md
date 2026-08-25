# Reminder Physical Validation

This protocol validates Besyu reminder reliability on physical Android and iOS devices without treating native notification queues as authoritative application data.

## Read-only probe

Run the diagnostic entrypoint against the same installed application id:

```bash
flutter run -t lib/reminder_reliability_probe_main.dart -d <device-id>
```

The probe prints a `BESYU_REMINDER_RELIABILITY_SNAPSHOT` JSON block and shows the same JSON on screen.

Captured fields:

- capture time in UTC;
- platform;
- local timezone identifier;
- pending native notification count;
- pending native notification IDs only;
- Android notification-enabled state;
- Android exact-alarm capability.

The probe intentionally does **not** emit notification titles, bodies, payloads, medication names, dose details, or repository data.

The probe is read-only. It initializes the notification plugin so native state can be queried, but it does not reconcile reminders and does not request permissions.

## Evidence naming

For each case, save the console JSON before and after the transition using a predictable name, for example:

```text
android_reboot_before.json
android_reboot_after_boot.json
android_reboot_after_launch.json
ios_long_idle_before.json
ios_long_idle_after.json
```

A screenshot is useful for OS permission/settings state, but the JSON snapshot is the primary queue evidence.

## Android matrix

### Reboot recovery

1. Launch normal Besyu and create at least one scheduled medication with a future reminder.
2. Run the probe and save the baseline snapshot.
3. Reboot the device without force-stopping Besyu first.
4. Before opening normal Besyu, run the probe again if the test workflow/device permits it and save the native-restored snapshot.
5. Launch normal Besyu, allow cold-launch reconciliation to complete, then run the probe again.
6. Verify future pending reminders remain represented after reconciliation and no duplicate IDs accumulate.

### Package replacement/update

1. Capture a baseline snapshot with future reminders present.
2. Install a newer debug build over the existing package without clearing app data.
3. Capture a snapshot before normal interaction if practical.
4. Launch normal Besyu and capture again after reconciliation.
5. Verify future schedules survive/repair without duplicate growth.

### Force-stop recovery

1. Capture a baseline snapshot.
2. Force-stop Besyu from Android System Settings.
3. Do not claim reminders will execute while force-stopped; Android may suppress alarms/notifications until relaunch.
4. Relaunch Besyu normally.
5. Capture a post-launch snapshot and verify reconciliation restores the expected pending set.

### Notification permission transition

1. Capture with notifications enabled.
2. Disable notifications in Android System Settings.
3. Resume Besyu normally so foreground state sampling runs.
4. Capture a snapshot; `notificationsEnabled` must reflect the disabled state.
5. Re-enable notifications, resume Besyu, and capture again.

### Exact-alarm transition

1. On an Android version/device exposing exact-alarm control, capture the baseline state.
2. Disable exact-alarm capability in System Settings.
3. Resume Besyu normally and capture; `exactAlarmsEnabled` must be false and reconciliation should use the inexact fallback.
4. Re-enable exact alarms, resume Besyu, and capture again.

### Timezone transition

1. Create reminders whose next occurrence is easy to verify.
2. Capture the current timezone and pending IDs.
3. Change the system timezone without editing medication data.
4. Resume Besyu normally.
5. Capture again and verify the reported timezone changed and the pending set was rebuilt without duplicate growth.

## iOS matrix

### Cold launch and foreground refill

1. Create finite courses large enough to exercise the 14-calendar-day scheduling projection.
2. Capture the pending count and IDs.
3. Terminate and relaunch Besyu.
4. Capture again and verify the pending set is stable and bounded by the current scheduling policy.

### Long-idle rolling-window refill

1. Create a finite course longer than the 14-day native window.
2. Capture a baseline snapshot.
3. Move the test date forward naturally or use a dedicated controlled test device/date workflow.
4. Resume Besyu after enough calendar days have passed to require refill.
5. Capture again and verify newly relevant future days are scheduled while stale days are absent.

### High medication/time-count pressure

This case decides whether a global pending-notification allocator is necessary.

1. Create a deliberately high number of scheduled medications and dose times while keeping test data non-sensitive.
2. Capture the pending count after reconciliation.
3. Verify whether all expected near-term reminders are represented and actually delivered.
4. Repeat after cold launch and foreground resume.
5. Only implement a global allocator if physical evidence shows per-course rolling windows still exceed usable iOS pending capacity or cause dropped reminders.

Do not infer a platform queue limit from the probe alone. Record the observed device/OS behavior and use current authoritative platform/plugin documentation before selecting any allocator budget.

## Acceptance criteria

A reliability case passes when:

- persistent medication data remains unchanged unless the test intentionally edits it;
- pending native IDs do not grow through accidental duplication after repair;
- permission/timezone state observed by the probe matches System Settings;
- scheduled/PRN semantics remain intact (PRN must not acquire scheduled notification IDs);
- force-stop behavior is documented as an Android platform limitation rather than reported as successful background recovery;
- any failure includes before/after snapshots and exact reproduction steps.
