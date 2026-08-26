# Feature Plugin Foundation

Besyu now has the first executable boundary for the compile-time Feature Plugin Architecture described in `ARCHITECTURE_EVOLUTION.md`.

## Added in this slice

- `AppCapability` — domain-neutral platform/runtime capabilities a feature may declare.
- `FeatureManifest` — stable feature identity, version, localization key, default enablement, and capabilities.
- `AppFeature` — minimal compile-time feature contract.
- `FeatureEnablementStore` — application boundary for persisted per-feature enablement.
- `FeatureRegistry` — immutable registered feature catalog plus effective enabled-feature/capability projection.

The registry rejects blank and duplicate feature IDs. Stable IDs are user-preference keys and must not be casually renamed after shipping.

## Important distinction

Registration and enablement are separate:

```text
compiled into app
    ↓
registered in FeatureRegistry
    ↓
manifest default + persisted user preference
    ↓
effective enabled feature set
```

Disabling a feature is not data deletion. Future feature-specific lifecycle/bootstrap code must consult effective enablement before starting feature-only background work or permission flows.

## Dependency rule

The foundation is pure Dart. It deliberately does not depend on Flutter widgets, routing packages, Hive, or a concrete feature implementation. The app shell may depend on these contracts; feature implementations should not make the registry depend on their internal repositories or presentation state.

## Next slices

1. Add a persisted `FeatureEnablementStore` adapter behind the existing settings/storage infrastructure.
2. Register shipped capabilities (Medication, Appointments, Emergency) with stable manifests without changing current UX defaults.
3. Expose the registry through app-level DI/Riverpod.
4. Migrate navigation/onboarding/settings composition incrementally to registry contributions; do not rewrite routing atomically.
5. Gate feature-specific initialization/permissions only after registry state is wired through the app shell.
