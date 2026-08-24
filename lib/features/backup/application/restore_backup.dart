import 'dart:typed_data';

import '../../../core/result/result.dart';
import '../domain/entities/backup_snapshot.dart';
import 'backup_archive_codec.dart';
import 'backup_data_port.dart';

class RestoreBackup {
  const RestoreBackup({required this.dataPort, required this.codec});

  final BackupDataPort dataPort;
  final BackupArchiveCodec codec;

  Future<Result<void>> call(Uint8List archiveBytes) async {
    final decoded = await codec.decode(archiveBytes);
    return decoded.fold(
      onSuccess: (snapshot) async {
        if (!snapshot.isCurrentSchema) {
          return Failed<void>(
            Failure(
              code: 'backup_unsupported_schema',
              message:
                  'Unsupported backup schema ${snapshot.schemaVersion}; expected ${BackupSnapshot.currentSchemaVersion}.',
            ),
          );
        }
        return dataPort.restoreAtomically(snapshot);
      },
      onFailure: (failure) async => Failed<void>(failure),
    );
  }
}
