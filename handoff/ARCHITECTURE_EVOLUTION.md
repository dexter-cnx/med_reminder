# Besyu Architecture Evolution Handoff

## Status

Architecture foundation work for the expanded Besyu product roadmap has started on `feature/app-theme-system`.

This is an incremental refactor. It intentionally preserves existing reminder behavior and storage compatibility while introducing boundaries needed by refill history, Daily Timeline, doctor summaries, emergency data, appointments, and the future MCP/assistant layer.

## Implemented foundation

### Medication domain split

The medication aggregate no longer owns all medication-related domain types in one source file.

Current direction:

```text
features/medication/
├── application/
│   └── build_today_doses.dart
├── domain/
│   ├── entities/
│   │   ├── medication.dart
│   │   ├── dose_log.dart
│   │   └── scheduled_dose.dart
│   ├── repositories/
│   │   ├── medication_repository.dart
│   │   └── dose_log_repository.dart
│   └── services/
├── data/
└── presentation/
```

`medication.dart` and `medication_repository.dart` retain compatibility exports so existing imports do not need to migrate atomically.

### Application/query boundary

Today-dose construction has moved out of `MedicationViewModel` into the pure Dart application query `buildTodayDoses()`.

The ViewModel now coordinates Riverpod state and delegates deterministic projection logic to the application layer. This is the first step toward sharing the same app logic with Home, Daily Timeline, doctor summaries, and MCP tools without routing those consumers through Flutter ViewModels.

### Refill event foundation

Refills are modeled as immutable `RefillEvent` records rather than fields added to `Medication`.

```text
features/refill/
├── application/
│   └── calculate_remaining_stock.dart
└── domain/
    ├── entities/refill_event.dart
    └── repositories/refill_repository.dart
```

The event-derived inventory formula is:

```text
remaining = initial amount + refill quantities - consumed taken doses
```

This deliberately avoids a mutable persisted `remainingAmount` counter.

Refill persistence is **not wired yet**. Existing medication storage and `Medication.remaining()` behavior remain unchanged until a dedicated refill data adapter/migration is implemented.

### Daily Timeline foundation

Daily Timeline is introduced as a projection/read-model feature:

```text
features/timeline/
├── application/
│   └── build_daily_timeline.dart
└── domain/
    └── entities/timeline_item.dart
```

The first timeline item is `MedicationDoseTimelineItem`. Future appointment, refill, and check-in item types should extend this projection rather than forcing Home widgets to query and join multiple repositories directly.

Timeline items are not a second source of truth and should not be persisted as copies of medication/appointment/refill data.

## Compatibility decisions

- Existing Hive medication and dose-log schemas remain untouched in this refactor.
- Existing imports through `medication.dart` continue to expose `DoseLog`, `DoseStatus`, and `ScheduledDose`.
- Existing imports through `medication_repository.dart` continue to expose `DoseLogRepository`.
- `MedicationMode` remains unchanged for now; PRN and staged/taper modeling will be introduced only with explicit domain semantics rather than growing this enum indiscriminately.
- `lib/screens` and other root compatibility paths remain temporarily available. UI migration should happen incrementally rather than through a broad path-only rewrite.

## Next structural steps

Before implementing the corresponding product features, continue in this order:

1. Add refill data model/data source/repository adapter and migration-safe local storage.
2. Route inventory consumers through the event-derived inventory application service once refill storage exists.
3. Introduce explicit PRN dose semantics without treating PRN as another duration mode.
4. Add appointment as its own feature and project appointments into Daily Timeline.
5. Add medication check-in as an immutable historical entity/repository.
6. Build Doctor Visit Summary as a query/read model over source repositories rather than its own duplicated database.
7. Add Emergency Profile as a separate aggregate; derive current medication lists when rendering the card.
8. Introduce an application-service facade for MCP/assistant reads and confirmation-gated writes.
9. Gradually migrate root-level UI paths into feature presentation folders, preserving compatibility exports while callers transition.

## Guardrails

- Do not turn `Medication` into a container for refill history, symptoms, appointment state, emergency data, or AI state.
- Do not persist Daily Timeline projections as another source of truth.
- Do not give MCP/AI direct Hive access or make it call Flutter ViewModels.
- Keep medical/safety calculations deterministic and testable outside model prompts.
- Preserve offline-first operation unless a later feature explicitly requires a network boundary.
