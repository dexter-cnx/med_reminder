import 'dart:io';

import '../lib/l10n/csv_validator.dart';

const _defaultSourcePath = 'assets/translations.csv';

void main(List<String> arguments) {
  final sourcePath = arguments.isEmpty ? _defaultSourcePath : arguments.first;
  final source = File(sourcePath);

  if (!source.existsSync()) {
    stderr.writeln('Missing localization source: $sourcePath');
    exitCode = 1;
    return;
  }

  final issues = validateTranslationCsv(source.readAsStringSync());
  if (issues.isEmpty) {
    stdout.writeln('Localization CSV is valid: $sourcePath');
    return;
  }

  for (final issue in issues) {
    stderr.writeln('localization: $issue');
  }
  exitCode = 1;
}
