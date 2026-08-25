import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/commit_prepared_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/application/prepare_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/application/restore_backup_bundle.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  test('coordinator stops when preparation fails', () async {
    final commit = _FakeCommit();
    final restore = RestoreBackupBundle(
      prepare: _FailingPrepare(),
      commit: commit,
    );

    final result = await restore(Uint8List(0));

    expect(result.isFailure, isTrue);
    expect(commit.calls, 0);
  });

  test('coordinator commits prepared restore', () async {
    final prepared = PreparedBackupRestore(
      snapshot: BackupSnapshot(
        schemaVersion: BackupSnapshot.currentSchemaVersion,
        exportedAt: DateTime.utc(2026, 8, 25),
        records: const [],
      ),
      stageId: 'stage-1',
    );
    final commit = _FakeCommit();
    final restore = RestoreBackupBundle(
      prepare: _SuccessfulPrepare(prepared),
      commit: commit,
    );

    final result = await restore(Uint8List(0));

    expect(result.isSuccess, isTrue);
    expect(commit.calls, 1);
    expect(commit.lastStageId, 'stage-1');
  });
}

final class _FailingPrepare extends PrepareBackupRestore {
  _FailingPrepare()
      : super(
          codec: throw UnimplementedError(),
          attachmentRestorePort: throw UnimplementedError(),
        );

  @override
  Future<Result<PreparedBackupRestore>> call(Uint8List archiveBytes) async =>
      const Failed<PreparedBackupRestore>(
        Failure(code: 'prepare_failed', message: 'Preparation failed.'),
      );
}

final class _SuccessfulPrepare extends PrepareBackupRestore {
  _SuccessfulPrepare(this.prepared)
      : super(
          codec: throw UnimplementedError(),
          attachmentRestorePort: throw UnimplementedError(),
        );

  final PreparedBackupRestore prepared;

  @override
  Future<Result<PreparedBackupRestore>> call(Uint8List archiveBytes) async =>
      Success<PreparedBackupRestore>(prepared);
}

final class _FakeCommit extends CommitPreparedBackupRestore {
  _FakeCommit()
      : super(
          dataPort: throw UnimplementedError(),
          attachmentRestorePort: throw UnimplementedError(),
        );

  int calls = 0;
  String? lastStageId;

  @override
  Future<Result<void>> call(PreparedBackupRestore prepared) async {
    calls++;
    lastStageId = prepared.stageId;
    return const Success<void>(null);
  }
}
