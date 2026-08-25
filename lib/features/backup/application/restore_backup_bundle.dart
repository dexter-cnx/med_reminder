import 'dart:typed_data';

import '../../../core/result/result.dart';
import 'commit_prepared_backup_restore.dart';
import 'prepare_backup_restore.dart';

typedef BackupRestoreSuccessCallback = Future<Result<void>> Function();

final class RestoreBackupBundle {
  const RestoreBackupBundle({
    required this.prepare,
    required this.commit,
    this.onSuccess,
  });

  final PrepareBackupRestore prepare;
  final CommitPreparedBackupRestore commit;
  final BackupRestoreSuccessCallback? onSuccess;

  Future<Result<void>> call(Uint8List archiveBytes) async {
    final prepared = await prepare(archiveBytes);
    if (prepared case Failed<PreparedBackupRestore>(:final failure)) {
      return Failed<void>(failure);
    }

    final committed =
        await commit((prepared as Success<PreparedBackupRestore>).value);
    if (committed case Failed<void>()) return committed;

    final successCallback = onSuccess;
    if (successCallback != null) {
      return successCallback();
    }
    return const Success<void>(null);
  }
}
