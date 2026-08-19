# CSV Localization

Source: `assets/translations.csv`

```csv
key,en,th
app_title,Med Reminder,เตือนกินยา
```

The first column is always the key. Remaining columns are locale language codes. Adding `ja` to the header and values automatically adds `Locale('ja')` to `supportedLocales`.

When the selected language has an empty cell, the loader uses the English cell for that key.
