# Besyu Settings

## Overview

Settings is a top-level destination in the bottom navigation alongside Today and Medications. It contains four sections:

1. Language
2. Profile
3. Permissions
4. About

All profile/settings data remains local to the device. Besyu has no application server in the current baseline.

## Language

Besyu currently supports English (`en`) and Thai (`th`).

Startup policy:

- if `language_code` has never been stored, Besyu follows the device locale;
- if the device locale is unsupported, Besyu falls back to English;
- once the user explicitly chooses English or Thai in Settings, that language code is stored in the Hive `settings` box and becomes the startup override;
- there is intentionally no visible `System default` choice in Settings.

`EasyLocalization` internal locale persistence is disabled (`saveLocale: false`) so Hive remains the single persistence source for the explicit language choice.

## Profile

The optional profile stores:

- `profile_age` — integer age from 1 through 120;
- `profile_sex` — one of `not_specified`, `female`, `male`, or `other`.

Both values are stored in the existing Hive `settings` box.

These values are **not used to calculate medication dose, diagnose a condition, or change a medication schedule automatically** in the current baseline. They are profile metadata only.

## Permissions

Settings gives the user a repeatable place to manage permission-related flows after onboarding.

### Notifications

`NotificationService.requestNotificationPermission()` is invoked only after an explicit user action. Permission prompts are never part of startup initialization.

### Precise reminders on Android

Android users can explicitly request Alarms & reminders / exact-alarm access through `NotificationService.requestExactAlarmPermission()`.

If exact-alarm access is not granted, scheduling continues with `AndroidScheduleMode.inexactAllowWhileIdle`.

### Camera and photos

Camera/photo access remains just-in-time: the app asks only when the user captures or selects a medication image. Settings explains this policy rather than pre-requesting those permissions.

### System app settings

`AppSettingsService` uses the MethodChannel `med_reminder/app_settings` to open the operating system's app settings page:

- Android: `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` for the current package;
- iOS: `UIApplication.openSettingsURLString`.

## About

The product identity is:

- **Besyu**
- **Beside You.**
- **อยู่ข้างกาย ในทุกวัน**

The About section also states the application version and offline/no-application-server baseline.
