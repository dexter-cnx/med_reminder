import 'dart:typed_data';

import '../../../core/result/result.dart';

abstract interface class BackupExportPort {
  Future<Result<void>> shareArchive(
    Uint8List archiveBytes, {
    required String fileName,
  });
}
