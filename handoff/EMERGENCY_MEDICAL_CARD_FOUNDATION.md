# Emergency Medical Card Foundation

## Scope

This change introduces the first Emergency Medical Card foundation as a separate feature boundary.

Implemented:

- `EmergencyProfile` aggregate for user-entered emergency information.
- Repository and local-data-source contracts.
- Hive-backed local data source and local repository implementation.
- `EmergencyMedicalCard` read model that composes the profile with current medications at read time.
- Riverpod provider/view-model foundation.
- Regression tests for record round-trip, normalization, persistence behavior, and derived medication composition.

Not wired into app bootstrap or UI yet. Runtime Hive composition, Settings editing UI, emergency-card presentation, and SOS contact actions belong in the next slice.

## Data ownership

`EmergencyProfile` owns only user-entered emergency fields:

- display name
- emergency contact name
- emergency contact phone
- medication allergies
- important medical notes

Current medications are deliberately **not persisted inside the emergency profile**. `BuildEmergencyMedicalCard` derives them from the Medication feature when the card is read, so medication changes do not create stale copied emergency data.

## Privacy and safety

The feature remains local-first and user-controlled.

- No emergency profile data is sent to analytics by default.
- No contacts permission is required by this foundation.
- No phone/SMS/LINE action is triggered by this foundation.
- Medication allergies and medical notes are user-entered facts; Besyu does not infer diagnoses or allergies.
- The card is a communication aid, not a clinical record or emergency-services substitute.

## Persistence

Persistence is hidden behind `EmergencyProfileRepository` and `EmergencyProfileLocalDataSource`.

The Hive implementation stores one profile record under a stable key in a dedicated future emergency-profile box. Hive remains an adapter detail and is not exposed to application/presentation code.

## Read model

`BuildEmergencyMedicalCard` composes:

```text
EmergencyProfile (owned by Emergency feature)
        +
Medication list (owned by Medication feature)
        ↓
EmergencyMedicalCard read model
```

The read model is not persisted.

## Next slice

1. Wire a dedicated Hive emergency-profile box into `main.dart` DI.
2. Add Settings entry and edit screen.
3. Add a dedicated read-only Emergency Medical Card presentation.
4. Keep current medication data derived rather than copied.
5. Add explicit delete/reset UX.
6. Only after the card flow is stable, integrate it with the SOS entry point and evaluate phone/SMS/LINE platform adapters separately.
