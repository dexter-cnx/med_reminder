# SOS Call/SMS Handoff

## Scope

This slice introduces the first actionable SOS entry point after the Emergency Medical Card flow became stable.

Implemented:

- Persistent SOS entry in the Home app bar.
- Secondary SOS entry from the Emergency Medical Card app bar.
- SOS action sheet reading the user-entered emergency contact from `EmergencyProfile`.
- Explicit Call and SMS actions.
- `EmergencyContactLauncher` application contract.
- `UrlLauncherEmergencyContactLauncher` platform adapter using `tel:` and `sms:` URI schemes.

## Safety and UX

Pressing the SOS entry does not immediately place a call or send a message.

The user must first open the SOS sheet and then explicitly choose Call or SMS. Besyu delegates the final action to the operating system using the device Phone/Messages application.

No Contacts permission is requested. The number comes only from the emergency contact that the user entered into Besyu.

If no emergency contact phone number is configured, Call and SMS actions are disabled.

## Architecture

Presentation code depends on `EmergencyContactLauncher`; URI launching is isolated in a platform adapter. This keeps the Emergency feature from binding its application logic directly to `url_launcher`.

`url_launcher` is pinned to `6.3.0` so this slice does not silently raise the project's declared Dart SDK floor from `>=3.2.0`.

## Privacy

- No emergency contact value is sent to analytics.
- No call/SMS content is recorded by Besyu.
- No contacts address-book access is introduced.
- Emergency profile data remains local-first.

## Deferred

LINE voice/video/chat actions remain separate. They should only be added after verifying the current official LINE URI/deep-link capabilities and platform behavior. Do not assume third-party or legacy URL schemes are stable enough for emergency UX.

A later platform-hardening slice may also add capability/error reporting for devices without handlers for `tel:` or `sms:`.
