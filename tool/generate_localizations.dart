import 'dart:convert';
import 'dart:io';

import '../lib/l10n/csv_table.dart';
import '../lib/l10n/csv_validator.dart';

const _sourcePath = 'assets/translations.csv';
const _outputDirectory = 'assets/translations';
const _generatedLocalesPath = 'lib/l10n/generated_locales.dart';

Future<void> main(List<String> arguments) async {
  final checkOnly = arguments.contains('--check');
  final source = File(_sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('Missing localization source: $_sourcePath');
    exitCode = 1;
    return;
  }

  final csv = source.readAsStringSync();
  final issues = validateTranslationCsv(csv);
  if (issues.isNotEmpty) {
    for (final issue in issues) {
      stderr.writeln('localization: $issue');
    }
    exitCode = 1;
    return;
  }

  final rows = parseCsv(csv);
  final header =
      rows.first.map((value) => value.trim()).toList(growable: false);
  final locales =
      header.skip(1).where((value) => value.isNotEmpty).toList(growable: false);
  final englishIndex = header.indexOf('en');
  final expectedFiles = <String, String>{};

  for (var localeIndex = 1; localeIndex < header.length; localeIndex++) {
    final locale = header[localeIndex].trim();
    if (locale.isEmpty) continue;

    final translations = <String, String>{};
    for (final row in rows.skip(1)) {
      if (row.isEmpty || row.first.trim().isEmpty) continue;
      final key = row.first.trim();
      var value = localeIndex < row.length ? row[localeIndex].trim() : '';
      if (value.isEmpty) {
        value = englishIndex < row.length ? row[englishIndex].trim() : '';
      }
      translations[key] = value;
    }
    expectedFiles['$_outputDirectory/$locale.json'] =
        '${jsonEncode(translations)}\n';
  }

  expectedFiles[_generatedLocalesPath] = _renderLocales(locales);

  if (checkOnly) {
    var valid = true;
    for (final entry in expectedFiles.entries) {
      final file = File(entry.key);
      if (!file.existsSync() || file.readAsStringSync() != entry.value) {
        stderr.writeln('Generated localization is stale: ${entry.key}');
        valid = false;
      }
    }

    final outputDirectory = Directory(_outputDirectory);
    if (outputDirectory.existsSync()) {
      final expectedJsonPaths = expectedFiles.keys
          .where((path) =>
              path.startsWith('$_outputDirectory/') && path.endsWith('.json'))
          .toSet();
      for (final entity in outputDirectory.listSync()) {
        if (entity is File &&
            entity.path.endsWith('.json') &&
            !expectedJsonPaths.contains(entity.path)) {
          stderr.writeln('Unexpected generated localization: ${entity.path}');
          valid = false;
        }
      }
    }

    if (!valid) exitCode = 1;
    return;
  }

  Directory(_outputDirectory).createSync(recursive: true);
  for (final entry in expectedFiles.entries) {
    final file = File(entry.key);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }

  final expectedJsonNames = locales.map((locale) => '$locale.json').toSet();
  for (final entity in Directory(_outputDirectory).listSync()) {
    if (entity is File && entity.path.endsWith('.json')) {
      final name = entity.uri.pathSegments.last;
      if (!expectedJsonNames.contains(name)) entity.deleteSync();
    }
  }

  stdout.writeln(
      'Generated ${locales.length} locale JSON files from $_sourcePath.');
}

String _renderLocales(List<String> locales) {
  final buffer = StringBuffer()
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln()
    ..writeln('// GENERATED FILE. DO NOT EDIT.')
    ..writeln('// Source: assets/translations.csv')
    ..writeln('const supportedLocales = <Locale>[');
  for (final locale in locales) {
    buffer.writeln("  Locale('$locale'),");
  }
  buffer.writeln('];');
  return buffer.toString();
}
