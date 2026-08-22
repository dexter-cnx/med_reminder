# Refill Persistence Handoff

## Status

Implemented on `feature/refill-persistence` after the domain-neutral inventory foundation landed on `main`.

This milestone persists medication refill history without changing the existing `meds` or `logs` Hive schemas.

## Storage boundary

Refill remains a medication-owned feature. The generic inventory primitive in `core/inventory` does not own persistence.

```text
features/refill/
├── application/
│   └── calculate_remaining_stock.dart
├── data/
│   ├── datasources/
│   │   └── refill_local_data_source.dart
│   ├── models/
│   │   └── refill_record.dart
│   └── repositories/
│       └── local_refill_repository.dart
├── domain/
│   ├── entities/refill_event.dart
│   └── repositories/refill_repository.dart
└── presentation/
    └── providers/refill_providers.dart
```

## Hive storage

A dedicated `refills` box is opened during application bootstrap.

Existing boxes are unchanged:

```text
meds
logs
settings
```

New box:

```text
refills
```

Opening a new empty box is migration-safe for existing installations because no existing record schema is rewritten.

Each refill is stored under its stable `RefillEvent.id` rather than as an auto-increment Hive index. The event id therefore acts as an idempotency key: retrying the same append replaces the same persisted record instead of adding duplicate stock.

## Record schema

Current schema version is `1`.

```text
schemaVersion
id
medicationId
quantity
createdAt
note
```

Dates are stored as ISO-8601 strings. The mapper validates required fields before constructing a domain entity.

## Repository behavior

`LocalRefillRepository` implements the existing `RefillRepository` contract:

```dart
Result<List<RefillEvent>> readAll();
Future<Result<void>> append(RefillEvent event);
```

Reads return events ordered chronologically by `createdAt`.

Persistence errors are converted to the existing application `Failure` boundary instead of leaking Hive exceptions through the domain contract.

## Dependency injection

`refillRepositoryProvider` is overridden in the application bootstrap with the Hive-backed repository.

No UI is added in this milestone. This PR only makes refill history durable and available to subsequent application/UI work.

## Tests

Coverage includes:

- `RefillRecord` domain round-trip;
- chronological repository reads;
- retry-safe append semantics using stable event ids.

## Explicit non-goals

This milestone does not yet:

- add refill UI;
- change medication stock displays;
- route Home/Medication detail through refill-aware inventory;
- add low-stock notification changes;
- persist generic `StockEvent` objects;
- introduce a generic inventory repository or household inventory product feature.

## Next steps

1. Add a refill application query/service that loads persisted refill events with medication dose history.
2. Route medication remaining-stock consumers through `calculateRemainingStock()` using persisted refill events.
3. Add low-stock threshold evaluation on the refill-aware balance.
4. Add user-facing refill entry/history UI.
5. Add refill-related timeline projection only after the user-facing refill workflow exists.
