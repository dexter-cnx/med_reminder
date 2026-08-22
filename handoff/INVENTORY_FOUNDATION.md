# Besyu Inventory Foundation Handoff

## Status

Started on `feature/inventory-foundation` after the app-theme/branding architecture branch was merged to `main`.

This change deliberately generalizes only the inventory calculation primitive. It does **not** turn Besyu into a generic household inventory application and does not introduce generic inventory persistence before a second persisted consumer exists.

## Why this boundary exists

Medication refill/stock is the first real inventory consumer, but the underlying arithmetic is not medical:

```text
initial amount + stock movements = current balance
```

That same primitive can support another future feature such as household consumables or refrigerator items without importing medication domain objects.

## Domain-neutral core

The reusable primitive lives under:

```text
lib/core/inventory/
├── stock_event.dart
└── calculate_stock_balance.dart
```

`StockEvent` contains only:

- event id
- item id
- signed quantity delta
- occurrence time
- optional note

A positive delta adds stock; a negative delta removes stock.

`calculateStockBalance()` filters events by item id and folds their quantity deltas over the initial amount.

The generic primitive intentionally permits a negative balance. Whether a negative balance is valid, clamped, warned about, or rejected is a feature-domain policy rather than a core inventory rule.

## Medication adapter remains medication-specific

Medication concepts stay in the medication/refill feature boundary:

```text
features/refill/
├── domain/
│   └── entities/refill_event.dart
└── application/
    └── calculate_remaining_stock.dart
```

`calculateRemainingStock()` translates medication-owned events into generic `StockEvent`s:

```text
RefillEvent       -> positive StockEvent
Taken DoseLog     -> negative StockEvent using dosagePerTime
```

It then delegates aggregation to `calculateStockBalance()` and preserves the existing medication policy of clamping the displayed remaining amount to zero.

This keeps medication terminology and medication rules out of `core/inventory` while avoiding premature abstraction of medication persistence.

## Explicit non-goals

Do not add these yet solely for genericity:

- `InventoryItem` global aggregate
- generic `InventoryRepository`
- generic Hive inventory box/schema
- household/refrigerator UI
- remote inventory synchronization
- plugin/package extraction for inventory

Refill persistence should remain owned by the refill/medication feature until another real persisted inventory consumer proves that a shared persistence contract is useful.

## Tests

`test/inventory_foundation_test.dart` includes a non-medication tomato stock scenario to prove that the core primitive is reusable without medication imports.

Existing `product_architecture_foundation_test.dart` continues to verify medication refill + taken-dose stock behavior through `calculateRemainingStock()`.

## Next step

Proceed with refill persistence using this boundary:

1. Keep `RefillEvent` as a medication/refill feature entity.
2. Add refill data model/data source/repository implementation behind `RefillRepository`.
3. Use migration-safe local persistence.
4. Route medication inventory consumers through `calculateRemainingStock()` after persistence is wired.
5. Do not create generic inventory persistence unless another real feature needs it.
