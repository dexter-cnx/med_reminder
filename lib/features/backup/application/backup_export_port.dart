import 'dart:typed_data';

import '../../../core/result/result.dart';

final class BackupShareAnchor {
  const BackupShareAnchor({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

abstract interface class BackupExportPort {
  Future<Result<void>> shareArchive(
    Uint8List archiveBytes, {
    required String fileName,
    BackupShareAnchor? anchor,
  });
}
