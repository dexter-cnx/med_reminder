# PRN Dose Semantics Handoff

## Status

PRN / as-needed medication semantics are now modeled explicitly on `feature/prn-dose-semantics`.

The change deliberately keeps PRN separate from `MedicationMode`.

- `MedicationMode` continues to describe the course duration/lifecycle: `forever`, `days`, or `untilEmpty`.
- `MedicationDosePlan` describes how a dose is initiated: `scheduled` or `asNeeded`.

This avoids treating PRN as another duration mode and keeps combinations such as “PRN for 7 days” or “PRN until empty” representable without overloading one enum.

## Domain model

```dart
enum MedicationDosePlan { scheduled, asNeeded }
```

`Medication` now exposes:

```dart
final MedicationDosePlan dosePlan;

bool get isAsNeeded;
bool get hasScheduledDoses;
```

The default is `MedicationDosePlan.scheduled`, so existing callers preserve their previous behavior.

## Persistence compatibility

`MedicationRecord` persists the new value as `dosePlan`.

Backward compatibility rules:

- records without `dosePlan` default to `scheduled`;
- `asNeeded`, `as_needed`, and legacy-friendly `prn` spellings map to `MedicationDosePlan.asNeeded`;
- no Hive box/schema migration is required because medication records already use map-backed values.

## Today / Daily Timeline semantics

`buildTodayDoses()` now excludes `asNeeded` medications from scheduled-dose projection.

This is intentional: PRN medication does not represent a dose that is expected at a predetermined clock time. Consequently it must not create pending scheduled cards, missed-dose state, or scheduled reminders merely because the medication exists.

Scheduled medications retain the existing behavior unchanged.

## What is intentionally not implemented yet

This branch establishes semantics and persistence only. It does **not** yet add the user interaction for recording an as-needed dose.

The next PRN-specific application flow should introduce an explicit command/use case such as:

```text
RecordAsNeededDose
  -> validate medication is PRN
  -> capture actual taken time
  -> append immutable DoseLog
  -> refresh inventory/read models
  -> project the taken event into history/timeline where appropriate
```

Do not fake a PRN dose by manufacturing a scheduled clock time in the Today projection.

Future PRN fields such as indication/reason, maximum daily frequency, minimum interval, or dose range require explicit product/medical semantics before being added. They should not be inferred from `times`.

## Tests

`test/prn_dose_semantics_test.dart` covers:

- PRN being independent from course duration;
- PRN exclusion from scheduled Today doses;
- unchanged scheduled-medication behavior;
- persistence round-trip;
- legacy records defaulting to scheduled;
- compatibility parsing for `prn`.

## Next structural step

With refill persistence, refill-aware stock, appointments, and the PRN semantic foundation present, the architecture handoff can proceed to the next remaining structural item: medication check-in as an immutable historical entity/repository.
