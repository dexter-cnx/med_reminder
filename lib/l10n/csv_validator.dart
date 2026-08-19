import 'csv_table.dart';

class CsvValidationIssue {
  const CsvValidationIssue(this.message);
  final String message;

  @override
  String toString() => message;
}

List<CsvValidationIssue> validateTranslationCsv(String input) {
  final rows = parseCsv(input);
  if (rows.isEmpty) {
    return const <CsvValidationIssue>[CsvValidationIssue('CSV is empty.')];
  }

  final header =
      rows.first.map((value) => value.trim()).toList(growable: false);
  if (header.isEmpty || header.first != 'key') {
    return const <CsvValidationIssue>[
      CsvValidationIssue('First CSV column must be key.'),
    ];
  }

  final locales =
      header.skip(1).where((value) => value.isNotEmpty).toList(growable: false);
  final englishIndex = header.indexOf('en');
  final seenKeys = <String>{};
  final issues = <CsvValidationIssue>[];

  Set<String> placeholders(String value) => RegExp(r'\{([A-Za-z0-9_]+)\}')
      .allMatches(value)
      .map((match) => match.group(1)!)
      .toSet();

  for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    if (row.isEmpty || row.first.trim().isEmpty) continue;
    final key = row.first.trim();

    if (!seenKeys.add(key)) {
      issues.add(CsvValidationIssue('Duplicate key: $key'));
    }

    final values = <String>[];
    for (var index = 1; index < header.length; index++) {
      values.add(index < row.length ? row[index].trim() : '');
    }
    if (values.every((value) => value.isEmpty)) {
      issues.add(
        CsvValidationIssue('All translations are empty for key: $key'),
      );
    }

    if (englishIndex >= 0 && englishIndex < row.length) {
      final english = row[englishIndex].trim();
      if (english.isEmpty) {
        issues.add(
          CsvValidationIssue('English fallback is empty for key: $key'),
        );
      } else {
        final expected = placeholders(english);
        for (var index = 1; index < header.length; index++) {
          final locale = header[index].trim();
          if (locale.isEmpty || locale == 'en') continue;
          final translated = index < row.length ? row[index].trim() : '';
          if (translated.isEmpty) continue;
          final actual = placeholders(translated);
          if (actual.length != expected.length ||
              !actual.containsAll(expected)) {
            issues.add(
              CsvValidationIssue(
                'Placeholder mismatch for $key [$locale]: expected $expected, found $actual',
              ),
            );
          }
        }
      }
    }
  }

  if (locales.isEmpty) {
    issues.add(const CsvValidationIssue('No locale columns found.'));
  }
  if (englishIndex < 0) {
    issues.add(
      const CsvValidationIssue('Missing required en fallback column.'),
    );
  }

  return issues;
}
