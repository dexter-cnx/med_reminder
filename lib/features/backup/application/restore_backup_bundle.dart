import 'dart:typed_data';

import '../../../core/result/result.dart';
import 'commit_prepared_backup_restore.dart';
import 'prepare_backup_restore.dart';

final class RestoreBackupBundle {
  const RestoreBackupBundle({
    required this.prepare,
    required this.commit,
  });

  final PrepareBackupRestore prepare;
  final CommitPreparedBackupRestore commit;

  Future<Result<void>> call(Uint8List archiveBytes) async {
    final prepared = await prepare(archiveBytes);
    if (prepared case Failed<PreparedBackupRestore>(:final failure)) {
      return Failed<void>(failure);
    }

    return commit((prepared as Success<PreparedBackupRestore>).value);
  }
}
