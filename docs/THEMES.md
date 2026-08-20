# Besyu App Theme System

## Scope

Besyu provides five selectable Material 3 themes. Theme selection is presentation-only and does not alter medication, reminder, stock, dose-log, or notification semantics.

## Presets

1. `besyu_blue` — Besyu Blue, the default light theme.
2. `warm_sand` — Warm Sand, a warm neutral light theme.
3. `sage_care` — Sage Care, a calm green light theme.
4. `lavender_calm` — Lavender Calm, a soft violet light theme.
5. `midnight` — Midnight, a dark-first theme.

Each preset owns a complete `ThemeData` generated from a dedicated Material 3 color scheme plus shared component tokens for cards, navigation, text fields, buttons, and floating actions.

## Persistence

The selected preset is stored locally in the existing Hive `settings` box under:

```text
app_theme_id
```

Unknown or missing values fall back to `besyu_blue`.

`AppThemeController` is the single write boundary. Selecting a theme persists it before publishing the new Riverpod state.

## Runtime behavior

`BesyuApp` watches `appThemeProvider` and rebuilds `MaterialApp.theme` immediately when the selection changes. No restart is required.

The Settings > Appearance section shows all five presets with a compact color preview and selected-state indicator.

## Accessibility / validation

- All themes use Material 3 generated color schemes rather than isolated hard-coded foreground/background pairs.
- Midnight uses `Brightness.dark`; the other four presets use `Brightness.light`.
- Tests assert the five-preset contract, default fallback, brightness policy, and distinct primary colors.
- Existing widget/accessibility tests continue to run under CI so theme changes cannot bypass the normal regression gate.
