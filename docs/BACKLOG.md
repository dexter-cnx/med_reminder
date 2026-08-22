# Backlog

## Next UI milestone — App Theme System

Goal: let the user personalize Besyu without changing medication behavior, storage semantics, reminder timing, or medical data.

This should be implemented as a dedicated UI milestone rather than being mixed into the native companion work. Theme selection belongs in the existing Settings tab and persists locally in the Hive `settings` box.

### Theme architecture

- Introduce a typed theme identifier such as `BesyuThemeId` rather than storing arbitrary colors.
- Store only the selected theme ID, for example `app_theme_id`, in the local `settings` box.
- Build each theme from centralized Material 3 tokens / `ColorScheme`; screens and components must not hard-code theme-specific colors.
- Apply theme changes live without requiring an app restart.
- The selected theme must survive app restart.
- Theme state must remain independent from language preference and profile data.
- Theme choice must never affect medication dose, reminder scheduling, stock calculations, or any domain/data behavior.

### Initial five themes

1. **Besyu Blue** — default brand theme; calm blue, clean clinical-neutral surfaces.
2. **Warm Sand** — warm beige / amber family; softer and more personal than the default.
3. **Sage Care** — muted green family; calm wellness-oriented appearance without implying medical status.
4. **Lavender Calm** — lavender / violet family; softer, more expressive appearance.
5. **Midnight** — dark-first navy / charcoal family with high-contrast text and controls.

The five themes must feel materially different through coordinated primary/secondary/surface/container colors, not merely by changing one seed color.

### Settings UX

- Add an **Appearance / Theme** section to Settings.
- Show all five themes as visual preview cards or swatches with localized names.
- Tapping a theme should preview/apply it immediately.
- Clearly indicate the currently selected theme.
- Do not add a separate onboarding step for themes; theme selection is optional personalization.
- Besyu Blue remains the default when `app_theme_id` has never been stored or contains an unknown value.

### Theme tokens

Each theme should define at least:

- Material 3 `ColorScheme`
- scaffold/surface/container treatment
- AppBar and navigation colors
- cards
- buttons / FAB
- input fields
- success / warning / error semantic colors where app-specific tokens are needed
- selected/unselected navigation states

Typography, spacing, radius, and component behavior should stay shared unless a concrete design requirement justifies a theme-specific override.

### Accessibility / quality gates

- Maintain readable Material contrast for body text, buttons, navigation, disabled states, and warning/error states.
- Verify large-text layouts remain usable across all themes.
- Add tests for theme ID persistence and unknown-value fallback.
- Add widget/golden coverage for representative screens under all five themes, at minimum Home and Settings.
- Switching theme must not recreate/clear medication, dose-log, language, profile, or onboarding state.
- `make analyze`, tests, and platform build gates must remain green.

### Deferred theme extensions

Do not expand the first theme milestone into an unrestricted theme editor. Custom user colors, downloadable themes, per-theme typography packs, and cloud synchronization are separate future work.

## Features awaiting product decision

These items are documented for future evaluation but are **not approved for implementation and are not committed roadmap scope**.

### Cycle Tracking / Period Log

Status: **Awaiting product decision**.

Potential direction:

- Lightweight period start/end logging.
- Optional flow, symptom, and daily-note records.
- Deterministic estimate of the next period from user-owned history.
- Optional estimated-period reminders.
- Possible Daily Timeline / calendar projection without making Timeline the source of truth.
- Separate `cycle_tracking` bounded feature; do not add reproductive-health fields to `Medication` or a global medication profile.
- Local-first and opt-in by default, with individual-record deletion and full cycle-data deletion.
- Analytics must not collect exact cycle dates, symptoms, flow values, or free-text notes by default.
- Initial scope should remain **Period Log + Cycle Estimate**, not fertility, ovulation, pregnancy, diagnosis, contraception advice, or medical recommendations.
- Future HealthKit / Health Connect and AI/MCP access require separate permission/privacy decisions.

Detailed proposal and decision checklist: `docs/CYCLE_TRACKING_PROPOSAL.md`.

## PR #2 — Native companion features

Scope remains the native handoff described in `handoff/NATIVE_HANDOFF.md`: iOS Live Activity / Dynamic Island, watchOS, Android ongoing notification fallback, Wear OS, and real-device evidence.

PR #2 must reference the post-merge bootstrap baseline tag `v0.1.0-bootstrap-fixed`.

## PR #3 — Offline backup / restore

Goal: reduce device-loss and device-migration risk without introducing a backend or cloud account.

### Export

- Export medication records, dose logs, app-owned medication photos, and backup metadata into a versioned ZIP archive.
- Do not export scheduled notification IDs as authoritative state; reminders must be rebuilt after import.
- Include a manifest such as `backup.json` with at least:
  - schema version
  - app version
  - exported-at timestamp
  - locale/timezone metadata when useful for diagnostics
  - record/photo inventory and integrity information
- Write the archive to a temporary/app-controlled location and expose it through the platform share sheet.
- Keep the feature entirely offline. Sharing to Drive/iCloud/etc. is the user's explicit destination choice through the OS share sheet, not an application server.

### Import

- Validate archive/schema before mutating current data.
- Reject unsupported future schema versions with a clear error.
- Import through repository/application contracts rather than writing Hive boxes from presentation code.
- Restore photos into the app-owned photo directory and rewrite paths as needed.
- Rebuild reminders from imported `Medication` + `DoseLog` domain state in the current timezone.
- Run orphan-photo pruning after a successful import.
- Define duplicate/conflict behavior explicitly before implementation (replace-all is the recommended first version because it is deterministic and easy to explain).

### Tests / acceptance

- export -> import round trip preserves medications and dose logs
- photos survive the round trip and point to valid app-owned paths
- invalid/corrupt ZIP does not partially mutate existing data
- unsupported schema is rejected
- import does not resurrect expired or `untilEmpty` medications with zero remaining stock
- notification IDs are regenerated, not trusted from the archive

## Release baseline after PR #1

Only after PR #1 is merged and required CI is green, create the bootstrap baseline tag from `main`:

```bash
git checkout main
git pull --ff-only
git tag v0.1.0-bootstrap-fixed
git push origin v0.1.0-bootstrap-fixed
```

Do not create this tag from the feature branch or before PR #1 is merged.
