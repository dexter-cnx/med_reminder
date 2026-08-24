# Emergency Medical Card

## Status

The Emergency feature is now wired end to end as a local-first feature boundary.

Implemented:

- `EmergencyProfile` aggregate for user-entered emergency information.
- Repository and local-data-source contracts.
- Dedicated Hive-backed local persistence wired through app DI.
- `EmergencyMedicalCard` read model that composes current medications at read time.
- Riverpod provider/view-model state.
- Dedicated read-only Emergency Medical Card presentation.
- Separate `EmergencyProfileSettingsScreen` for editing and explicit clear/delete.
- Emergency profile entry from the application's main Settings surface.
- Focused widget coverage for the read-only card vs settings mutation boundary.
- SOS entry points from Home and the Emergency Medical Card.
- Call/SMS handoff through an `EmergencyContactLauncher` abstraction and native platform channel.

LINE direct-contact voice/video calling is not implemented because LINE's public URL scheme does not expose a supported direct friend voice/video-call deep link.

## Data ownership

`EmergencyProfile` owns only user-entered emergency fields:

- display name
- emergency contact name
- emergency contact phone
- medication allergies
- important medical notes

Current medications are deliberately **not persisted inside the emergency profile**. `BuildEmergencyMedicalCard` derives them from Medication, dose-log, and refill state when the card is read, so medication changes do not create stale copied emergency data.

## Privacy and safety

The feature remains local-first and user-controlled.

- Emergency profile fields are not sent to analytics by default.
- No contacts permission is required.
- Pressing the top-level SOS entry never immediately places a call or sends a message.
- Call/SMS actions require a second explicit user action and hand off to the operating system.
- Medication allergies and medical notes are user-entered facts; Besyu does not infer diagnoses or allergies.
- The card is a communication aid, not a clinical record or emergency-services substitute.

## Persistence

Persistence stays behind `EmergencyProfileRepository` and `EmergencyProfileLocalDataSource`.

The Hive implementation stores one profile record under a stable key in a dedicated emergency-profile box. Hive remains an adapter detail and is not exposed to application/presentation code.

## Read model

`BuildEmergencyMedicalCard` composes:

```text
EmergencyProfile (owned by Emergency feature)
        +
Medication / DoseLog / Refill state
        ↓
EmergencyMedicalCard read model
```

The read model is not persisted.

## Presentation boundary

The Emergency Medical Card is intentionally read-only. Editing and destructive actions live in `EmergencyProfileSettingsScreen` so an emergency-viewing context cannot accidentally mutate or clear the data being shown.

The card can navigate to the settings screen through an explicit edit action. The same editor is also available from the application's main Settings surface.

Focused widget coverage verifies that the card remains read-only and that editing/save/delete controls live on the settings screen.

## SOS platform boundary

`EmergencyContactLauncher` is the application-facing contract for external emergency-contact actions. The current adapter uses the app's native MethodChannel integration:

- Android: opens the system dialer/messages UI with `ACTION_DIAL` / `ACTION_SENDTO`.
- iOS: opens the system `tel:` / `sms:` handlers.

Besyu does not place a call or send an SMS itself.

## Remaining / deferred

1. Keep LINE share/chat exploration separate from direct-contact SOS because the official public URL scheme does not provide direct friend voice/video-call deep links.
2. Any future additional SOS transports must remain explicit user actions behind an application-facing launcher abstraction.
3. Emergency profile export/import should join the application backup boundary rather than adding feature-specific raw Hive export logic.
