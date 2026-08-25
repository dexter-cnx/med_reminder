# Reminder Physical Validation

This protocol validates Besyu reminder reliability on physical Android and iOS devices without treating notification-plugin state as authoritative application data.

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
- pending notification count and IDs returned by `flutter_local_notifications`;
- an explicit `pendingEvidenceKind` identifying what those pending values represent;
- Android notification-enabled state;
- Android exact-alarm capability.

The probe intentionally does **not** emit notification titles, bodies, payloads, medication names, dose details, or repository data.

The probe is read-only. It initializes the notification plugin so diagnostic state can be queried, but it does not reconcile reminders and does not request permissions.

### Android evidence limitation

On Android, `pendingNotificationRequests()` reflects the notification plugin's persisted scheduled-notification registry. It does **not** prove that the corresponding alarms currently exist in `AlarmManager`, survived reboot/package replacement, or will be delivered. The probe therefore labels Android pending data as `pluginPersistedScheduledNotificationRegistry` and emits a warning in the snapshot.

For Android reboot/package-replacement validation, plugin-registry snapshots are supporting evidence only. A pass also requires OS-level alarm evidence or observed delivery evidence. Prefer one of the following on a controlled test device:

- `adb shell dumpsys alarm` evidence scoped to the Besyu package before/after the transition, with sensitive unrelated output excluded from saved evidence; or
- a deliberately near-future non-sensitive test reminder whose actual delivery is observed after reboot/package replacement before normal Besyu reconciliation runs.

Do not mark Android reboot restoration as passed from unchanged plugin pending IDs alone.

## Evidence naming

For each case, save the probe JSON before and after the transition using a predictable name, for example:

```text
android_reboot_before.json
android_reboot_after_boot.json
android_reboot_after_launch.json
android_reboot_after_boot_alarm.txt
ios_long_idle_before.json
ios_long_idle_after.json
```

A screenshot is useful for OS permission/settings state. On iOS, pending-request snapshots can be used directly as queue evidence. On Android, save separate OS/delivery evidence for reboot/package-replacement claims.

## Android matrix

### Reboot recovery

1. Launch normal Besyu and create at least one non-sensitive scheduled test medication with a future reminder.
2. Run the probe and save the baseline plugin-registry snapshot.
3. Capture baseline OS alarm evidence with `adb shell dumpsys alarm` scoped to the Besyu package, or prepare a near-future delivery observation.
4. Reboot the device without force-stopping Besyu first.
5. Before opening normal Besyu, capture OS-level alarm evidence again or observe the prepared reminder delivery. Running the probe here is useful only to confirm the plugin registry survived; it is not sufficient to prove alarm restoration.
6. Launch normal Besyu, allow cold-launch reconciliation to complete, then run the probe again.
7. Verify reconciliation does not accumulate duplicate IDs and the post-launch schedule is healthy.

Pass condition before normal launch: at least one of the OS-level alarm evidence or actual delivery evidence confirms recovery. Unchanged plugin pending IDs alone are not a pass.

### Package replacement/update

1. Capture a baseline plugin-registry snapshot and OS alarm/delivery evidence with future reminders present.
2. Install a newer debug build over the existing package without clearing app data.
3. Before normal interaction, capture OS-level alarm evidence or observe a prepared near-future reminder. A probe snapshot may additionally confirm that the plugin registry survived.
4. Launch normal Besyu and capture again after reconciliation.
5. Verify future schedules survive/repair without duplicate growth.

### Force-stop recovery

1. Capture a baseline snapshot.
2. Force-stop Besyu from Android System Settings.
3. Do not claim reminders will execute while force-stopped; Android may suppress alarms/notifications until relaunch.
4. Relaunch Besyu normally.
5. Capture a post-launch snapshot and verify reconciliation restores the expected pending registry. Delivery behavior while force-stopped is not a pass criterion.

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
2. Capture the current timezone and pending plugin-registry IDs.
3. Change the system timezone without editing medication data.
4. Resume Besyu normally.
5. Capture again and verify the reported timezone changed and the registry was rebuilt without duplicate growth.

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
- pending IDs do not grow through accidental duplication after repair;
- permission/timezone state observed by the probe matches System Settings;
- Android reboot/package-replacement claims include OS-level alarm or actual delivery evidence, not plugin-registry IDs alone;
- scheduled/PRN semantics remain intact (PRN must not acquire scheduled notification IDs);
- force-stop behavior is documented as an Android platform limitation rather than reported as successful background recovery;
- any failure includes before/after snapshots, the required platform evidence, and exact reproduction steps.
