import 'dart:typed_data';

import '../../../core/result/result.dart';

final class BackupImportSelection {
  BackupImportSelection({required this.fileName, required Uint8List bytes})
    : bytes = Uint8List.fromList(bytes);

  final String fileName;
  final Uint8List bytes;
}

abstract interface class BackupImportPort {
  Future<Result<BackupImportSelection?>> pickArchive();
}
