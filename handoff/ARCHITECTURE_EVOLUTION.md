# Besyu Architecture Evolution Handoff

## Status

Architecture foundation work for the expanded Besyu product roadmap has started on `feature/app-theme-system`.

This is an incremental refactor. It intentionally preserves existing reminder behavior and storage compatibility while introducing boundaries needed by refill history, Daily Timeline, doctor summaries, emergency data, appointments, and the future MCP/assistant layer.

The current product focus remains medication/health assistance, but the architecture must not make medication the root domain of the entire Besyu application. The name and product identity may support non-medical companion features later, so current boundaries should keep that option open without pre-building speculative features.

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

## Besyu-wide extensibility boundary

Besyu should be structured as a feature-oriented companion application rather than a medication application with unrelated features attached underneath it.

Conceptually:

```text
Besyu
├── Medication
├── Timeline
├── Appointment
├── Refill
├── Check-in
├── Doctor Summary
├── Emergency
├── Assistant
└── future independent companion features
```

Medication is therefore a **bounded feature/domain**, not an application-wide core dependency.

A future non-medical feature such as tasks, routines, personal notes, household reminders, or another companion workflow must be able to live beside medication without importing medication domain objects merely to participate in Home, Timeline, notifications, search, or the Assistant.

Do not create those future features now. This section defines architectural compatibility, not a committed product roadmap.

### Core must remain domain-neutral

Infrastructure shared across features belongs in `core` only when its contract is not specific to medication or health.

Preferred direction:

```text
lib/
├── app/
│   ├── bootstrap/
│   ├── router/
│   └── di/
├── core/
│   ├── error/
│   ├── result/
│   ├── storage/
│   ├── notifications/
│   ├── time/
│   ├── permissions/
│   └── observability/
├── features/
│   ├── medication/
│   ├── timeline/
│   ├── appointment/
│   ├── refill/
│   ├── medication_checkin/
│   ├── doctor_summary/
│   ├── emergency/
│   └── assistant/
└── shared/
    ├── theme/
    ├── widgets/
    └── l10n/
```

Examples of acceptable shared abstractions include generic notification/reminder delivery, storage primitives/adapters, time, permissions, calendar access, observability, and result/error types.

Medication-specific orchestration may wrap generic infrastructure, for example a medication reminder service can use a domain-neutral notification/reminder port without making that port medication-aware.

### Composition features must not become sources of truth

Home, Daily Timeline, Search, dashboards, and Assistant are composition surfaces. They may combine read models from multiple feature domains, but they must not own the canonical data for those features.

Architecture rule:

> New features must own their data, lifecycle, repositories, and application services. Cross-feature surfaces may compose read models but must not become the source of truth.

Future Timeline item types may include, when real features require them:

```text
MedicationDoseTimelineItem
AppointmentTimelineItem
RefillTimelineItem
CheckInTimelineItem
TaskTimelineItem
RoutineTimelineItem
PersonalNoteTimelineItem
```

Only implement item types backed by actual product features. Do not create empty abstractions solely for hypothetical future use.

### Data ownership rule

Avoid a global database object or record schema that tries to represent every Besyu feature.

Each feature should own persistence behind its repository/data-source contracts. Examples may eventually include separate medication, dose-log, refill, appointment, task, routine, or note records.

A feature may change its storage adapter later without forcing unrelated features to migrate. Hive remains an implementation detail, not the application domain model.

Likewise, avoid a giant global `UserProfile` object containing health, emergency, task, routine, assistant, and future feature state. Use feature-specific aggregates unless data is genuinely application-global identity or preference data.

### Assistant/tool boundary

The Assistant/MCP layer should depend on application-service capabilities, not directly on medication, Flutter ViewModels, or Hive.

That allows the future tool surface to expand naturally, for example:

```text
get_today_medications
get_low_stock_medications
get_next_appointment
get_today_timeline

# future only when corresponding features exist
get_today_tasks
get_daily_routine
add_personal_note
```

Medical safety restrictions continue to apply to medical tools even if the Assistant later also supports non-medical domains.

## Compatibility decisions

- Existing Hive medication and dose-log schemas remain untouched in this refactor.
- Existing imports through `medication.dart` continue to expose `DoseLog`, `DoseStatus`, and `ScheduledDose`.
- Existing imports through `medication_repository.dart` continue to expose `DoseLogRepository`.
- `MedicationMode` remains unchanged for now; PRN and staged/taper modeling will be introduced only with explicit domain semantics rather than growing this enum indiscriminately.
- `lib/screens` and other root compatibility paths remain temporarily available. UI migration should happen incrementally rather than through a broad path-only rewrite.
- No non-medical feature is introduced by these extensibility rules.

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
10. Generalize shared infrastructure only when a second real feature demonstrates the need; avoid speculative abstraction work.

## Guardrails

- Medication is a feature/domain, not the root dependency of the Besyu application.
- Do not turn `Medication` into a container for refill history, symptoms, appointment state, emergency data, AI state, or unrelated future companion features.
- Shared `core` contracts must remain domain-neutral; medication-specific behavior stays inside medication/application layers.
- New features own their own data and repositories.
- Home, Timeline, Search, and Assistant may compose feature read models but must not become sources of truth.
- Do not persist Daily Timeline projections as another source of truth.
- Do not create speculative task/routine/note domains before a real product feature requires them.
- Do not give MCP/AI direct Hive access or make it call Flutter ViewModels.
- Keep medical/safety calculations deterministic and testable outside model prompts.
- Preserve offline-first operation unless a later feature explicitly requires a network boundary.
