import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_attachment_restore_port.dart';
import 'package:med_reminder_offline/features/backup/application/backup_bundle_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/application/backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/commit_prepared_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/application/prepare_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/application/restore_backup_bundle.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_attachment.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  test('coordinator stops before staging when decode fails', () async {
    final attachments = _FakeAttachmentRestorePort();
    final dataPort = _FakeDataPort();
    final restore = RestoreBackupBundle(
      prepare: PrepareBackupRestore(
        codec: const _FailingCodec(),
        attachmentRestorePort: attachments,
      ),
      commit: CommitPreparedBackupRestore(
        dataPort: dataPort,
        attachmentRestorePort: attachments,
      ),
    );

    final result = await restore(Uint8List(0));

    expect(result.isFailure, isTrue);
    expect(attachments.stageCalls, 0);
    expect(attachments.commitCalls, 0);
    expect(dataPort.restoreCalls, 0);
  });

  test('coordinator stages, commits files, then restores data', () async {
    final attachments = _FakeAttachmentRestorePort();
    final dataPort = _FakeDataPort();
    final restore = RestoreBackupBundle(
      prepare: PrepareBackupRestore(
        codec: _SuccessfulCodec(_bundle()),
        attachmentRestorePort: attachments,
      ),
      commit: CommitPreparedBackupRestore(
        dataPort: dataPort,
        attachmentRestorePort: attachments,
      ),
    );

    final result = await restore(Uint8List(0));

    expect(result.isSuccess, isTrue);
    expect(attachments.stageCalls, 1);
    expect(attachments.commitCalls, 1);
    expect(dataPort.restoreCalls, 1);
    expect(attachments.events, <String>['stage', 'commit:stage-1']);
  });
}

BackupAttachmentBundle _bundle() => BackupAttachmentBundle(
      snapshot: BackupSnapshot(
        schemaVersion: BackupSnapshot.currentSchemaVersion,
        exportedAt: DateTime.utc(2026, 8, 25),
        records: const [],
      ),
      attachments: const <BackupAttachment>[],
    );

final class _SuccessfulCodec implements BackupBundleArchiveCodec {
  const _SuccessfulCodec(this.bundle);

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

final class _FailingCodec implements BackupBundleArchiveCodec {
  const _FailingCodec();

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

final class _FakeAttachmentRestorePort implements BackupAttachmentRestorePort {
  int stageCalls = 0;
  int commitCalls = 0;
  final List<String> events = <String>[];

  @override
  Future<Result<StagedBackupAttachments>> stage(
    List<BackupAttachment> attachments,
  ) async {
    stageCalls++;
    events.add('stage');
    return Success<StagedBackupAttachments>(
      StagedBackupAttachments(
        stageId: 'stage-1',
        pathsByArchivePath: const <String, StagedBackupAttachmentPath>{},
      ),
    );
  }

  @override
  Future<Result<void>> commit(String stageId) async {
    commitCalls++;
    events.add('commit:$stageId');
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> rollback(String stageId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> discard(String stageId) async =>
      const Success<void>(null);
}

final class _FakeDataPort implements BackupDataPort {
  int restoreCalls = 0;

  @override
  Future<Result<BackupSnapshot>> capture() async => Success<BackupSnapshot>(
        BackupSnapshot(
          schemaVersion: BackupSnapshot.currentSchemaVersion,
          exportedAt: DateTime.utc(2026, 8, 25),
          records: const [],
        ),
      );

  @override
  Future<Result<void>> restoreAtomically(BackupSnapshot snapshot) async {
    restoreCalls++;
    return const Success<void>(null);
  }
}
