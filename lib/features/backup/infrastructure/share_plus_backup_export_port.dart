import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/result/result.dart';
import '../application/backup_export_port.dart';

final class SharePlusBackupExportPort implements BackupExportPort {
  const SharePlusBackupExportPort();

  @override
  Future<Result<void>> shareArchive(
    Uint8List archiveBytes, {
    required String fileName,
    BackupShareAnchor? anchor,
  }) async {
    File? temporaryFile;
    try {
      final temporaryDirectory = await getTemporaryDirectory();
      final shareDirectory = Directory(
        p.join(temporaryDirectory.path, 'besyu_backup_share'),
      );
      await shareDirectory.create(recursive: true);
      temporaryFile = File(p.join(shareDirectory.path, fileName));
      await temporaryFile.writeAsBytes(archiveBytes, flush: true);

      await Share.shareXFiles(
        <XFile>[XFile(temporaryFile.path, mimeType: 'application/zip')],
        subject: 'Besyu backup',
        sharePositionOrigin: anchor == null
            ? null
            : Rect.fromLTWH(
                anchor.left,
                anchor.top,
                anchor.width,
                anchor.height,
              ),
      );
      return const Success<void>(null);
    } on Object {
      return const Failed<void>(
        Failure(
          code: 'backup_export_share_failed',
          message: 'The backup could not be handed to the system share sheet.',
        ),
      );
    } finally {
      if (temporaryFile != null) {
        try {
          if (await temporaryFile.exists()) await temporaryFile.delete();
        } on Object {
          // Best-effort cleanup. Never turn a completed share into a failure.
        }
      }
    }
  }
}
