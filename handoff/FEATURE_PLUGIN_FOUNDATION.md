# Feature Plugin Foundation

Besyu now has the first executable boundary for the compile-time Feature Plugin Architecture described in `ARCHITECTURE_EVOLUTION.md`.

## Implemented

- `AppCapability` — domain-neutral platform/runtime capabilities a feature may declare.
- `FeatureManifest` — stable feature identity, version, localization key, default enablement, and capabilities.
- `AppFeature` — minimal compile-time feature contract.
- `FeatureEnablementStore` — application boundary for persisted per-feature enablement.
- `FeatureRegistry` — immutable registered feature catalog plus effective enabled-feature/capability projection.
- `HiveFeatureEnablementStore` — concrete adapter backed by the existing local `settings` Hive box.

The registry rejects blank, non-canonical, and duplicate feature IDs. Stable IDs are user-preference keys and must not be casually renamed after shipping. Manifest capability sets are defensively frozen so the registered catalog cannot mutate behind the registry.

## Persisted enablement

Feature registration and enablement are separate:

```text
compiled into app
    ↓
registered in FeatureRegistry
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

The app shell may depend on these contracts; feature implementations should not make the registry depend on their internal repositories or presentation state.

## Next slices

1. Register shipped capabilities (Medication, Appointments, Emergency) with stable manifests without changing current UX defaults.
2. Expose the registry through app-level DI/Riverpod using the existing settings box.
3. Migrate navigation/onboarding/settings composition incrementally to registry contributions; do not rewrite routing atomically.
4. Gate feature-specific initialization/permissions only after registry state is wired through the app shell.
