import 'dart:typed_data';

import '../../../core/result/result.dart';
import 'commit_prepared_backup_restore.dart';
import 'prepare_backup_restore.dart';

typedef BackupRestoreReminderStateCapture = Result<List<int>> Function();
typedef BackupRestoreSuccessCallback =
    Future<Result<void>> Function(List<int> previousNotificationIds);

final class RestoreBackupBundle {
  const RestoreBackupBundle({
    required this.prepare,
    required this.commit,
    this.captureReminderState,
    this.onSuccess,
  });

  final PrepareBackupRestore prepare;
  final CommitPreparedBackupRestore commit;
  final BackupRestoreReminderStateCapture? captureReminderState;
  final BackupRestoreSuccessCallback? onSuccess;

  Future<Result<void>> call(Uint8List archiveBytes) async {
    final prepared = await prepare(archiveBytes);
    if (prepared case Failed<PreparedBackupRestore>(:final failure)) {
      return Failed<void>(failure);
    }
    final preparedRestore = (prepared as Success<PreparedBackupRestore>).value;

    var previousNotificationIds = const <int>[];
    final capture = captureReminderState;
    if (capture != null) {
      final captured = capture();
      if (captured case Failed<List<int>>(:final failure)) {
        final discard = await prepare.attachmentRestorePort.discard(
          preparedRestore.stageId,
        );
        if (discard case Failed<void>()) {
          return const Failed<void>(
            Failure(
              code: 'backup_restore_stage_cleanup_failed',
              message:
                  'Reminder state capture failed and staged backup attachments could not be cleaned up.',
            ),
          );
        }
        return Failed<void>(failure);
      }
      previousNotificationIds = (captured as Success<List<int>>).value;
    }

    final committed = await commit(preparedRestore);
    if (committed case Failed<void>()) return committed;

    final successCallback = onSuccess;
    if (successCallback != null) {
      return successCallback(previousNotificationIds);
    }
    return const Success<void>(null);
  }
}
