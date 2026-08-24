import '../../../core/result/result.dart';
import '../domain/entities/backup_snapshot.dart';

abstract interface class BackupDataPort {
  Future<Result<BackupSnapshot>> capture();

  /// Replaces all backup-owned application data as one logical transaction.
  ///
  /// Implementations must validate and stage incoming data before mutation.
  /// A failure must leave the pre-import application state intact.
  Future<Result<void>> restoreAtomically(BackupSnapshot snapshot);
}
