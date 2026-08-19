List<List<String>> parseCsv(String input) {
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

  if (quoted) {
    throw const FormatException('Unterminated quoted CSV field.');
  }

  row.add(field.toString());
  if (row.any((value) => value.isNotEmpty)) rows.add(row);
  return rows;
}
