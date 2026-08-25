import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/backup/application/backup_import_port.dart';

void main() {
  test('default selection defensively copies caller-owned bytes', () {
    final source = Uint8List.fromList(<int>[1, 2, 3]);
    final selection = BackupImportSelection(
      fileName: 'backup.zip',
      bytes: source,
    );

    source[0] = 9;

    expect(selection.bytes, <int>[1, 2, 3]);
    expect(() => selection.bytes[0] = 7, throwsUnsupportedError);
  });

  test('takeOwnership avoids a second archive copy and is read-only', () {
    final source = Uint8List.fromList(<int>[1, 2, 3]);
    final selection = BackupImportSelection.takeOwnership(
      fileName: 'backup.zip',
      bytes: source,
    );

    source[0] = 9;

    expect(selection.bytes, <int>[9, 2, 3]);
    expect(() => selection.bytes[0] = 7, throwsUnsupportedError);
  });
}
