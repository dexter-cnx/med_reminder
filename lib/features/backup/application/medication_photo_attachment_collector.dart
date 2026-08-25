import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/result/result.dart';
import '../domain/entities/backup_attachment.dart';
import '../domain/entities/backup_record.dart';
import '../domain/entities/backup_snapshot.dart';
import 'backup_attachment_source.dart';
import 'medication_backup_data_port.dart';

final class MedicationPhotoAttachmentCollector {
  const MedicationPhotoAttachmentCollector({required this.source});

  final BackupAttachmentSource source;

  Future<Result<BackupAttachmentBundle>> collect(
    BackupSnapshot snapshot,
  ) async {
    final records = <BackupRecord>[];
    final attachments = <BackupAttachment>[];

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

      final bytesResult = await source.read(imagePath);
      if (bytesResult case Failed<Uint8List>(:final failure)) {
        return Failed<BackupAttachmentBundle>(failure);
      }

      final archivePath = _archivePath(record.id, imagePath);
      final payload = Map<String, Object?>.from(record.payload)
        ..['imagePath'] = archivePath;
      records.add(
        BackupRecord(
          namespace: record.namespace,
          id: record.id,
          payload: payload,
        ),
      );
      attachments.add(
        BackupAttachment(
          archivePath: archivePath,
          bytes: (bytesResult as Success<Uint8List>).value,
        ),
      );
    }

    return Success<BackupAttachmentBundle>(
      BackupAttachmentBundle(
        snapshot: BackupSnapshot(
          schemaVersion: snapshot.schemaVersion,
          exportedAt: snapshot.exportedAt,
          records: records,
        ),
        attachments: attachments,
      ),
    );
  }

  static String _archivePath(String recordId, String sourcePath) {
    final rawExtension = p.extension(sourcePath).toLowerCase();
    final extension = RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(rawExtension)
        ? rawExtension
        : '.jpg';
    final safeId = Uri.encodeComponent(recordId);
    return 'attachments/medication/$safeId$extension';
  }
}
