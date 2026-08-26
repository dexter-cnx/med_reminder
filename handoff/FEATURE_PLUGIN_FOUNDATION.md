# Feature Plugin Foundation

Besyu now has the first executable boundary for the compile-time Feature Plugin Architecture described in `ARCHITECTURE_EVOLUTION.md`.

## Implemented

- `AppCapability` — domain-neutral platform/runtime capabilities a feature may declare.
- `FeatureManifest` — stable feature identity, version, localization key, default enablement, and capabilities.
- `AppFeature` — minimal compile-time feature contract.
- `FeatureEnablementStore` — application boundary for persisted per-feature enablement.
- `FeatureRegistry` — immutable registered feature catalog plus effective enabled-feature/capability projection.
- `HiveFeatureEnablementStore` — concrete adapter backed by the existing local `settings` Hive box.
- `buildShippedFeatures()` — compile-time catalog for shipped Medication, Appointments, and Emergency features.
- `featureEnablementStoreProvider` — app-DI boundary for the persistence adapter.
- `featureRegistryProvider` — reactive Riverpod state for the shipped registry.
- `FeatureRegistryController` — the write path for enablement changes; successful writes publish a fresh registry state so watched navigation/capability consumers recompute immediately.

The app bootstrap injects `HiveFeatureEnablementStore(settingsBox)` into the provider scope. The registry itself remains unaware of Hive and reads the compile-time shipped catalog through `buildShippedFeatures()`.

Feature enablement writes should go through `featureRegistryProvider.notifier` rather than mutating a watched registry instance directly. The controller persists the new preference and then publishes a fresh `FeatureRegistry`, making `ref.watch(featureRegistryProvider)` reactive to enablement changes.

The registry rejects blank, non-canonical, and duplicate feature IDs. Stable IDs are user-preference keys and must not be casually renamed after shipping. Manifest capability sets are defensively frozen so the registered catalog cannot mutate behind the registry.

## Shipped manifests

Current stable feature IDs and defaults:

```text
medication    enabled by default    notifications, camera
appointments  enabled by default    calendar
emergency     enabled by default    phone/SMS
```

All three remain enabled by default so introducing the registry does not change current UX. Capability declarations describe feature ownership only; they must not cause startup permission prompts. Emergency declares `phoneSms` because the shipped SOS flow already launches phone calls and SMS; this remains distinct from contacts access.

## Persisted enablement

Feature registration and enablement are separate:

```text
compiled into app
    ↓
registered in FeatureRegistry
    ↓
Riverpod app-DI + reactive controller
    ↓
manifest default + persisted user preference
    ↓
effective enabled feature set
```

Persisted overrides use stable keys:

```text
feature.<feature-id>.enabled
```

Only persisted booleans are accepted. Missing or malformed stored values fall back to the manifest default rather than implicitly enabling or disabling a feature.

Disabling a feature is not data deletion. Future feature-specific lifecycle/bootstrap code must consult effective enablement before starting feature-only background work or permission flows.

## Dependency rule

The contracts and registry remain pure Dart. Hive is isolated in the concrete enablement-store adapter; screens and feature implementations must not read feature enablement keys directly.

The app shell may depend on the Riverpod providers and registry contracts; feature implementations should not make the registry depend on their internal repositories or presentation state.

## Next slices

1. Migrate navigation/onboarding/settings composition incrementally to registry contributions; do not rewrite routing atomically.
2. Gate feature-specific initialization/permissions only after registry state is wired through the app shell.
3. Add an explicit user-facing feature enablement surface only when product behavior for disabling shipped features is defined.
4. Add opt-in manifests only when the corresponding feature is actually shipped; do not register speculative roadmap features.
