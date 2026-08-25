import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/result/result.dart';
import '../../../services/photo_service.dart';
import '../application/backup_attachment_restore_port.dart';
import '../domain/entities/backup_attachment.dart';

final class FileBackupAttachmentRestorePort
    implements BackupAttachmentRestorePort {
  FileBackupAttachmentRestorePort({
    required this.documentsPath,
    required this.stagingRootPath,
    Uuid? uuid,
    DateTime Function()? now,
  })  : _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now;

  static const String _metadataFileName = 'stage.json';

  final String documentsPath;
  final String stagingRootPath;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Future<Result<StagedBackupAttachments>> stage(
    List<BackupAttachment> attachments,
  ) async {
    final stageId = _uuid.v4();
    final stageDirectory = Directory(p.join(stagingRootPath, stageId));
    final finalDirectory = Directory(_photoDirectoryPath);

    try {
      await stageDirectory.create(recursive: true);
      await finalDirectory.create(recursive: true);

      final paths = <String, StagedBackupAttachmentPath>{};
      final metadataEntries = <Map<String, Object?>>[];

      for (final attachment in attachments) {
        final extension = _safeExtension(attachment.archivePath);
        final fileId = _uuid.v4();
        final stagedPath = p.join(stageDirectory.path, '$fileId$extension');
        final finalPath = p.join(finalDirectory.path, '$fileId$extension');

        if (await File(finalPath).exists()) {
          await _deleteDirectoryIfExists(stageDirectory);
          return const Failed<StagedBackupAttachments>(
            Failure(
              code: 'backup_restore_destination_conflict',
              message: 'A reserved medication photo destination already exists.',
            ),
          );
        }

        await File(stagedPath).writeAsBytes(attachment.bytes, flush: true);
        final staged = StagedBackupAttachmentPath(
          stagedPath: stagedPath,
          finalPath: finalPath,
        );
        paths[attachment.archivePath] = staged;
        metadataEntries.add(<String, Object?>{
          'archivePath': attachment.archivePath,
          'stagedPath': stagedPath,
          'finalPath': finalPath,
        });
      }

      await File(p.join(stageDirectory.path, _metadataFileName)).writeAsString(
        jsonEncode(<String, Object?>{
          'stageId': stageId,
          'createdAt': _now().toUtc().toIso8601String(),
          'entries': metadataEntries,
        }),
        flush: true,
      );

      return Success<StagedBackupAttachments>(
        StagedBackupAttachments(
          stageId: stageId,
          pathsByArchivePath: paths,
        ),
      );
    } on Object {
      await _deleteDirectoryIfExists(stageDirectory);
      return const Failed<StagedBackupAttachments>(
        Failure(
          code: 'backup_restore_attachment_stage_failed',
          message: 'Backup attachments could not be staged.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> commit(String stageId) async {
    final metadataResult = await _readMetadata(stageId);
    if (metadataResult case Failed<_StageMetadata>(:final failure)) {
      return Failed<void>(failure);
    }
    final metadata = (metadataResult as Success<_StageMetadata>).value;

    final moved = <_StageEntry>[];
    try {
      for (final entry in metadata.entries) {
        final stagedFile = File(entry.stagedPath);
        final finalFile = File(entry.finalPath);
        if (!await stagedFile.exists() || await finalFile.exists()) {
          throw FileSystemException('Stage cannot be committed.');
        }
      }

      for (final entry in metadata.entries) {
        await File(entry.stagedPath).rename(entry.finalPath);
        moved.add(entry);
      }
      return const Success<void>(null);
    } on Object {
      for (final entry in moved.reversed) {
        try {
          final finalFile = File(entry.finalPath);
          if (await finalFile.exists()) {
            await finalFile.rename(entry.stagedPath);
          }
        } on Object {
          return const Failed<void>(
            Failure(
              code: 'backup_restore_attachment_commit_rollback_failed',
              message:
                  'Backup photo commit failed and partial files could not be rolled back.',
            ),
          );
        }
      }
      return const Failed<void>(
        Failure(
          code: 'backup_restore_attachment_commit_failed',
          message: 'Backup photos could not be committed.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> rollback(String stageId) async {
    final metadataResult = await _readMetadata(stageId);
    if (metadataResult case Failed<_StageMetadata>(:final failure)) {
      return Failed<void>(failure);
    }
    final metadata = (metadataResult as Success<_StageMetadata>).value;

    try {
      for (final entry in metadata.entries) {
        final file = File(entry.finalPath);
        if (await file.exists()) await file.delete();
      }
      await _deleteDirectoryIfExists(_stageDirectory(stageId));
      return const Success<void>(null);
    } on Object {
      return const Failed<void>(
        Failure(
          code: 'backup_restore_attachment_rollback_failed',
          message: 'Committed backup photos could not be rolled back.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> discard(String stageId) async {
    try {
      await _deleteDirectoryIfExists(_stageDirectory(stageId));
      return const Success<void>(null);
    } on Object {
      return const Failed<void>(
        Failure(
          code: 'backup_restore_attachment_discard_failed',
          message: 'Staged backup photos could not be discarded.',
        ),
      );
    }
  }

  Future<Result<int>> cleanupStaleStages({required Duration olderThan}) async {
    final root = Directory(stagingRootPath);
    if (!await root.exists()) return const Success<int>(0);

    var deleted = 0;
    final cutoff = _now().toUtc().subtract(olderThan);
    try {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final metadataFile = File(p.join(entity.path, _metadataFileName));
        DateTime? createdAt;
        if (await metadataFile.exists()) {
          try {
            final decoded = jsonDecode(await metadataFile.readAsString());
            if (decoded is Map<String, Object?>) {
              createdAt = DateTime.tryParse(decoded['createdAt'] as String? ?? '');
            }
          } on Object {
            createdAt = null;
          }
        }
        createdAt ??= (await entity.stat()).modified.toUtc();
        if (createdAt.isAfter(cutoff)) continue;
        await entity.delete(recursive: true);
        deleted++;
      }
      return Success<int>(deleted);
    } on Object {
      return const Failed<int>(
        Failure(
          code: 'backup_restore_stale_stage_cleanup_failed',
          message: 'Stale backup photo stages could not be cleaned up.',
        ),
      );
    }
  }

  String get _photoDirectoryPath =>
      p.join(documentsPath, PhotoService.photoDirectoryName);

  Directory _stageDirectory(String stageId) =>
      Directory(p.join(stagingRootPath, stageId));

  Future<Result<_StageMetadata>> _readMetadata(String stageId) async {
    try {
      if (!_isSafeStageId(stageId)) {
        throw const FormatException('Invalid stage id.');
      }
      final stageDirectory = _stageDirectory(stageId);
      final metadataFile = File(p.join(stageDirectory.path, _metadataFileName));
      if (!await metadataFile.exists()) {
        return const Failed<_StageMetadata>(
          Failure(
            code: 'backup_restore_stage_missing',
            message: 'Backup photo stage metadata is missing.',
          ),
        );
      }
      final decoded = jsonDecode(await metadataFile.readAsString());
      if (decoded is! Map<String, Object?> || decoded['stageId'] != stageId) {
        throw const FormatException('Invalid stage metadata.');
      }
      final rawEntries = decoded['entries'];
      if (rawEntries is! List) throw const FormatException('Invalid entries.');
      final entries = <_StageEntry>[];
      for (final rawEntry in rawEntries) {
        if (rawEntry is! Map) throw const FormatException('Invalid entry.');
        final stagedPath = rawEntry['stagedPath'];
        final finalPath = rawEntry['finalPath'];
        if (stagedPath is! String || finalPath is! String) {
          throw const FormatException('Invalid paths.');
        }
        if (!_isPathWithin(stageDirectory.path, stagedPath) ||
            !_isPathWithin(_photoDirectoryPath, finalPath)) {
          throw const FormatException('Stage metadata path escapes restore roots.');
        }
        entries.add(_StageEntry(stagedPath: stagedPath, finalPath: finalPath));
      }
      return Success<_StageMetadata>(_StageMetadata(entries));
    } on Object {
      return const Failed<_StageMetadata>(
        Failure(
          code: 'backup_restore_stage_invalid',
          message: 'Backup photo stage metadata is invalid.',
        ),
      );
    }
  }

  static bool _isSafeStageId(String stageId) =>
      stageId.isNotEmpty &&
      !stageId.contains('/') &&
      !stageId.contains('\\') &&
      stageId != '.' &&
      stageId != '..';

  static bool _isPathWithin(String root, String candidate) {
    final normalizedRoot = p.normalize(p.absolute(root));
    final normalizedCandidate = p.normalize(p.absolute(candidate));
    return normalizedCandidate != normalizedRoot &&
        p.isWithin(normalizedRoot, normalizedCandidate);
  }

  static String _safeExtension(String archivePath) {
    final extension = p.extension(archivePath).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : '.jpg';
  }

  static Future<void> _deleteDirectoryIfExists(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

final class _StageMetadata {
  const _StageMetadata(this.entries);

  final List<_StageEntry> entries;
}

final class _StageEntry {
  const _StageEntry({required this.stagedPath, required this.finalPath});

  final String stagedPath;
  final String finalPath;
}
