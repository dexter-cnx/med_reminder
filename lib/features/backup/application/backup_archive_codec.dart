import 'dart:typed_data';

import '../../../core/result/result.dart';
import '../domain/entities/backup_snapshot.dart';

abstract interface class BackupArchiveCodec {
  Future<Result<Uint8List>> encode(BackupSnapshot snapshot);
  Future<Result<BackupSnapshot>> decode(Uint8List archiveBytes);
}
