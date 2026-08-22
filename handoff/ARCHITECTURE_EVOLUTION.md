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

## Feature Plugin Architecture direction

Besyu should evolve toward a **compile-time Feature Plugin Architecture**. The goal is modular feature composition and explicit boundaries, not runtime code downloading or dynamic executable plugins.

This direction fits the expanding roadmap because medication, appointments, emergency/SOS, cycle tracking, local AI, and future companion features should be independently composable without turning the application shell into a dependency hub for every domain.

### Plugin model

Use three architectural levels:

1. **Core services/adapters** — storage, notifications, analytics, crash reporting, permissions, localization, calendar/platform integrations, AI runtime abstractions.
2. **Feature plugins** — user-visible capabilities such as Medication, Appointments, Emergency/SOS, Cycle Tracking, Health Journal, or Local AI Assistant.
3. **Shared UI** — theme, reusable widgets, spacing, typography, and visual primitives. Shared UI is not a feature plugin.

Do not pluginize everything. A component should become a feature plugin only when the user can reasonably perceive it as an application capability with its own routes, lifecycle, data ownership, or optional enablement.

### Application shell and registry

The application shell should compose features through a registry rather than manually importing feature internals throughout routing, navigation, startup, or settings code.

Preferred direction:

```text
lib/
├── app/
│   ├── bootstrap/
│   ├── routing/
│   ├── theme/
│   └── feature_registry/
├── core/
│   ├── analytics/
│   ├── crash_reporting/
│   ├── storage/
│   ├── notifications/
│   ├── permissions/
│   ├── localization/
│   ├── ai/
│   └── platform/
└── features/
    ├── medication/
    ├── appointments/
    ├── emergency/
    ├── cycle/
    └── ...
```

A minimal compile-time feature contract may expose identity, routes, navigation contributions, capabilities, and initialization hooks:

```dart
abstract interface class AppFeature {
  String get id;

  List<RouteBase> get routes;

  List<FeatureNavigationItem> get navigationItems;

  Set<AppCapability> get capabilities;

  Future<void> initialize(FeatureContext context);
}
```

The exact API can evolve, but the dependency direction must remain stable: **the app shell knows feature contracts; it does not depend on feature implementation details**.

A `FeatureRegistry` should aggregate registered features and expose composition data to router/navigation/settings code.

```dart
class FeatureRegistry {
  FeatureRegistry(this.features);

  final List<AppFeature> features;

  List<RouteBase> get routes =>
      features.expand((feature) => feature.routes).toList();

  List<FeatureNavigationItem> get navigationItems =>
      features.expand((feature) => feature.navigationItems).toList();
}
```

Initial registration remains compile-time, for example:

```dart
final features = <AppFeature>[
  MedicationFeature(),
  AppointmentFeature(),
  EmergencyFeature(),
];
```

This is intentionally simpler and safer than runtime plugin loading on Flutter/mobile while preserving modularity and future package extraction.

### Feature manifest and enablement

Each feature should eventually expose lightweight metadata through a manifest or equivalent contract.

```dart
class FeatureManifest {
  const FeatureManifest({
    required this.id,
    required this.version,
    required this.displayNameKey,
    this.enabledByDefault = true,
    this.capabilities = const {},
  });

  final String id;
  final String version;
  final String displayNameKey;
  final bool enabledByDefault;
  final Set<AppCapability> capabilities;
}
```

This provides a clean foundation for optional features, feature flags, settings-driven enablement, staged rollout, or product variants without hard-wiring those decisions into individual screens.

Potential enablement semantics include:

```text
Medication        enabled
Appointments      enabled
Emergency         enabled
Cycle Tracking    opt-in
Local AI          optional
Wellness          optional
Caregiver         future
```

Do not implement speculative remote configuration solely for this architecture. The registry/manifest boundary should simply keep that option available.

### Feature enablement is a first-class user preference

Feature registration and feature enablement are different concepts. A feature may be compiled into the app and registered in `FeatureRegistry` while still being disabled for a particular user.

The architecture should support persisted per-feature enablement, for example:

```text
feature.medication.enabled = true
feature.appointments.enabled = false
feature.emergency.enabled = true
feature.cycle.enabled = false
feature.local_ai.enabled = false
```

The exact storage representation can evolve, but feature IDs must remain stable enough to preserve user preference across app upgrades.

When a feature is disabled:

