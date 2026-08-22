# Refill UI + History Handoff

Branch: `feature/refill-ui-history`

## Scope

This iteration exposes the persisted refill foundation to the user without expanding Besyu into a generic inventory product.

User flow:

1. Open **Medications**.
2. Tap the refill action on a medication.
3. See the current event-derived remaining stock.
4. Enter a positive refill quantity and an optional note.
5. Save the refill locally.
6. See the refill immediately in medication-specific history.
7. Today's remaining-stock projection refreshes immediately.

## State ownership

Refill keeps its own Riverpod state:

```text
RefillRepository
  -> RefillViewModel
  -> refillEventsProvider
  -> RefillPanel
```

The UI never mutates `Medication.initialAmount` and does not persist a mutable `remaining` counter.

Refill history remains an immutable sequence of `RefillEvent` records.

## Stock calculation

Current stock is still resolved through the medication-owned `MedicationStockResolver` contract introduced in the previous iteration.

The runtime implementation remains:

```text
initial amount
+ persisted refill events
- taken dose consumption
= remaining stock
```

The refill panel observes refill state for immediate history updates, while the stock resolver reads the repository-backed event history used by the rest of the app.

## Reminder recovery

A refill can recover an `untilEmpty` medication that previously reached zero and had its reminder IDs cleared.

`MedicationViewModel.refreshAfterRefill()` only reschedules the affected medication when all of these are true:

- mode is `untilEmpty`
- medication is not expired
- refill-aware remaining stock is known and greater than zero
- there are currently no scheduled notification IDs

This avoids rescheduling every medication after a single refill.

## Failure behavior

- invalid or non-positive quantity is rejected before persistence
- repository append failure leaves refill state unchanged
- persistence failures surface through `refillFailureProvider`
- the UI shows a local save-failed message
- no stock mutation is attempted as a fallback

## Localization

Refill action, quantity, note, save result, and history labels are localized in English and Thai through the existing CSV-generated localization pipeline.

## Tests

`test/refill_ui_flow_test.dart` covers:

- successful append and chronological refill state
- failed append preserving existing state
- reminder restoration for refilled `untilEmpty` medication

Existing stock-integration and persistence tests remain the source of truth for arithmetic and Hive behavior.

## Non-goals

This iteration does not add:

- edit/delete refill history
- refill forecasting
- pharmacy integration
- prescription renewal inference
- generic inventory UI
- generic inventory persistence
- cloud sync

## Next candidate

After this PR is green, the next refill-related hardening should be low-stock notification deduplication / notification-state policy, then Daily Timeline integration of refill events.
