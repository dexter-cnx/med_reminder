# CSV Localization Pipeline

`assets/translations.csv` is the single editable translation source, but it is **not a Flutter runtime asset**.

```csv
key,en,th
app_title,Med Reminder,เตือนกินยา
```

The first column is the translation key. Remaining columns are locale language codes. English (`en`) is required as the fallback source.

## Generate runtime assets

```bash
make l10n-generate
```

This generates:

```text
assets/translations/en.json
assets/translations/th.json
lib/l10n/generated_locales.dart
```

Runtime `easy_localization` loads the generated JSON files from `assets/translations/`; the app never parses or loads the CSV at startup. `pubspec.yaml` bundles only the generated JSON directory, not `assets/translations.csv`.

Empty values in non-English locale columns are resolved to the English value during generation, so fallback normalization happens before the app is built.

## Add a language

Add a locale column to the CSV, for example:

```csv
key,en,th,ja
```

Then run `make l10n-generate`. The generator creates `ja.json` and updates `generated_locales.dart` automatically.

## Validation

`make l10n-check` validates the CSV and verifies that committed JSON/locales are byte-for-byte up to date. CI fails on duplicate keys, missing English fallback, empty translation rows, placeholder mismatches, stale generated files, or unexpected generated locale JSON files.
