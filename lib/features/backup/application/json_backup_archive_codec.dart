import 'dart:convert';
import 'dart:typed_data';

import '../../../core/result/result.dart';
import '../domain/entities/backup_record.dart';
import '../domain/entities/backup_snapshot.dart';
import 'backup_archive_codec.dart';

final class JsonBackupArchiveCodec implements BackupArchiveCodec {
  const JsonBackupArchiveCodec();

  static const int manifestVersion = 1;
  static const String manifestFileName = 'backup.json';

  @override
  Future<Result<Uint8List>> encode(BackupSnapshot snapshot) async {
    try {
      final manifest = <String, Object?>{
        'manifestVersion': manifestVersion,
        'schemaVersion': snapshot.schemaVersion,
        'exportedAt': snapshot.exportedAt.toUtc().toIso8601String(),
        'records': <Object?>[
          for (final record in snapshot.records)
            <String, Object?>{
              'namespace': record.namespace,
              'id': record.id,
              'payload': record.payload,
            },
        ],
      };
      return Success<Uint8List>(
        Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
      );
    } on Object {
      return const Failed<Uint8List>(
        Failure(
          code: 'backup_manifest_encode_failed',
          message: 'Backup manifest could not be encoded.',
        ),
      );
    }
  }

  @override
  Future<Result<BackupSnapshot>> decode(Uint8List archiveBytes) async {
    try {
      final decoded = jsonDecode(utf8.decode(archiveBytes));
      if (decoded is! Map<String, Object?>) {
        return _invalidManifest();
      }

      final version = decoded['manifestVersion'];
      if (version != manifestVersion) {
        return const Failed<BackupSnapshot>(
          Failure(
            code: 'backup_manifest_version_unsupported',
            message: 'Unsupported backup manifest version.',
          ),
        );
      }

      final schemaVersion = decoded['schemaVersion'];
      final exportedAt = decoded['exportedAt'];
      final rawRecords = decoded['records'];
      if (schemaVersion is! int ||
          exportedAt is! String ||
          rawRecords is! List<Object?>) {
        return _invalidManifest();
      }

      final records = <BackupRecord>[];
      for (final rawRecord in rawRecords) {
        if (rawRecord is! Map<String, Object?>) {
          return _invalidManifest();
        }
        final namespace = rawRecord['namespace'];
        final id = rawRecord['id'];
        final payload = rawRecord['payload'];
        if (namespace is! String ||
            id is! String ||
            payload is! Map<String, Object?>) {
          return _invalidManifest();
        }
        records.add(
          BackupRecord(namespace: namespace, id: id, payload: payload),
        );
      }

      return Success<BackupSnapshot>(
        BackupSnapshot(
          schemaVersion: schemaVersion,
          exportedAt: DateTime.parse(exportedAt).toUtc(),
          records: records,
        ),
      );
    } on Object {
      return _invalidManifest();
    }
  }

  static Failed<BackupSnapshot> _invalidManifest() {
    return const Failed<BackupSnapshot>(
      Failure(
        code: 'backup_manifest_invalid',
        message: 'Backup manifest is invalid or corrupt.',
      ),
    );
  }
}
