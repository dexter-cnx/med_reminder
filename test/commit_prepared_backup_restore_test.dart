import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_attachment_restore_port.dart';
import 'package:med_reminder_offline/features/backup/application/backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/commit_prepared_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/application/prepare_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_attachment.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  test('commits files before restoring data', () async {
    final events = <String>[];
    final attachments = _FakeAttachmentRestorePort(events: events);
    final dataPort = _FakeDataPort(events: events);
    final useCase = CommitPreparedBackupRestore(
      dataPort: dataPort,
      attachmentRestorePort: attachments,
    );

    final result = await useCase(_prepared());

    expect(result.isSuccess, isTrue);
    expect(events, <String>['commit:stage-1', 'restore']);
    expect(attachments.rollbackCalls, 0);
  });

  test('file commit failure leaves data untouched', () async {
    final events = <String>[];
    final attachments = _FakeAttachmentRestorePort(
      events: events,
      commitResult: const Failed<void>(
        Failure(code: 'file_commit_failed', message: 'Commit failed.'),
      ),
    );
    final dataPort = _FakeDataPort(events: events);
    final useCase = CommitPreparedBackupRestore(
      dataPort: dataPort,
      attachmentRestorePort: attachments,
    );

    final result = await useCase(_prepared());

    expect(result.isFailure, isTrue);
    expect(events, <String>['commit:stage-1']);
    expect(dataPort.restoreCalls, 0);
  });

  test('data restore failure rolls committed files back', () async {
    final events = <String>[];
    final attachments = _FakeAttachmentRestorePort(events: events);
    final dataPort = _FakeDataPort(
      events: events,
      restoreResult: const Failed<void>(
        Failure(code: 'data_restore_failed', message: 'Restore failed.'),
      ),
    );
    final useCase = CommitPreparedBackupRestore(
      dataPort: dataPort,
      attachmentRestorePort: attachments,
    );

    final result = await useCase(_prepared());

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected data restore failure.'),
      onFailure: (failure) => expect(failure.code, 'data_restore_failed'),
    );
    expect(
      events,
      <String>['commit:stage-1', 'restore', 'rollback:stage-1'],
    );
  });

  test('rollback failure surfaces explicit transactional failure', () async {
    final events = <String>[];
    final attachments = _FakeAttachmentRestorePort(
      events: events,
      rollbackResult: const Failed<void>(
        Failure(code: 'rollback_failed', message: 'Rollback failed.'),
      ),
    );
    final dataPort = _FakeDataPort(
      events: events,
      restoreResult: const Failed<void>(
        Failure(code: 'data_restore_failed', message: 'Restore failed.'),
      ),
    );
    final useCase = CommitPreparedBackupRestore(
      dataPort: dataPort,
      attachmentRestorePort: attachments,
    );

    final result = await useCase(_prepared());

    result.fold(
      onSuccess: (_) => fail('Expected rollback failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_restore_attachment_rollback_failed');
      },
    );
  });
}

PreparedBackupRestore _prepared() => PreparedBackupRestore(
      snapshot: BackupSnapshot(
        schemaVersion: BackupSnapshot.currentSchemaVersion,
        exportedAt: DateTime.utc(2026, 8, 25),
        records: const [],
      ),
      stageId: 'stage-1',
    );

final class _FakeDataPort implements BackupDataPort {
  _FakeDataPort({
    required this.events,
    this.restoreResult = const Success<void>(null),
  });

  final List<String> events;
  final Result<void> restoreResult;
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
    events.add('restore');
    return restoreResult;
  }
}

final class _FakeAttachmentRestorePort implements BackupAttachmentRestorePort {
  _FakeAttachmentRestorePort({
    required this.events,
    this.commitResult = const Success<void>(null),
    this.rollbackResult = const Success<void>(null),
  });

  final List<String> events;
  final Result<void> commitResult;
  final Result<void> rollbackResult;
  int rollbackCalls = 0;

  @override
  Future<Result<StagedBackupAttachments>> stage(
    List<BackupAttachment> attachments,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> commit(String stageId) async {
    events.add('commit:$stageId');
    return commitResult;
  }

  @override
  Future<Result<void>> rollback(String stageId) async {
    rollbackCalls++;
    events.add('rollback:$stageId');
    return rollbackResult;
  }

  @override
  Future<Result<void>> discard(String stageId) {
    throw UnimplementedError();
  }
}
