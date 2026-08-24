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
- SOS entry points from Home and the Emergency Medical Card.
- Call/SMS handoff through an `EmergencyContactLauncher` abstraction and native platform channel.

The main Settings screen entry remains a follow-up slice. LINE direct-contact voice/video calling is not implemented because LINE's public URL scheme does not expose a supported direct friend voice/video-call deep link.

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

The card can navigate to the settings screen through an explicit edit action. A later slice should also expose the same settings screen from the application's main Settings surface.

## SOS platform boundary

`EmergencyContactLauncher` is the application-facing contract for external emergency-contact actions. The current adapter uses the app's native MethodChannel integration:

- Android: opens the system dialer/messages UI with `ACTION_DIAL` / `ACTION_SENDTO`.
- iOS: opens the system `tel:` / `sms:` handlers.

Besyu does not place a call or send an SMS itself.

## Next slice

1. Add an Emergency section in the main Settings screen that opens `EmergencyProfileSettingsScreen`.
2. Add focused presentation tests for read-only card vs settings mutation boundaries.
3. Keep LINE share/chat exploration separate from direct-contact SOS because the official public URL scheme does not provide direct friend voice/video-call deep links.
