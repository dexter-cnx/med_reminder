import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../core/result/result.dart';
import '../application/backup_import_port.dart';

typedef BackupArchivePicker = Future<PickedBackupArchive?> Function();

final class PickedBackupArchive {
  const PickedBackupArchive({
    required this.name,
    required this.length,
    required this.readAsBytes,
  });

  final String name;
  final Future<int> Function() length;
  final Future<Uint8List> Function() readAsBytes;
}

final class FilePickerBackupImportPort implements BackupImportPort {
  const FilePickerBackupImportPort({
    this.maximumArchiveBytes = 256 * 1024 * 1024,
    BackupArchivePicker? picker,
  }) : _picker = picker ?? _pickArchive;

  final int maximumArchiveBytes;
  final BackupArchivePicker _picker;

  @override
  Future<Result<BackupImportSelection?>> pickArchive() async {
    try {
      final file = await _picker();
      if (file == null) {
        return const Success<BackupImportSelection?>(null);
      }

      final size = await file.length();
      if (size > maximumArchiveBytes) {
        return const Failed<BackupImportSelection?>(
          Failure(
            code: 'backup_import_too_large',
            message: 'The selected backup archive is too large to import.',
          ),
        );
      }

      final bytes = await file.readAsBytes();
      if (bytes.length > maximumArchiveBytes) {
        return const Failed<BackupImportSelection?>(
          Failure(
            code: 'backup_import_too_large',
            message: 'The selected backup archive is too large to import.',
          ),
        );
      }
      return Success<BackupImportSelection?>(
        BackupImportSelection.takeOwnership(fileName: file.name, bytes: bytes),
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

  static Future<PickedBackupArchive?> _pickArchive() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
    );
    if (file == null) return null;
    return PickedBackupArchive(
      name: file.name,
      length: file.length,
      readAsBytes: file.readAsBytes,
    );
  }
}
