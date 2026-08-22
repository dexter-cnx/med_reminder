# Refill-aware Stock Integration Handoff

## Status

This branch routes operational medication stock consumers through the persisted-refill-aware inventory calculation introduced by the inventory and refill persistence foundations.

The effective medication stock formula is now:

```text
initial amount + refill quantities - consumed taken doses
```

## Boundary

Medication does not import refill persistence or refill presentation details.

The medication application/presentation boundary defines `MedicationStockResolver`, a narrow function contract:

```dart
typedef MedicationStockResolver = int? Function(
  Medication medication,
  Iterable<DoseLog> logs,
);
```

Its default implementation preserves legacy behavior for isolated medication tests and feature use.

The app composition root overrides this resolver with a refill-aware implementation backed by `RefillRepository` and `calculateRemainingStock()`.

This keeps dependency direction explicit:

```text
Medication consumers
      ↓
MedicationStockResolver
      ↑
app composition root
      ↓
RefillRepository + calculateRemainingStock
```

## Consumers migrated

The following consumers now use the injected stock resolver:

- Today dose `remaining` values shown by Home.
- `untilEmpty` active/empty evaluation while building today's doses.
- Taken-dose reconciliation that cancels reminders when an until-empty medication truly reaches zero.
- Low-stock threshold crossing and warning values.
- Timezone-triggered `rescheduleAll()` active/empty evaluation.

This prevents the UI, low-stock warnings, and reminder cancellation from disagreeing after a refill has been recorded.

## Failure behavior

If persisted refill history cannot be read, the app-level refill-aware resolver returns `null` rather than falling back to the old no-refill calculation.

This is deliberate fail-safe behavior:

- an `untilEmpty` medication is not incorrectly treated as empty;
- reminders are not cancelled because refill data could not be read;
- a false low-stock warning is not emitted;
- the UI may show unknown remaining stock until storage can be read again.

## Compatibility

`Medication.remaining()`, `Medication.isLowStock()`, and `Medication.isActiveOn()` remain available as legacy medication-domain helpers for compatibility and isolated use. Runtime app composition no longer relies on those helpers for refill-aware operational stock decisions.

No existing medication, dose-log, or refill persistence schema changes are introduced in this step.

## Tests

Coverage verifies that:

- Today doses remain active and show refill-aware stock even when legacy stock would be zero.
- Until-empty reconciliation does not cancel reminders when refill-aware stock remains positive.
- Low-stock warning evaluation uses the injected refill-aware balance.

## Next step

Add the user-facing refill workflow:

1. Add refill action from medication details/list.
2. Persist quantity/date/note through `RefillRepository.append()`.
3. Refresh the visible stock state after append.
4. Show refill history where useful.
5. Re-evaluate low-stock UX and notification deduplication after refill actions exist.

Do not introduce a generic inventory UI or generic inventory repository solely for this medication workflow.
