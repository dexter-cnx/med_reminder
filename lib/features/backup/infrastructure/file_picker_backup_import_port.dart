import 'package:file_picker/file_picker.dart';

import '../../../core/result/result.dart';
import '../application/backup_import_port.dart';

final class FilePickerBackupImportPort implements BackupImportPort {
  const FilePickerBackupImportPort({
    this.maximumArchiveBytes = 256 * 1024 * 1024,
  });

  final int maximumArchiveBytes;

  @override
  Future<Result<BackupImportSelection?>> pickArchive() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const <String>['zip'],
      );
      if (result == null || result.files.isEmpty) {
        return const Success<BackupImportSelection?>(null);
      }

      final file = result.files.single;
      if (file.size > maximumArchiveBytes) {
        return const Failed<BackupImportSelection?>(
          Failure(
            code: 'backup_import_too_large',
            message: 'The selected backup archive is too large to import.',
          ),
        );
      }

      final bytes = await file.xFile.readAsBytes();
      if (bytes.length > maximumArchiveBytes) {
        return const Failed<BackupImportSelection?>(
          Failure(
            code: 'backup_import_too_large',
            message: 'The selected backup archive is too large to import.',
          ),
        );
      }
      return Success<BackupImportSelection?>(
        BackupImportSelection(fileName: file.name, bytes: bytes),
      );
    } on Object {
      return const Failed<BackupImportSelection?>(
        Failure(
          code: 'backup_import_pick_failed',
          message: 'The backup archive could not be selected or read.',
        ),
      );
    }
  }
}
