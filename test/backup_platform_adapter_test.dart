import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/infrastructure/file_picker_backup_import_port.dart';
import 'package:med_reminder_offline/features/backup/infrastructure/share_plus_backup_export_port.dart';

void main() {
  test('file picker cancellation is a normal no-op', () async {
    const port = FilePickerBackupImportPort(picker: _cancelPicker);

    final result = await port.pickArchive();

    expect(result, isA<Success>());
    expect((result as Success).value, isNull);
  });

  test('file picker read error becomes backup_import_pick_failed', () async {
    final port = FilePickerBackupImportPort(
      picker: () async => PickedBackupArchive(
        name: 'broken.zip',
        length: () async => 12,
        readAsBytes: () async => throw const FileSystemException('read failed'),
      ),
    );

    final result = await port.pickArchive();

    expect(result, isA<Failed>());
    expect((result as Failed).failure.code, 'backup_import_pick_failed');
  });

  test('file picker rejects oversized archive before reading bytes', () async {
    var reads = 0;
    final port = FilePickerBackupImportPort(
      maximumArchiveBytes: 10,
      picker: () async => PickedBackupArchive(
        name: 'large.zip',
        length: () async => 11,
        readAsBytes: () async {
          reads++;
          return Uint8List(11);
        },
      ),
    );

    final result = await port.pickArchive();

    expect(result, isA<Failed>());
    expect((result as Failed).failure.code, 'backup_import_too_large');
    expect(reads, 0);
  });

  test('share unavailable maps to explicit adapter failure', () async {
    final root = await Directory.systemTemp.createTemp('backup_share_test_');
    addTearDown(() async => root.delete(recursive: true));
    final port = SharePlusBackupExportPort(
      temporaryDirectoryProvider: () async => root,
      shareInvoker: (_, __) async => BackupShareStatus.unavailable,
    );

    final result = await port.shareArchive(
      Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'besyu.zip',
    );

    expect(result, isA<Failed<void>>());
    expect(
      (result as Failed<void>).failure.code,
      'backup_export_share_unavailable',
    );
  });

  test(
    'share transport exception maps to backup_export_share_failed',
    () async {
      final root = await Directory.systemTemp.createTemp('backup_share_test_');
      addTearDown(() async => root.delete(recursive: true));
      final port = SharePlusBackupExportPort(
        temporaryDirectoryProvider: () async => root,
        shareInvoker: (_, __) async => throw StateError('share failed'),
      );

      final result = await port.shareArchive(
        Uint8List.fromList(<int>[4, 5]),
        fileName: 'besyu.zip',
      );

      expect(result, isA<Failed<void>>());
      expect(
        (result as Failed<void>).failure.code,
        'backup_export_share_failed',
      );
    },
  );
}

Future<PickedBackupArchive?> _cancelPicker() async => null;
