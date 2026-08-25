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

    var previousNotificationIds = const <int>[];
    final capture = captureReminderState;
    if (capture != null) {
      final captured = capture();
      if (captured case Failed<List<int>>(:final failure)) {
        return Failed<void>(failure);
      }
      previousNotificationIds = (captured as Success<List<int>>).value;
    }

    final committed = await commit(
      (prepared as Success<PreparedBackupRestore>).value,
    );
    if (committed case Failed<void>()) return committed;

    final successCallback = onSuccess;
    if (successCallback != null) {
      return successCallback(previousNotificationIds);
    }
    return const Success<void>(null);
  }
}
