import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../application/backup_export_port.dart';
import '../../application/create_backup_bundle.dart';
import '../../infrastructure/share_plus_backup_export_port.dart';
import 'backup_restore_providers.dart';

final backupExportPortProvider = Provider<BackupExportPort>(
  (ref) => const SharePlusBackupExportPort(),
);

final backupExportControllerProvider =
    StateNotifierProvider<BackupExportController, bool>(
  (ref) => BackupExportController(
    createBundle: ref.watch(createBackupBundleProvider),
    exportPort: ref.watch(backupExportPortProvider),
  ),
);

final class BackupExportController extends StateNotifier<bool> {
  BackupExportController({
    required this.createBundle,
    required this.exportPort,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(false);

  final CreateBackupBundle createBundle;
  final BackupExportPort exportPort;
  final DateTime Function() _now;

  Future<Result<void>> shareBackup({BackupShareAnchor? anchor}) async {
    if (state) {
      return const Failed<void>(
        Failure(
          code: 'backup_export_in_progress',
          message: 'Backup export is already in progress.',
        ),
      );
    }

    state = true;
    try {
      final bundle = await createBundle();
      if (bundle case Failed<Uint8List>(:final failure)) {
        return Failed<void>(failure);
      }
      return exportPort.shareArchive(
        (bundle as Success<Uint8List>).value,
        fileName: _fileName(_now()),
        anchor: anchor,
      );
    } finally {
      state = false;
    }
  }

  static String _fileName(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return 'besyu-backup-${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}.zip';
  }
}
