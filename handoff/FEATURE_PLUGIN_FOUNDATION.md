# Feature Plugin Foundation

Besyu now has the first executable boundary for the compile-time Feature Plugin Architecture described in `ARCHITECTURE_EVOLUTION.md`.

## Implemented

- `AppCapability` — domain-neutral platform/runtime capabilities a feature may declare.
- `AppNavigationSlot` — domain-neutral app-shell navigation surfaces a feature may contribute without importing presentation widgets.
- `AppShellAction` — domain-neutral app-shell actions contributed by features without importing Flutter widgets or routes.
- `AppSettingsSection` — domain-neutral settings surfaces contributed by features without coupling manifests to `SettingsScreen` widgets.
- `AppOnboardingStep` — domain-neutral onboarding steps contributed by features without coupling manifests to onboarding widgets.
- `FeatureManifest` — stable feature identity, version, localization key, default enablement, capabilities, navigation contributions, shell actions, settings contributions, and onboarding contributions.
- `AppFeature` — minimal compile-time feature contract.
- `FeatureEnablementStore` — application boundary for persisted per-feature enablement.
- `FeatureRegistry` — immutable registered feature catalog plus effective enabled-feature/capability/navigation/shell-action/settings/onboarding projection.
- `HiveFeatureEnablementStore` — concrete adapter backed by the existing local `settings` Hive box.
- `buildShippedFeatures()` — compile-time catalog for shipped Medication, Appointments, and Emergency features.
- `featureEnablementStoreProvider` — app-DI boundary for the persistence adapter.
- `featureRegistryProvider` — reactive Riverpod state for the shipped registry.
- `FeatureRegistryController` — the write path for enablement changes; successful writes publish a fresh registry state so watched shell consumers recompute immediately.
- `HomeScreen` — consumes effective navigation slots and shell actions reactively while keeping Settings as a core app destination.
- `settingsCompositionProvider` — derives feature-owned Settings visibility from the reactive registry.
- `SettingsScreen` — consumes the settings composition model while preserving core settings surfaces independently from feature enablement.
- `onboardingCompositionProvider` — derives feature-owned onboarding steps from the reactive registry.
- `OnboardingScreen` — composes its permission flow from semantic feature ownership while retaining welcome, language selection, and completion as core onboarding.

The app bootstrap injects `HiveFeatureEnablementStore(settingsBox)` into the provider scope. The registry itself remains unaware of Hive and reads the compile-time shipped catalog through `buildShippedFeatures()`.

Feature enablement writes should go through `featureRegistryProvider.notifier` rather than mutating a watched registry instance directly. The controller persists the new preference and then publishes a fresh `FeatureRegistry`, making `ref.watch(featureRegistryProvider)` reactive to enablement changes.

The registry rejects blank, non-canonical, and duplicate feature IDs. Stable IDs are user-preference keys and must not be casually renamed after shipping. Manifest contribution sets are defensively frozen so the registered catalog cannot mutate behind the registry.

## Shipped manifests

Current stable feature IDs and defaults:

```text
medication    enabled by default    notifications, camera    today, medications    no shell action    medication permissions    medication onboarding permissions
appointments  enabled by default    calendar                 appointments          no shell action    no settings section       no onboarding step
emergency     enabled by default    phone/SMS                no bottom-nav slot    SOS, medical card  emergency profile         no onboarding step
```

All three remain enabled by default so introducing the registry does not change current UX. Capability declarations describe feature ownership only; they must not cause startup permission prompts. Emergency declares `phoneSms` because the shipped SOS flow already launches phone calls and SMS; this remains distinct from contacts access.

Navigation slots, shell actions, settings sections, and onboarding steps are semantic contributions, not Flutter widgets. Feature manifests must not import `MaterialPageRoute`, `NavigationDestination`, screens, or other presentation types. The app shell owns the mapping from semantic values to presentation implementations.

`HomeScreen` stores the selected semantic section rather than a raw numeric tab index. If reactive enablement removes the currently selected feature destination, the shell falls back to the first remaining destination and keeps `NavigationBar.selectedIndex` in range. When fewer than two destinations remain, the bottom navigation bar is omitted. Settings therefore remains usable even when all feature navigation slots are disabled.

Emergency app-bar actions come from `enabledShellActions`. Disabling Emergency removes both SOS and the emergency medical-card shortcut reactively; re-enabling it restores them.

Settings composition is consumed reactively. Emergency owns the emergency profile section. Medication owns notification permission, Android exact-alarm permission, camera guidance, and reminder repair. Disabling Medication hides only those Medication-owned surfaces. Backup export/restore, the generic system-permissions launcher, appearance, language, profile, and About remain core app settings.

Onboarding composition is also reactive. Medication owns notification and Android precise-reminder permission onboarding. With Medication enabled, the existing onboarding sequence is preserved. With Medication disabled, onboarding becomes Welcome → Ready and never asks for Medication-owned permissions. Language selection and onboarding completion remain core behavior.

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
    ↓
effective capabilities + navigation + shell + settings + onboarding contributions
    ↓
reactive app-shell/settings/onboarding composition
```

Persisted overrides use stable keys:

```text
feature.<feature-id>.enabled
```

Only persisted booleans are accepted. Missing or malformed stored values fall back to the manifest default rather than implicitly enabling or disabling a feature.

Disabling a feature is not data deletion. Future feature-specific lifecycle/bootstrap code must consult effective enablement before starting feature-only background work or permission flows.

## Dependency rule

The contracts and registry remain pure Dart. Hive is isolated in the concrete enablement-store adapter; screens and feature implementations must not read feature enablement keys directly.

The app shell, Settings, and onboarding composition may depend on Riverpod providers and registry contracts; feature implementations should not make the registry depend on their internal repositories or presentation state.

## Next slices

1. Gate feature-specific initialization and lifecycle permission refresh so disabled Medication does not initialize or reconcile notification-only runtime work.
2. Define disable semantics for already-scheduled reminders and existing local feature data before adding a user-facing feature enablement surface.
3. Add the explicit user-facing feature enablement surface only after those disable semantics are enforced.
4. Add opt-in manifests only when the corresponding feature is actually shipped; do not register speculative roadmap features.
