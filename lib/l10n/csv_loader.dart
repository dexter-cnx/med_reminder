import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

import 'csv_table.dart';

class SingleCsvAssetLoader extends AssetLoader {
  const SingleCsvAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final rows = parseCsv(await rootBundle.loadString(path));
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
    final rows = parseCsv(await rootBundle.loadString(path));
    if (rows.isEmpty) return const <Locale>[Locale('en')];
    return rows.first
        .skip(1)
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .map(Locale.new)
        .toList();
  }
}
