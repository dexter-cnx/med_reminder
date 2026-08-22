# Besyu App Theme System

## Scope

Theme selection is presentation-only and does not alter medication, reminder, stock, dose-log, or notification semantics.

The catalog is now **asset-driven**. Besyu Blue is the only theme that is permanently defined in Dart code; all additional themes are data entries loaded from `assets/themes/themes.json`.

## Fixed fallback

`besyu_blue` is intentionally fixed in code and cannot be overridden or deleted by the asset catalog.

It is used when:

- no theme has been selected yet;
- the persisted `app_theme_id` no longer exists in the catalog;
- `themes.json` is missing, malformed, or cannot be loaded;
- an individual asset theme entry is invalid.

This guarantees that theme data can never prevent the application from starting.

## Asset catalog

Additional themes live in:

```text
assets/themes/themes.json
```

Example entry:

```json
{
  "id": "warm_sand",
  "name": {
    "en": "Warm Sand",
    "th": "Warm Sand"
  },
  "seed": "#B47B45",
  "brightness": "light",
  "surfaceTintStrength": 0.02
}
```

Supported fields:

- `id` — stable persisted theme identifier. It must be unique and must not be `besyu_blue`.
- `name` — locale-to-display-name map. `en` is the preferred fallback when the current locale is absent.
- `seed` — `#RRGGBB` or `#AARRGGBB` Material seed color.
- `brightness` — `light` or `dark`.
- `surfaceTintStrength` — optional value from `0.0` to `1.0`.

The first asset catalog contains Warm Sand, Sage Care, Lavender Calm, and Midnight. Together with the fixed Besyu Blue fallback, the UI still exposes the original five themes.

## Adding, editing, and removing themes

No Dart theme enum or switch statement is required for additional themes.

- **Add:** append a valid entry with a new unique `id` to `themes.json`.
- **Edit:** change the asset entry while keeping its `id` stable when existing selections should continue to resolve to that theme.
- **Remove:** delete the entry. Users who previously selected the removed `id` automatically resolve to `besyu_blue` on the next startup.

Changing an existing theme `id` is semantically equivalent to deleting the old theme and adding a new one, so existing users with the old persisted value will fall back to Besyu Blue.

## Persistence

The selected theme ID is stored locally in the existing Hive `settings` box under:

```text
app_theme_id
```

`AppThemeController` validates the persisted string against the currently loaded `AppThemeCatalog`. Unknown or missing values resolve to `besyu_blue`.

Theme IDs remain strings specifically so adding a new asset theme does not require adding a Dart enum member.

## Runtime behavior

During bootstrap, Besyu loads `AppThemeCatalog` from assets before creating `AppThemeController`. The catalog is exposed through Riverpod and is shared by the application theme renderer and Settings theme picker.

`BesyuApp` watches the selected theme ID and renders:

```text
AppThemeCatalog.themeFor(themeId)
```

Theme changes apply immediately without an app restart.

Settings > Appearance reads the theme list directly from `AppThemeCatalog.themes`, so newly added asset themes automatically participate in the picker. Display names also come from the asset definition rather than a hard-coded theme-name switch.

## Safety and validation rules

- Besyu Blue remains code-owned and always available.
- Asset entries cannot override the `besyu_blue` ID.
- Invalid entries are skipped individually.
- Duplicate IDs are ignored after the first valid entry.
- A broken or missing catalog produces a one-theme catalog containing only Besyu Blue.
- Theme definitions control presentation tokens only; they cannot provide executable behavior.
- `ThemeData` construction remains in Dart and uses Material 3 `ColorScheme.fromSeed` plus shared component tokens.

## Tests

Theme tests cover:

- the fixed Besyu Blue fallback;
- adding arbitrary new asset IDs without Dart enum changes;
- prevention of `besyu_blue` override from assets;
- invalid-entry fallback behavior;
- light/dark theme construction from asset definitions.
