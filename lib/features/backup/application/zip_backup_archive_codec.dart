import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../../core/result/result.dart';
import '../domain/entities/backup_snapshot.dart';
import 'backup_archive_codec.dart';
import 'json_backup_archive_codec.dart';

final class ZipBackupArchiveCodec implements BackupArchiveCodec {
  const ZipBackupArchiveCodec({
    this.manifestCodec = const JsonBackupArchiveCodec(),
  });

  static final DateTime _deterministicModifiedAt = DateTime.utc(1980);

  final JsonBackupArchiveCodec manifestCodec;

  @override
  Future<Result<Uint8List>> encode(BackupSnapshot snapshot) async {
    final manifestResult = await manifestCodec.encode(snapshot);
    if (manifestResult case Failed<Uint8List>(:final failure)) {
      return Failed<Uint8List>(failure);
    }

    try {
      final manifestBytes = (manifestResult as Success<Uint8List>).value;
      final archive = Archive()
        ..add(
          ArchiveFile.bytes(
            JsonBackupArchiveCodec.manifestFileName,
            manifestBytes,
          ),
        );
      final bytes = ZipEncoder().encodeBytes(
        archive,
        modified: _deterministicModifiedAt,
      );
      return Success<Uint8List>(bytes);
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
  Future<Result<BackupSnapshot>> decode(Uint8List archiveBytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);
      final seenPaths = <String>{};
      for (final entry in archive) {
        if (!seenPaths.add(entry.name)) {
          return const Failed<BackupSnapshot>(
            Failure(
              code: 'backup_zip_duplicate_path',
              message: 'Backup ZIP contains duplicate archive paths.',
            ),
          );
        }
      }

      final manifestEntries = archive
          .where((entry) => entry.name == JsonBackupArchiveCodec.manifestFileName)
          .toList(growable: false);
      if (manifestEntries.length != 1 || !manifestEntries.single.isFile) {
        return const Failed<BackupSnapshot>(
          Failure(
            code: 'backup_zip_manifest_missing',
            message: 'Backup ZIP does not contain exactly one backup.json manifest.',
          ),
        );
      }

      final manifestBytes = manifestEntries.single.readBytes();
      if (manifestBytes == null) {
        return const Failed<BackupSnapshot>(
          Failure(
            code: 'backup_zip_manifest_invalid',
            message: 'Backup ZIP manifest could not be read.',
          ),
        );
      }

      return manifestCodec.decode(manifestBytes);
    } on Object {
      return const Failed<BackupSnapshot>(
        Failure(
          code: 'backup_zip_invalid',
          message: 'Backup ZIP is invalid or corrupt.',
        ),
      );
    }
  }
}
