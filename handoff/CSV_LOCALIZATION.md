# CSV Localization

`assets/translations.csv` is the single source of truth for translators and developers, but it is **not** loaded by the app at runtime.

The build/development pipeline validates the CSV and generates compact JSON assets under `assets/translations/`. `easy_localization` loads those JSON files directly in production.

## Source format

```csv
key,en,th
app_title,Med Reminder,เตือนกินยา
```

The first column is always `key`. Remaining columns are locale language codes. English (`en`) is required as the fallback source.

## Validate

Run the standalone validator when editing translations:

```bash
dart run tool/validate_translations.dart
# or
make l10n-validate
```

The validator fails on:

- duplicate keys
- missing or empty English fallback values
- rows where all translations are empty
- placeholder mismatches, such as `{count}` existing in English but missing from a non-empty Thai translation

## Generate runtime JSON

```bash
make l10n-generate
```

This writes deterministic compact JSON files such as:

```text
assets/translations/en.json
assets/translations/th.json
```

It also regenerates `lib/l10n/generated_locales.dart` from the CSV header. Adding a `ja` column therefore adds both `assets/translations/ja.json` and `Locale('ja')` after generation.

Empty non-English cells are resolved to the English fallback during generation, so runtime does not need CSV parsing or per-cell fallback logic.

## CI stale-output gate

```bash
make l10n-check
```

This runs validation and then verifies that every generated JSON file and the generated locale list exactly match the CSV source. CI fails when a developer changes the CSV but forgets to regenerate outputs, or when a removed locale leaves a stale JSON file behind.

Only `assets/translations/` is declared as a Flutter asset. `assets/translations.csv` remains a repository source file and is not bundled for runtime loading.
