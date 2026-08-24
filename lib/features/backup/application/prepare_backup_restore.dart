import 'dart:typed_data';

import '../../../core/result/result.dart';
import '../domain/entities/backup_record.dart';
import '../domain/entities/backup_snapshot.dart';
import 'backup_attachment_restore_port.dart';
import 'backup_bundle_archive_codec.dart';
import 'medication_backup_data_port.dart';

class PreparedBackupRestore {
  const PreparedBackupRestore({
    required this.snapshot,
    required this.stageId,
  });

  final BackupSnapshot snapshot;
  final String stageId;
}

class PrepareBackupRestore {
  const PrepareBackupRestore({
    required this.codec,
    required this.attachmentRestorePort,
  });

  final BackupBundleArchiveCodec codec;
  final BackupAttachmentRestorePort attachmentRestorePort;

  Future<Result<PreparedBackupRestore>> call(Uint8List archiveBytes) async {
    final decoded = await codec.decodeBundle(archiveBytes);
    if (decoded case Failed(:final failure)) {
      return Failed<PreparedBackupRestore>(failure);
    }

    final bundle = (decoded as Success).value;
    if (!bundle.snapshot.isCurrentSchema) {
      return const Failed<PreparedBackupRestore>(
        Failure(
          code: 'backup_unsupported_schema',
          message: 'Unsupported backup schema.',
        ),
      );
    }

    final staged = await attachmentRestorePort.stage(bundle.attachments);
    if (staged case Failed(:final failure)) {
      return Failed<PreparedBackupRestore>(failure);
    }
    final stage = (staged as Success<StagedBackupAttachments>).value;

    final rewritten = _rewritePhotoPaths(
      bundle.snapshot,
      stage.localPathsByArchivePath,
    );
    if (rewritten case Failed<BackupSnapshot>(:final failure)) {
      final discardResult = await attachmentRestorePort.discard(stage.stageId);
      if (discardResult case Failed(:final failure)) {
        return const Failed<PreparedBackupRestore>(
          Failure(
            code: 'backup_restore_stage_cleanup_failed',
            message: 'Staged backup attachments could not be cleaned up.',
          ),
        );
      }
      return Failed<PreparedBackupRestore>(failure);
    }

    return Success<PreparedBackupRestore>(
      PreparedBackupRestore(
        snapshot: (rewritten as Success<BackupSnapshot>).value,
        stageId: stage.stageId,
      ),
    );
  }

  Result<BackupSnapshot> _rewritePhotoPaths(
    BackupSnapshot snapshot,
    Map<String, String> localPaths,
  ) {
    final records = <BackupRecord>[];
    for (final record in snapshot.records) {
      if (record.namespace != MedicationBackupDataPort.medicationNamespace) {
        records.add(record);
        continue;
      }

      final imagePath = record.payload['imagePath'];
      if (imagePath is! String || imagePath.isEmpty) {
        records.add(record);
        continue;
      }

      final localPath = localPaths[imagePath];
      if (localPath == null || localPath.isEmpty) {
        return const Failed<BackupSnapshot>(
          Failure(
            code: 'backup_restore_attachment_mapping_missing',
            message: 'A staged attachment path is missing.',
          ),
        );
      }

      final payload = Map<String, Object?>.from(record.payload)
        ..['imagePath'] = localPath;
      records.add(
        BackupRecord(
          namespace: record.namespace,
          id: record.id,
          payload: payload,
        ),
      );
    }

    return Success<BackupSnapshot>(
      BackupSnapshot(
        schemaVersion: snapshot.schemaVersion,
        exportedAt: snapshot.exportedAt,
        records: records,
      ),
    );
  }
}
