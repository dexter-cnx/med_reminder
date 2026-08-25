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
  static const int maxArchiveEntryCount = 2048;
  static const int maxUncompressedEntryBytes = 64 * 1024 * 1024;
  static const int maxTotalUncompressedBytes = 128 * 1024 * 1024;
  static const double maxCompressionRatio = 100;

  static const int _endOfCentralDirectorySignature = 0x06054b50;
  static const int _centralDirectoryFileHeaderSignature = 0x02014b50;
  static const int _zip64Sentinel16 = 0xffff;
  static const int _zip64Sentinel32 = 0xffffffff;
  static const int _maxZipCommentLength = 0xffff;

  final JsonBackupArchiveCodec manifestCodec;

  @override
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle) async {
    final referencedPathsResult = _referencedAttachmentPaths(bundle.snapshot);
    if (referencedPathsResult case Failed<Set<String>>(:final failure)) {
      return Failed<Uint8List>(failure);
    }
    final referencedPaths =
        (referencedPathsResult as Success<Set<String>>).value;

    final attachmentPaths = <String>{};
    for (final attachment in bundle.attachments) {
      if (!_isSafeAttachmentPath(attachment.archivePath) ||
          !attachmentPaths.add(attachment.archivePath)) {
        return const Failed<Uint8List>(
          Failure(
            code: 'backup_attachment_path_invalid',
            message: 'Backup attachment path is invalid or duplicated.',
          ),
        );
      }
    }

    final missingPaths = referencedPaths.difference(attachmentPaths);
    if (missingPaths.isNotEmpty) {
      return const Failed<Uint8List>(
        Failure(
          code: 'backup_attachment_missing',
          message: 'Backup bundle is missing a referenced attachment.',
        ),
      );
    }
    final unexpectedPaths = attachmentPaths.difference(referencedPaths);
    if (unexpectedPaths.isNotEmpty) {
      return const Failed<Uint8List>(
        Failure(
          code: 'backup_attachment_unexpected',
          message: 'Backup bundle contains an unreferenced attachment.',
        ),
      );
    }

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
      for (final attachment in bundle.attachments) {
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

    final metadataPreflight = _preflightZipMetadata(archiveBytes);
    if (metadataPreflight case Failed<void>(:final failure)) {
      return Failed<BackupAttachmentBundle>(failure);
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
      final referencedPathsResult = _referencedAttachmentPaths(snapshot);
      if (referencedPathsResult case Failed<Set<String>>(:final failure)) {
        return Failed<BackupAttachmentBundle>(failure);
      }
      final referencedAttachmentPaths =
          (referencedPathsResult as Success<Set<String>>).value;

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

  static Result<void> _preflightZipMetadata(Uint8List bytes) {
    try {
      if (bytes.length < 22) return _invalidZip();
      final data = ByteData.sublistView(bytes);
      final searchStart = bytes.length - 22;
      final searchEnd =
          (bytes.length - 22 - _maxZipCommentLength).clamp(0, bytes.length);

      var eocdOffset = -1;
      for (var offset = searchStart; offset >= searchEnd; offset--) {
        if (data.getUint32(offset, Endian.little) ==
            _endOfCentralDirectorySignature) {
          eocdOffset = offset;
          break;
        }
      }
      if (eocdOffset < 0 || eocdOffset + 22 > bytes.length) {
        return _invalidZip();
      }

      final diskNumber = data.getUint16(eocdOffset + 4, Endian.little);
      final centralDirectoryDisk =
          data.getUint16(eocdOffset + 6, Endian.little);
      final entriesOnDisk = data.getUint16(eocdOffset + 8, Endian.little);
      final totalEntries = data.getUint16(eocdOffset + 10, Endian.little);
      final centralDirectorySize =
          data.getUint32(eocdOffset + 12, Endian.little);
      final centralDirectoryOffset =
          data.getUint32(eocdOffset + 16, Endian.little);
      final commentLength = data.getUint16(eocdOffset + 20, Endian.little);

      if (eocdOffset + 22 + commentLength != bytes.length ||
          diskNumber != 0 ||
          centralDirectoryDisk != 0 ||
          entriesOnDisk != totalEntries ||
          totalEntries == _zip64Sentinel16 ||
          centralDirectorySize == _zip64Sentinel32 ||
          centralDirectoryOffset == _zip64Sentinel32 ||
          totalEntries > maxArchiveEntryCount ||
          centralDirectoryOffset + centralDirectorySize > eocdOffset) {
        return _unsafeZip();
      }

      var offset = centralDirectoryOffset;
      var totalUncompressed = 0;
      for (var index = 0; index < totalEntries; index++) {
        if (offset + 46 > bytes.length ||
            data.getUint32(offset, Endian.little) !=
                _centralDirectoryFileHeaderSignature) {
          return _invalidZip();
        }

        final generalPurposeFlags = data.getUint16(offset + 8, Endian.little);
        final compressedSize = data.getUint32(offset + 20, Endian.little);
        final uncompressedSize = data.getUint32(offset + 24, Endian.little);
        final fileNameLength = data.getUint16(offset + 28, Endian.little);
        final extraFieldLength = data.getUint16(offset + 30, Endian.little);
        final fileCommentLength = data.getUint16(offset + 32, Endian.little);
        final diskStart = data.getUint16(offset + 34, Endian.little);

        if ((generalPurposeFlags & 0x1) != 0 ||
            diskStart != 0 ||
            compressedSize == _zip64Sentinel32 ||
            uncompressedSize == _zip64Sentinel32 ||
            uncompressedSize > maxUncompressedEntryBytes) {
          return _unsafeZip();
        }

        totalUncompressed += uncompressedSize;
        if (totalUncompressed > maxTotalUncompressedBytes) {
          return _unsafeZip();
        }

        if (uncompressedSize > 0) {
          if (compressedSize == 0 ||
              uncompressedSize / compressedSize > maxCompressionRatio) {
            return _unsafeZip();
          }
        }

        final nextOffset =
            offset + 46 + fileNameLength + extraFieldLength + fileCommentLength;
        if (nextOffset <= offset || nextOffset > bytes.length) {
          return _invalidZip();
        }
        offset = nextOffset;
      }

      if (offset != centralDirectoryOffset + centralDirectorySize) {
        return _invalidZip();
      }
      return const Success<void>(null);
    } on RangeError {
      return _invalidZip();
    }
  }

  static Failed<void> _invalidZip() => const Failed<void>(
        Failure(
          code: 'backup_zip_invalid',
          message: 'Backup ZIP is invalid or corrupt.',
        ),
      );

  static Failed<void> _unsafeZip() => const Failed<void>(
        Failure(
          code: 'backup_zip_expansion_limit_exceeded',
          message: 'Backup ZIP exceeds safe expansion limits.',
        ),
      );

  static Result<Set<String>> _referencedAttachmentPaths(
    BackupSnapshot snapshot,
  ) {
    final paths = <String>{};
    for (final record in snapshot.records) {
      final imagePath = record.payload['imagePath'];
      if (record.namespace != MedicationBackupDataPort.medicationNamespace ||
          imagePath == null ||
          imagePath == '') {
        continue;
      }
      if (imagePath is! String || !_isSafeAttachmentPath(imagePath)) {
        return const Failed<Set<String>>(
          Failure(
            code: 'backup_attachment_path_invalid',
            message: 'Backup manifest references an unsafe attachment path.',
          ),
        );
      }
      paths.add(imagePath);
    }
    return Success<Set<String>>(paths);
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
