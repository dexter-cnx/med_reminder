import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_import_port.dart';
import 'package:med_reminder_offline/features/backup/application/medication_backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/zip_backup_bundle_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_attachment.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_record.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';
import 'package:med_reminder_offline/features/backup/presentation/providers/backup_import_providers.dart';

void main() {
  test(
    'selecting a valid archive previews it without loading restore',
    () async {
      const codec = ZipBackupBundleArchiveCodec();
      final exportedAt = DateTime.utc(2026, 8, 25, 4, 30);
      final encoded = await codec.encodeBundle(
        BackupAttachmentBundle(
          snapshot: BackupSnapshot(
            schemaVersion: BackupSnapshot.currentSchemaVersion,
            exportedAt: exportedAt,
            records: <BackupRecord>[
              BackupRecord(
                namespace: MedicationBackupDataPort.medicationNamespace,
                id: 'med-1',
                payload: const <String, Object?>{'imagePath': ''},
              ),
              BackupRecord(
                namespace: MedicationBackupDataPort.doseLogNamespace,
                id: 'log-1',
                payload: const <String, Object?>{},
              ),
            ],
          ),
          attachments: const <BackupAttachment>[],
        ),
      );
      expect(encoded, isA<Success<Uint8List>>());

      var restoreLoads = 0;
      final controller = BackupImportController(
        importPort: _FakeImportPort(
          Success<BackupImportSelection?>(
            BackupImportSelection(
              fileName: 'besyu.zip',
              bytes: (encoded as Success<Uint8List>).value,
            ),
          ),
        ),
        codec: codec,
        loadRestore: () async {
          restoreLoads += 1;
          throw StateError('restore must not load during preview');
        },
      );

      final selected = await controller.selectArchive();

      expect(restoreLoads, 0);
      expect(selected, isA<Success<BackupImportPreview?>>());
      final preview = (selected as Success<BackupImportPreview?>).value!;
      expect(preview.fileName, 'besyu.zip');
      expect(preview.exportedAt, exportedAt);
      expect(preview.medicationCount, 1);
      expect(preview.doseLogCount, 1);
      expect(preview.attachmentCount, 0);
      expect(controller.state.busy, isFalse);
      expect(controller.state.preview, same(preview));
    },
  );

  test('picker cancellation is a no-op with no restore load', () async {
    var restoreLoads = 0;
    final controller = BackupImportController(
      importPort: const _FakeImportPort(Success<BackupImportSelection?>(null)),
      codec: const ZipBackupBundleArchiveCodec(),
      loadRestore: () async {
        restoreLoads += 1;
        throw StateError('restore must not load after picker cancellation');
      },
    );

    final selected = await controller.selectArchive();

    expect(restoreLoads, 0);
    expect(selected, isA<Success<BackupImportPreview?>>());
    expect((selected as Success<BackupImportPreview?>).value, isNull);
    expect(controller.state.busy, isFalse);
    expect(controller.state.preview, isNull);
  });

  test(
    'unsupported schema is rejected before confirmation or restore load',
    () async {
      const codec = ZipBackupBundleArchiveCodec();
      final encoded = await codec.encodeBundle(
        BackupAttachmentBundle(
          snapshot: BackupSnapshot(
            schemaVersion: BackupSnapshot.currentSchemaVersion + 1,
            exportedAt: DateTime.utc(2026, 8, 25),
            records: const <BackupRecord>[],
          ),
          attachments: const <BackupAttachment>[],
        ),
      );
      expect(encoded, isA<Success<Uint8List>>());

      var restoreLoads = 0;
      final controller = BackupImportController(
        importPort: _FakeImportPort(
          Success<BackupImportSelection?>(
            BackupImportSelection(
              fileName: 'future.zip',
              bytes: (encoded as Success<Uint8List>).value,
            ),
          ),
        ),
        codec: codec,
        loadRestore: () async {
          restoreLoads += 1;
          throw StateError('restore must not load for unsupported schema');
        },
      );

      final selected = await controller.selectArchive();

      expect(restoreLoads, 0);
      expect(selected, isA<Failed<BackupImportPreview?>>());
      expect(
        (selected as Failed<BackupImportPreview?>).failure.code,
        'backup_manifest_version_unsupported',
      );
      expect(controller.state.preview, isNull);
    },
  );
}

final class _FakeImportPort implements BackupImportPort {
  const _FakeImportPort(this.result);

  final Result<BackupImportSelection?> result;

  @override
  Future<Result<BackupImportSelection?>> pickArchive() async => result;
}