- it must not initialize background work that exists only for that feature;
- it must not schedule feature-specific notifications, alarms, sync jobs, or observers;
- it must not proactively request permissions or platform capabilities used only by that feature;
- feature-specific navigation may be hidden, disabled, or represented as an enable call-to-action according to product UX;
- existing user-owned data should normally remain intact so re-enabling the feature restores the previous state, unless the user explicitly chooses deletion;
- disabling a feature is **not** equivalent to deleting its data;
- cross-feature composition surfaces must tolerate the feature being unavailable and must not assume every registered feature is enabled.

The registry should therefore expose both the compiled/registered feature set and the effective enabled feature set.

Conceptually:

```dart
abstract interface class FeatureEnablementStore {
  bool isEnabled(String featureId);
  Future<void> setEnabled(String featureId, bool enabled);
}
```

Do not make individual screens read Hive keys directly. Feature enablement should be coordinated through an application/core boundary so Settings, onboarding, routing, and capabilities all observe the same state.

### Capability and permission boundary

Feature plugins should declare required platform capabilities rather than requesting permissions ad hoc from arbitrary screens.

Example capability model:

```dart
enum AppCapability {
  camera,
  notifications,
  calendar,
  contacts,
  location,
  localAi,
  healthData,
}
```

A feature may declare:

```dart
Set<AppCapability> get capabilities => {
  AppCapability.notifications,
  AppCapability.healthData,
};
```

The app/core capability layer should coordinate platform availability, permission state, user consent, and capability failure behavior. This is especially important for sensitive health-related features.

Feature declarations must not imply blanket permission requests at startup. Permissions should still be requested contextually and only when the user enables or invokes a capability that needs them.

A disabled feature must not cause a permission prompt. For example, if medication reminders are not enabled, Besyu should not request notification or exact-alarm permission merely because the medication/reminder feature is compiled into the application.

Preferred flow:

```text
Feature disabled
    ↓
No feature-specific permission request
    ↓
User chooses Enable
    ↓
Explain value / capability needed
    ↓
Request only the permission required for that capability
    ↓
Permission granted   → enable capability / feature path
Permission denied    → preserve a recoverable disabled or limited state
```

Where possible, distinguish feature enablement from individual capability enablement. A feature may remain useful in a limited mode even if one optional permission is denied. For example, medication records may remain usable while reminder notifications stay disabled.

Permission denial must not silently convert into destructive feature disablement or data deletion.

### Onboarding becomes feature discovery and opt-in

The onboarding/boarding experience should move away from being primarily a sequence of startup permission prompts.

Its primary purpose should be:

1. introduce Besyu and the product promise;
2. present a concise set of **Key Features** that are actually available in the current build;
3. explain the user benefit of each feature in plain language;
4. invite the user to enable the features they want;
5. request platform permissions only as a consequence of enabling or using the corresponding feature/capability.

Example conceptual flow:

```text
Welcome to Besyu
    ↓
Key Features
    ├── Medication tracking
    ├── Medication reminders      [Enable]
    ├── Appointments              [Enable]
    ├── Emergency / SOS           [Enable]
    └── other shipped features
    ↓
Optional feature-specific setup
    ↓
Permission prompts only where required
    ↓
Home
```

Onboarding must not present features that are only speculative or not shipped in the current build.

The user should be able to skip optional features and continue into the app. The same features must remain discoverable and enable-able later from Settings or another appropriate feature-management surface.

Feature enablement performed during onboarding and feature enablement performed later in Settings must use the same application service/state, not separate onboarding-only flags.

For permissions, onboarding should explain **why** a permission is needed before invoking the OS prompt. Avoid requesting notification, calendar, contacts, camera, health-data, location, or similar access simply because onboarding is running.

This also makes onboarding resilient as the product grows: adding a new feature should contribute onboarding/discovery metadata rather than expanding a hard-coded permission wizard.

A future feature manifest may therefore expose optional discovery metadata, for example:

```dart
class FeatureManifest {
  // existing fields...
  final String? onboardingTitleKey;
  final String? onboardingDescriptionKey;
  final String? onboardingIconKey;
  final bool showInOnboarding;
}
```

Treat this as presentation metadata only. The feature still owns the actual enablement and capability requirements.

### Cross-feature dependencies

Feature implementation folders must not import another feature's internal data source, repository implementation, ViewModel, or presentation layer.

When a real cross-feature use case exists, expose a narrow public feature API/application contract.

Example:

```dart
abstract interface class MedicationFeatureApi {
  Future<List<MedicationSummary>> getActiveMedications();
}
```

An Appointment feature may depend on `MedicationFeatureApi` when it genuinely needs medication summaries, but it must not import `MedicationRepositoryImpl`, Hive models, or medication UI state.

