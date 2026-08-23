# Medication Check-in Runtime + UI

## Status

This slice turns the Medication Check-in foundation into a user-visible, offline-first workflow.

Implemented on `feature/medication-checkin-runtime-ui`.

## Runtime composition

The app bootstrap now opens a dedicated Hive box:

```text
medication_check_ins
```

The box is wrapped by `HiveMedicationCheckInLocalDataSource` and `LocalMedicationCheckInRepository`, then injected through `medicationCheckInRepositoryProvider`.

Check-ins remain owned by the medication-checkin feature. They are not stored inside `Medication`, `DoseLog`, Home, or Timeline state.

## Application services

Two explicit application operations now exist:

- `RecordMedicationCheckIn` — creates an immutable record with a generated ID and factual timestamp, trims free-text notes, and persists through the repository contract.
- `QueryMedicationCheckIns` — filters check-ins by medication and returns newest-first history, with an optional limit for future summary surfaces.

These application operations are suitable building blocks for the future Doctor Visit Summary and Assistant/tool layer without exposing Hive or Flutter UI state.

## UI flow

The Medications list now exposes a Check-in action beside Refill.

The check-in bottom sheet allows the user to record:

- No issue noticed
- Dizziness
- Nausea
- Rash
- Other
- Optional free-text context

The same sheet shows medication-scoped history newest first.

English and Thai copy is generated from `assets/translations.csv`.

## Safety semantics

The UI deliberately uses language equivalent to "reported observation" rather than asserting a medication side effect.

Besyu records what the user noticed but does not:

- determine that the medication caused the observation;
- diagnose the symptom;
- recommend stopping, substituting, or changing a dose;
- infer urgency from a selected observation in this slice.

Urgent-symptom routing to SOS/emergency behavior remains a separate safety design decision.

## Tests

`test/medication_check_in_runtime_test.dart` covers:

- capture persistence with trimmed free-text notes;
- deterministic timestamp injection;
- medication-scoped filtering;
- newest-first ordering;
- query limiting after filtering/sorting.

The existing foundation tests continue to cover persistence compatibility and stable-ID replacement behavior.

## Next structural step

With factual check-in capture and query APIs available, the next architecture item can begin:

**Doctor Visit Summary as a read model over source repositories.**

The summary must query Medication, DoseLog/adherence, PRN usage, Refill, Appointment, and Medication Check-in sources. It must not persist duplicated copies of those source records.
