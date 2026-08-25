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

  static const _retention = Duration(hours: 24);

  @override
  Future<Result<void>> shareArchive(
    Uint8List archiveBytes, {
    required String fileName,
    BackupShareAnchor? anchor,
  }) async {
    try {
      final temporaryDirectory = await getTemporaryDirectory();
      final shareDirectory = Directory(
        p.join(temporaryDirectory.path, 'besyu_backup_share'),
      );
      await shareDirectory.create(recursive: true);
      await _cleanupStaleArchives(shareDirectory);

      final sharedFile = File(p.join(shareDirectory.path, fileName));
      await sharedFile.writeAsBytes(archiveBytes, flush: true);

      final shareResult = await Share.shareXFiles(
        <XFile>[XFile(sharedFile.path, mimeType: 'application/zip')],
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
      if (shareResult.status == ShareResultStatus.dismissed) {
        return const Failed<void>(
          Failure(
            code: 'backup_export_cancelled',
            message:
                'Backup export was cancelled before choosing a destination.',
          ),
        );
      }
      if (shareResult.status == ShareResultStatus.unavailable) {
        return const Failed<void>(
          Failure(
            code: 'backup_export_share_unavailable',
            message: 'The system share sheet is not available.',
          ),
        );
      }
      return const Success<void>(null);
    } on Object {
      return const Failed<void>(
        Failure(
          code: 'backup_export_share_failed',
          message: 'The backup could not be handed to the system share sheet.',
        ),
      );
    }
  }

  Future<void> _cleanupStaleArchives(Directory shareDirectory) async {
    final cutoff = DateTime.now().subtract(_retention);
    try {
      await for (final entity in shareDirectory.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) await entity.delete();
        } on Object {
          // Best-effort retention cleanup must never block a new export.
        }
      }
    } on Object {
      // Best-effort retention cleanup must never block a new export.
    }
  }
}
