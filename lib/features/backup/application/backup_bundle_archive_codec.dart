import 'dart:typed_data';

import '../../../core/result/result.dart';
import '../domain/entities/backup_attachment.dart';

abstract interface class BackupBundleArchiveCodec {
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle);

  Future<Result<BackupAttachmentBundle>> decodeBundle(Uint8List archiveBytes);
}
