import 'dart:io';
import 'dart:typed_data';

import '../../../core/result/result.dart';
import '../application/backup_attachment_source.dart';

final class FileBackupAttachmentSource implements BackupAttachmentSource {
  const FileBackupAttachmentSource();

  @override
  Future<Result<Uint8List>> read(String sourcePath) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        return const Failed<Uint8List>(
          Failure(
            code: 'backup_attachment_missing',
            message: 'A referenced backup attachment does not exist.',
          ),
        );
      }
      return Success<Uint8List>(await file.readAsBytes());
    } on Object {
      return const Failed<Uint8List>(
        Failure(
          code: 'backup_attachment_read_failed',
          message: 'A referenced backup attachment could not be read.',
        ),
      );
    }
  }
}
