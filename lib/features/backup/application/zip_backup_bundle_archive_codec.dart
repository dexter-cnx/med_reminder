import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../core/result/result.dart';
import '../domain/entities/backup_attachment.dart';
import '../domain/entities/backup_snapshot.dart';
import 'backup_bundle_archive_codec.dart';
import 'json_backup_archive_codec.dart';
import 'medication_backup_data_port.dart';

final class ZipBackupBundleArchiveCodec implements BackupBundleArchiveCodec {
  const ZipBackupBundleArchiveCodec({
    this.manifestCodec = const JsonBackupArchiveCodec(),
  });

  static final DateTime _deterministicModifiedAt = DateTime.utc(1980);
  static const String attachmentPrefix = 'attachments/';

  final JsonBackupArchiveCodec manifestCodec;

  @override
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle) async {
    final manifestResult = await manifestCodec.encode(bundle.snapshot);
    if (manifestResult case Failed<Uint8List>(:final failure)) {
      return Failed<Uint8List>(failure);
    }

    try {
      final archive = Archive()
        ..add(
          ArchiveFile.bytes(
            JsonBackupArchiveCodec.manifestFileName,
            (manifestResult as Success<Uint8List>).value,
          ),
        );
      final seenPaths = <String>{JsonBackupArchiveCodec.manifestFileName};
      for (final attachment in bundle.attachments) {
        if (!_isSafeAttachmentPath(attachment.archivePath) ||
            !seenPaths.add(attachment.archivePath)) {
          return const Failed<Uint8List>(
            Failure(
              code: 'backup_attachment_path_invalid',
              message: 'Backup attachment path is invalid or duplicated.',
            ),
          );
        }
        archive.add(
          ArchiveFile.bytes(attachment.archivePath, attachment.bytes),
        );
      }

      return Success<Uint8List>(
        ZipEncoder().encodeBytes(
          archive,
          modified: _deterministicModifiedAt,
        ),
      );
    } on Object {
      return const Failed<Uint8List>(
        Failure(
          code: 'backup_zip_encode_failed',
          message: 'Backup ZIP could not be encoded.',
        ),
      );
    }
  }

  @override
  Future<Result<BackupAttachmentBundle>> decodeBundle(
    Uint8List archiveBytes,
  ) async {
    if (!_hasZipSignature(archiveBytes)) {
      return const Failed<BackupAttachmentBundle>(
        Failure(
          code: 'backup_zip_invalid',
          message: 'Backup ZIP is invalid or corrupt.',
        ),
      );
    }

    try {
      final archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);
      final entriesByPath = <String, ArchiveFile>{};
      for (final entry in archive) {
        if (entriesByPath.containsKey(entry.name)) {
          return const Failed<BackupAttachmentBundle>(
            Failure(
              code: 'backup_zip_duplicate_path',
              message: 'Backup ZIP contains duplicate archive paths.',
            ),
          );
        }
        entriesByPath[entry.name] = entry;
      }

      final manifestEntry =
          entriesByPath[JsonBackupArchiveCodec.manifestFileName];
      if (manifestEntry == null || !manifestEntry.isFile) {
        return const Failed<BackupAttachmentBundle>(
          Failure(
            code: 'backup_zip_manifest_missing',
            message: 'Backup ZIP does not contain backup.json.',
          ),
        );
      }
      final manifestBytes = manifestEntry.readBytes();
      if (manifestBytes == null) {
        return const Failed<BackupAttachmentBundle>(
          Failure(
            code: 'backup_zip_manifest_invalid',
            message: 'Backup ZIP manifest could not be read.',
          ),
        );
      }

      final snapshotResult = await manifestCodec.decode(manifestBytes);
      if (snapshotResult case Failed<BackupSnapshot>(:final failure)) {
        return Failed<BackupAttachmentBundle>(failure);
      }
      final snapshot = (snapshotResult as Success<BackupSnapshot>).value;

      final referencedAttachmentPaths = <String>{};
      for (final record in snapshot.records) {
        final imagePath = record.payload['imagePath'];
        if (record.namespace != MedicationBackupDataPort.medicationNamespace ||
            imagePath == null) {
          continue;
        }
        if (imagePath is! String || !_isSafeAttachmentPath(imagePath)) {
          return const Failed<BackupAttachmentBundle>(
            Failure(
              code: 'backup_attachment_path_invalid',
              message: 'Backup manifest references an unsafe attachment path.',
            ),
          );
        }
        referencedAttachmentPaths.add(imagePath);
      }

      final attachments = <BackupAttachment>[];
      for (final path in referencedAttachmentPaths) {
        final entry = entriesByPath[path];
        final bytes = entry?.readBytes();
        if (entry == null || !entry.isFile || bytes == null) {
          return const Failed<BackupAttachmentBundle>(
            Failure(
              code: 'backup_attachment_missing',
              message: 'Backup ZIP is missing a referenced attachment.',
            ),
          );
        }
        attachments.add(BackupAttachment(archivePath: path, bytes: bytes));
      }

      for (final entry in archive) {
        if (entry.name == JsonBackupArchiveCodec.manifestFileName) continue;
        if (!_isSafeAttachmentPath(entry.name) ||
            !referencedAttachmentPaths.contains(entry.name)) {
          return const Failed<BackupAttachmentBundle>(
            Failure(
              code: 'backup_attachment_unexpected',
              message: 'Backup ZIP contains an unexpected attachment entry.',
            ),
          );
        }
      }

      return Success<BackupAttachmentBundle>(
        BackupAttachmentBundle(snapshot: snapshot, attachments: attachments),
      );
    } on Object {
      return const Failed<BackupAttachmentBundle>(
        Failure(
          code: 'backup_zip_invalid',
          message: 'Backup ZIP is invalid or corrupt.',
        ),
      );
    }
  }

  static bool _isSafeAttachmentPath(String path) {
    if (!path.startsWith(attachmentPrefix) ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.contains('../') ||
        path.contains('/..') ||
        path.endsWith('/')) {
      return false;
    }
    return Uri.tryParse(path)?.hasScheme == false;
  }

  static bool _hasZipSignature(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
      return false;
    }
    final marker2 = bytes[2];
    final marker3 = bytes[3];
    return (marker2 == 0x03 && marker3 == 0x04) ||
        (marker2 == 0x05 && marker3 == 0x06) ||
        (marker2 == 0x07 && marker3 == 0x08);
  }
}