Prefer composition/read-model services when features only need to appear together on Home, Timeline, Search, or Assistant surfaces. Direct feature-to-feature contracts should remain narrow and intentional.

Avoid cyclic feature dependencies. If Feature A and Feature B both require the same capability, extract a domain-neutral core contract or a dedicated composition/application service rather than making them depend on each other bidirectionally.

### Infrastructure adapters remain outside feature plugins

The existing adapter strategy for analytics and crash reporting fits this model and should be extended consistently.

Feature code should call contracts such as:

```dart
abstract interface class AnalyticsService {
  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
  });
}
```

Feature code should not call Firebase Analytics, Crashlytics, Sentry, Hive, or another vendor SDK directly unless that SDK is itself fully encapsulated behind a feature-local implementation detail with no application-wide coupling.

The same rule applies to notifications, storage, calendar access, permissions, and future local-AI runtimes.

### Package extraction path

Do **not** convert every feature into a separate Dart package immediately. Keep features as modules in the main repository first, but enforce package-like boundaries now.

Once build isolation, reuse, ownership, testing, or independent release cadence justifies the overhead, a feature can move toward:

```text
packages/
├── besyu_core/
├── besyu_feature_medication/
├── besyu_feature_appointments/
├── besyu_feature_cycle/
└── besyu_feature_emergency/
```

If public contracts and dependency direction are respected from the beginning, this later extraction should be primarily structural rather than an architectural rewrite.

### Plugin architecture guardrails

- Use **compile-time registration** first; do not introduce runtime executable plugin loading.
- Registration does not imply enablement; compiled features may remain disabled per user.
- The app shell must depend on feature contracts/registry contributions, not feature internals.
- Feature plugins own their domain data, repositories, application services, and lifecycle.
- Disabled features must not initialize feature-only background work or request feature-only permissions.
- Disabling a feature should preserve its data by default; deletion is a separate explicit user action.
- Cross-feature surfaces compose read models; they do not absorb feature ownership.
- Cross-feature dependencies use narrow public APIs/application contracts only when necessary.
- Never import another feature's repository implementation, storage model, ViewModel, or UI internals.
- Avoid cyclic feature dependencies.
- Platform permissions are coordinated through declared capabilities and a domain-neutral capability layer.
- Permission prompts must follow user intent to enable/use the relevant feature or capability; avoid startup permission sweeps.
- Onboarding should discover and invite activation of shipped Key Features, not act as a hard-coded permission wizard.
- Analytics, crash reporting, storage, notifications, and AI providers remain adapters, not feature plugins.
- Theme and reusable widgets remain shared UI, not feature plugins.
- Design module boundaries so they can become Dart packages later, but avoid multi-package overhead until there is a concrete benefit.

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
9. Introduce the compile-time `AppFeature`/`FeatureRegistry` boundary before feature count grows substantially; start with routing/navigation/manifest contributions and avoid over-engineering lifecycle hooks until required.
10. Add persisted per-feature enablement and a shared `FeatureEnablementStore`; ensure routing, Settings, onboarding, background initialization, and capability requests all consume the same state.
11. Refactor onboarding into shipped-feature discovery/opt-in; move permission requests behind explicit feature/capability enable actions.
12. Add the capability declaration boundary when the second feature requires shared platform permissions or integrations.
13. Gradually migrate root-level UI paths into feature presentation folders, preserving compatibility exports while callers transition.
14. Generalize shared infrastructure only when a second real feature demonstrates the need; avoid speculative abstraction work.

## Guardrails

- Medication is a feature/domain, not the root dependency of the Besyu application.
- Do not turn `Medication` into a container for refill history, symptoms, appointment state, emergency data, AI state, or unrelated future companion features.
- Shared `core` contracts must remain domain-neutral; medication-specific behavior stays inside medication/application layers.
- New features own their own data and repositories.
- Home, Timeline, Search, and Assistant may compose feature read models but must not become sources of truth.
- Do not persist Daily Timeline projections as another source of truth.
- Do not create speculative task/routine/note domains before a real product requirement exists.
- Treat feature plugins as compile-time modules first; runtime code/plugin loading is out of scope.
- Keep feature-to-feature APIs narrow, explicit, acyclic, and independent of storage/UI implementations.
- Feature availability is user-controlled where the product marks a feature optional; disabled features must remain operationally quiet.
- Never request feature-specific platform permissions before the user has chosen to enable or use the corresponding capability.
