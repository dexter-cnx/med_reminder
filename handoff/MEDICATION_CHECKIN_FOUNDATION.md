# Medication Check-in Foundation

## Status

Medication check-in / side-effect notes now have an independent feature boundary on `feature/medication-checkin-foundation`.

This change establishes domain and persistence semantics only. It does not yet add reminder scheduling, check-in UI, Doctor Visit Summary integration, or emergency symptom classification.

## Domain model

`MedicationCheckIn` is an immutable historical record with:

- `id`
- `medicationId`
- `recordedAt`
- `kind`
- optional free-text `note`

Initial user-reported kinds are:

- `noIssue`
- `dizziness`
- `nausea`
- `rash`
- `other`

The model deliberately records observations rather than causality. Besyu must not state that a medication caused a reported symptom merely because the check-in references that medication.

## Ownership

Check-ins are owned by `features/medication_checkin` rather than embedded into `Medication` or `DoseLog`.

This preserves immutable history and allows Doctor Visit Summary to query check-in records without turning medication storage into a growing aggregate of unrelated lifecycle data.

## Persistence

The feature defines:

- `MedicationCheckInRepository`
- `MedicationCheckInLocalDataSource`
- `HiveMedicationCheckInLocalDataSource`
- `MedicationCheckInRecord`
- `LocalMedicationCheckInRepository`

Repository semantics are append-oriented and read results are ordered by `recordedAt`.

Persisted unknown `kind` values degrade to `other` so a future enum extension does not make older app code fail to read the local history.

## Riverpod boundary

`medicationCheckInRepositoryProvider` and `medicationCheckInsProvider` establish the presentation composition boundary. Runtime Hive bootstrap wiring should be added together with the first user-visible check-in flow so the app does not open unused storage or initialize unused feature work merely because the foundation exists.

## Safety guardrails

- Check-ins are user-reported notes, not diagnoses.
- Do not infer that a medication caused a symptom.
- Do not recommend stopping, substituting, or changing dosage from a check-in.
- Urgent-symptom routing requires a separate conservative product/safety design.
- Check-in scheduling defaults such as day 1/day 3/day 7 are not implemented in this foundation.

## Next steps

1. Add the first explicit check-in capture/query use cases and user-visible UI.
2. Wire the Hive box/repository into app bootstrap only when that runtime feature is enabled.
3. Project check-in history into Doctor Visit Summary as source data, not copied summary persistence.
4. Design check-in reminder scheduling separately behind the domain-neutral notification boundary.
5. Evaluate emergency/SOS routing independently before attaching urgency semantics to symptoms.
