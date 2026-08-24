import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_attachment_restore_port.dart';
import 'package:med_reminder_offline/features/backup/application/backup_bundle_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/application/prepare_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_attachment.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_record.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  test('preparation rewrites archive photo paths to reserved final paths',
      () async {
    final bundle = _bundle('attachments/medication/med-1.png');
    final port = _FakeRestorePort(
      staged: StagedBackupAttachments(
        stageId: 'stage-1',
        pathsByArchivePath: const <String, StagedBackupAttachmentPath>{
          'attachments/medication/med-1.png': StagedBackupAttachmentPath(
            stagedPath: '/tmp/stage-1/med-1.png',
            finalPath: '/documents/med_photos/med-1.png',
          ),
        },
      ),
    );
    final useCase = PrepareBackupRestore(
      codec: _FakeBundleCodec(bundle),
      attachmentRestorePort: port,
    );

    final result = await useCase(Uint8List(0));

    result.fold(
      onSuccess: (prepared) {
        expect(prepared.stageId, 'stage-1');
        expect(
          prepared.snapshot.records.single.payload['imagePath'],
          '/documents/med_photos/med-1.png',
        );
        expect(port.stageCalls, 1);
        expect(port.discardCalls, 0);
      },
      onFailure: (failure) => fail(failure.toString()),
    );
  });

  test('preparation stops before staging when archive decode fails', () async {
    final port = _FakeRestorePort(
      staged: StagedBackupAttachments(
        stageId: 'unused',
        pathsByArchivePath: const <String, StagedBackupAttachmentPath>{},
      ),
    );
    final useCase = PrepareBackupRestore(
      codec: const _FailingBundleCodec(),
      attachmentRestorePort: port,
    );

    final result = await useCase(Uint8List(0));

    expect(result.isFailure, isTrue);
    expect(port.stageCalls, 0);
  });

  test('missing final mapping discards staged files before failure', () async {
    final bundle = _bundle('attachments/medication/med-1.png');
    final port = _FakeRestorePort(
      staged: StagedBackupAttachments(
        stageId: 'stage-1',
        pathsByArchivePath: const <String, StagedBackupAttachmentPath>{},
      ),
    );
    final useCase = PrepareBackupRestore(
      codec: _FakeBundleCodec(bundle),
      attachmentRestorePort: port,
    );

    final result = await useCase(Uint8List(0));

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected staged mapping failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_restore_attachment_mapping_missing');
      },
    );
    expect(port.discardCalls, 1);
    expect(port.lastDiscardedStageId, 'stage-1');
  });
}

BackupAttachmentBundle _bundle(String? imagePath) => BackupAttachmentBundle(
      snapshot: BackupSnapshot(
        schemaVersion: BackupSnapshot.currentSchemaVersion,
        exportedAt: DateTime.utc(2026, 8, 25),
        records: <BackupRecord>[
          BackupRecord(
            namespace: 'medication',
            id: 'med-1',
            payload: <String, Object?>{
              'version': 1,
              'id': 'med-1',
              'imagePath': imagePath,
            },
          ),
        ],
      ),
      attachments: imagePath == null || imagePath.isEmpty
          ? const <BackupAttachment>[]
          : <BackupAttachment>[
              BackupAttachment(
                archivePath: imagePath,
                bytes: Uint8List.fromList(<int>[1, 2, 3]),
              ),
            ],
    );

final class _FakeBundleCodec implements BackupBundleArchiveCodec {
  const _FakeBundleCodec(this.bundle);

  final BackupAttachmentBundle bundle;

  @override
  Future<Result<BackupAttachmentBundle>> decodeBundle(
    Uint8List archiveBytes,
  ) async =>
      Success<BackupAttachmentBundle>(bundle);

  @override
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle) {
    throw UnimplementedError();
  }
}

final class _FailingBundleCodec implements BackupBundleArchiveCodec {
  const _FailingBundleCodec();

  @override
  Future<Result<BackupAttachmentBundle>> decodeBundle(
    Uint8List archiveBytes,
  ) async =>
      const Failed<BackupAttachmentBundle>(
        Failure(code: 'decode_failed', message: 'Decode failed.'),
      );

  @override
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle) {
    throw UnimplementedError();
  }
}

final class _FakeRestorePort implements BackupAttachmentRestorePort {
  _FakeRestorePort({required this.staged});

  final StagedBackupAttachments staged;
  int stageCalls = 0;
  int discardCalls = 0;
  String? lastDiscardedStageId;

  @override
  Future<Result<StagedBackupAttachments>> stage(
    List<BackupAttachment> attachments,
  ) async {
    stageCalls++;
    return Success<StagedBackupAttachments>(staged);
  }

  @override
  Future<Result<void>> discard(String stageId) async {
    discardCalls++;
    lastDiscardedStageId = stageId;
    return const Success<void>(null);
  }
}
