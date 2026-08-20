# Settings

## Overview

The Settings screen is available from the Home screen and contains three sections:

1. Profile
2. Permissions
3. About

All profile/settings data remains local to the device. The current baseline has no application server and does not upload the profile.

## Profile

The optional profile stores:

- `profile_age` — integer age from 1 through 120;
- `profile_sex` — one of `not_specified`, `female`, `male`, or `other`.

Both values are stored in the existing Hive `settings` box.

These values are **not used to calculate medication dose, diagnose a condition, or change a medication schedule automatically** in the current baseline. They are profile metadata only. Any future clinical logic that depends on age or sex requires a separately specified and validated medication-safety design.

## Permissions

The Settings screen gives the user a repeatable place to manage permission-related flows after onboarding.

### Notifications

`NotificationService.requestNotificationPermission()` is invoked only after the user taps the notification row. Permission prompts are never part of startup initialization.

### Precise reminders on Android

Android users can explicitly request Alarms & reminders / exact-alarm access through `NotificationService.requestExactAlarmPermission()`.

If exact-alarm access is not granted, scheduling continues with `AndroidScheduleMode.inexactAllowWhileIdle`.

### Camera and photos

Camera/photo access remains just-in-time: the app asks only when the user captures or selects a medication image. Settings explains this policy rather than pre-requesting those permissions.

### System app settings

`AppSettingsService` uses the MethodChannel `med_reminder/app_settings` to open the operating system's app settings page:

- Android: `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` for the current package;
- iOS: `UIApplication.openSettingsURLString`.

This allows a user who previously denied a permission to review or change it later without reinstalling the app.

## About

The About section states the application name/version and the offline/no-application-server baseline.

The displayed baseline version is currently `1.0.0`, matching `pubspec.yaml` `version: 1.0.0+1` at the time this document was written.
