import 'dart:typed_data';

import '../../../core/result/result.dart';

abstract interface class BackupAttachmentSource {
  Future<Result<Uint8List>> read(String sourcePath);
}
