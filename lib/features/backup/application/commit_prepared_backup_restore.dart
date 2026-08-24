import '../../../core/result/result.dart';
import 'backup_attachment_restore_port.dart';
import 'backup_data_port.dart';
import 'prepare_backup_restore.dart';

class CommitPreparedBackupRestore {
  const CommitPreparedBackupRestore({
    required this.dataPort,
    required this.attachmentRestorePort,
  });

  final BackupDataPort dataPort;
  final BackupAttachmentRestorePort attachmentRestorePort;

  Future<Result<void>> call(PreparedBackupRestore prepared) async {
    final fileCommit = await attachmentRestorePort.commit(prepared.stageId);
    if (fileCommit case Failed<void>(:final failure)) {
      return Failed<void>(failure);
    }

    final dataRestore = await dataPort.restoreAtomically(prepared.snapshot);
    if (dataRestore case Success<void>()) {
      return const Success<void>(null);
    }

    final dataFailure = (dataRestore as Failed<void>).failure;
    final fileRollback = await attachmentRestorePort.rollback(prepared.stageId);
    if (fileRollback case Failed<void>()) {
      return const Failed<void>(
        Failure(
          code: 'backup_restore_attachment_rollback_failed',
          message:
              'Backup data restore failed and committed attachments could not be rolled back.',
        ),
      );
    }

    return Failed<void>(dataFailure);
  }
}
