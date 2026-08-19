import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

class SingleCsvAssetLoader extends AssetLoader {
  const SingleCsvAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final rows = _parseCsv(await rootBundle.loadString(path));
    if (rows.isEmpty) return <String, dynamic>{};
    final header = rows.first;
    final fallbackIndex = header.indexOf('en');
    final requestedIndex = header.indexOf(locale.languageCode);
    final targetIndex = requestedIndex >= 0 ? requestedIndex : fallbackIndex;
    if (targetIndex < 0) return <String, dynamic>{};

    final output = <String, dynamic>{};
    for (final row in rows.skip(1)) {
      if (row.isEmpty || row.first.trim().isEmpty) continue;
      final key = row.first.trim();
      var value = targetIndex < row.length ? row[targetIndex].trim() : '';
      if (value.isEmpty && fallbackIndex >= 0 && fallbackIndex < row.length) {
        value = row[fallbackIndex].trim();
      }
      output[key] = value;
    }
    return output;
  }

  static Future<List<Locale>> detectLocalesFromCsv(String path) async {
    final rows = _parseCsv(await rootBundle.loadString(path));
    if (rows.isEmpty) return const <Locale>[Locale('en')];
    return rows.first
        .skip(1)
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .map(Locale.new)
        .toList();
  }

  static List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        if (quoted && i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(char);
      }
    }
    row.add(field.toString());
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
    return rows;
  }
}
