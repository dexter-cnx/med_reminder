# Low-stock alert deduplication policy

## Goal

Prevent repeated low-stock notifications while a medication remains below its configured threshold, while allowing a new notification after a refill restores stock above the threshold and the balance later crosses down again.

## Source of truth

Remaining stock is still derived from:

```text
initial medication amount
+ persisted refill events
- Taken dose logs
= remaining stock
```

The deduplication state is **not** stock data and does not change this formula.

## Alert episode state

`LowStockAlertStateStore` persists only the threshold for which the current low-stock episode has already produced an alert.

The local implementation stores this in the existing Hive `settings` box using medication-scoped keys.

```text
low_stock_alert_threshold:<medicationId> -> threshold
```

This state is operational notification-delivery state. It is not part of `Medication`, `DoseLog`, `RefillEvent`, or generic inventory persistence.

## Policy

After a Taken dose:

1. Resolve refill-aware remaining stock.
2. If remaining is above the low-stock threshold, clear any old alert episode state.
3. If remaining is at or below the threshold, evaluate whether the current dose crossed from above to at/below the threshold.
4. Emit a low-stock notification only when that crossing happened and the same threshold has not already been alerted.
5. Persist the alerted threshold after notification delivery.

Repeated reconciliation while the balance remains below the threshold does not emit another notification.

## Re-arm after refill

After a refill:

- if refill-aware remaining stock becomes greater than the threshold, clear the alert episode state;
- if stock remains at or below the threshold, keep the existing episode state;
- refill itself does not emit a low-stock notification.

This means a later dose can notify again only after the stock was genuinely restored above the threshold and then crossed down again.

## Threshold changes

The stored value is the threshold that was alerted, rather than a simple boolean. A future medication-edit flow can therefore distinguish an alert produced under an old threshold from the current threshold without migrating medication stock data.

## Medication deletion

Deleting a medication clears its low-stock alert episode state after repository deletion succeeds.

## Failure / safety characteristics

- Refill-read failure continues to resolve stock as unknown (`null`) in the app composition root, so no low-stock decision is made from incomplete inventory data.
- Dedup state does not mutate the medication or inventory history.
- No refill, prescription-renewal, dosage, or medical recommendation is inferred from this state.

## Tests

Regression coverage verifies that:

- refill-aware low-stock crossing emits one alert;
- repeated reconciliation below the same threshold is deduplicated;
- refill above the threshold clears the episode state;
- a later threshold crossing can alert again;
- existing refill and Riverpod DI flows receive the new store dependency.

## Next step

After this policy is green and merged, surface refill events in the Daily Timeline projection. Timeline remains a read/composition model and must not become a source of truth.
