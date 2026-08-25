import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_attachment_restore_port.dart';
import 'package:med_reminder_offline/features/backup/application/backup_bundle_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/application/backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/backup_import_port.dart';
import 'package:med_reminder_offline/features/backup/application/commit_prepared_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/application/medication_backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/prepare_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/application/restore_backup_bundle.dart';
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

  test('restore is impossible before an archive is validated', () async {
    var restoreLoads = 0;
    final controller = BackupImportController(
      importPort: const _FakeImportPort(Success<BackupImportSelection?>(null)),
      codec: const ZipBackupBundleArchiveCodec(),
      loadRestore: () async {
        restoreLoads += 1;
        return _restoreReturning(const Success<void>(null));
      },
    );

    final restored = await controller.restoreSelected();

    expect(restoreLoads, 0);
    expect(restored, isA<Failed<void>>());
    expect(
      (restored as Failed<void>).failure.code,
      'backup_import_selection_missing',
    );
    expect(controller.state, isA<BackupImportState>());
    expect(controller.state.busy, isFalse);
    expect(controller.state.preview, isNull);
  });

  test('validated selection is consumed once after restore', () async {
    final fixture = await _selectionFixture();
    var restoreLoads = 0;
    final controller = BackupImportController(
      importPort: _FakeImportPort(Success<BackupImportSelection?>(fixture)),
      codec: const ZipBackupBundleArchiveCodec(),
      loadRestore: () async {
        restoreLoads += 1;
        return _restoreReturning(const Success<void>(null));
      },
    );

    final selected = await controller.selectArchive();
    expect(selected.isSuccess, isTrue);

    final firstRestore = await controller.restoreSelected();
    final secondRestore = await controller.restoreSelected();

    expect(firstRestore.isSuccess, isTrue);
    expect(restoreLoads, 1);
    expect(secondRestore, isA<Failed<void>>());
    expect(
      (secondRestore as Failed<void>).failure.code,
      'backup_import_selection_missing',
    );
    expect(controller.state.busy, isFalse);
    expect(controller.state.preview, isNull);
  });

  test(
    'post-restore reminder repair failure clears consumed selection',
    () async {
      final fixture = await _selectionFixture();
      var restoreLoads = 0;
      final controller = BackupImportController(
        importPort: _FakeImportPort(Success<BackupImportSelection?>(fixture)),
        codec: const ZipBackupBundleArchiveCodec(),
        loadRestore: () async {
          restoreLoads += 1;
          return _restoreReturning(
            const Failed<void>(
              Failure(
                code: 'backup_restore_reminder_rebuild_failed',
                message: 'Reminder rebuild failed.',
              ),
            ),
          );
        },
      );

      final selected = await controller.selectArchive();
      expect(selected.isSuccess, isTrue);

      final restored = await controller.restoreSelected();
      final retriedWithoutSelection = await controller.restoreSelected();

      expect(restoreLoads, 1);
      expect(restored, isA<Failed<void>>());
      expect(
        (restored as Failed<void>).failure.code,
        'backup_restore_reminder_rebuild_failed',
      );
      expect(controller.state.busy, isFalse);
      expect(controller.state.preview, isNull);
      expect(retriedWithoutSelection, isA<Failed<void>>());
      expect(
        (retriedWithoutSelection as Failed<void>).failure.code,
        'backup_import_selection_missing',
      );
    },
  );
}

Future<BackupImportSelection> _selectionFixture() async {
  const codec = ZipBackupBundleArchiveCodec();
  final encoded = await codec.encodeBundle(
    BackupAttachmentBundle(
      snapshot: BackupSnapshot(
        schemaVersion: BackupSnapshot.currentSchemaVersion,
        exportedAt: DateTime.utc(2026, 8, 25),
        records: const <BackupRecord>[],
      ),
      attachments: const <BackupAttachment>[],
    ),
  );
  return BackupImportSelection(
    fileName: 'besyu.zip',
    bytes: (encoded as Success<Uint8List>).value,
  );
}

RestoreBackupBundle _restoreReturning(Result<void> postRestoreResult) {
  final attachments = _FakeAttachmentRestorePort();
  return RestoreBackupBundle(
    prepare: PrepareBackupRestore(
      codec: const _EmptySuccessfulCodec(),
      attachmentRestorePort: attachments,
    ),
    commit: CommitPreparedBackupRestore(
      dataPort: const _FakeDataPort(),
      attachmentRestorePort: attachments,
    ),
    onSuccess: (_) async => postRestoreResult,
  );
}

final class _FakeImportPort implements BackupImportPort {
  const _FakeImportPort(this.result);

  final Result<BackupImportSelection?> result;

  @override
  Future<Result<BackupImportSelection?>> pickArchive() async => result;
}

final class _EmptySuccessfulCodec implements BackupBundleArchiveCodec {
  const _EmptySuccessfulCodec();

  @override
  Future<Result<BackupAttachmentBundle>> decodeBundle(
    Uint8List archiveBytes,
  ) async => Success<BackupAttachmentBundle>(
    BackupAttachmentBundle(
      snapshot: BackupSnapshot(
        schemaVersion: BackupSnapshot.currentSchemaVersion,
        exportedAt: DateTime.utc(2026, 8, 25),
        records: const <BackupRecord>[],
      ),
      attachments: const <BackupAttachment>[],
    ),
  );

  @override
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle) {
    throw UnimplementedError();
  }
}

final class _FakeAttachmentRestorePort implements BackupAttachmentRestorePort {
  @override
  Future<Result<StagedBackupAttachments>> stage(
    List<BackupAttachment> attachments,
  ) async => Success<StagedBackupAttachments>(
    StagedBackupAttachments(
      stageId: 'stage-1',
      pathsByArchivePath: const <String, StagedBackupAttachmentPath>{},
    ),
  );

  @override
  Future<Result<void>> commit(String stageId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> rollback(String stageId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> discard(String stageId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> cleanupStaleStages(Duration maxAge) async =>
      const Success<void>(null);
}

final class _FakeDataPort implements BackupDataPort {
  const _FakeDataPort();

  @override
  Future<Result<BackupSnapshot>> capture() {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> restoreAtomically(BackupSnapshot snapshot) async =>
      const Success<void>(null);
}
