import '../../../core/result/result.dart';
import '../domain/entities/backup_attachment.dart';

class StagedBackupAttachmentPath {
  const StagedBackupAttachmentPath({
    required this.stagedPath,
    required this.finalPath,
  });

  final String stagedPath;
  final String finalPath;
}

class StagedBackupAttachments {
  StagedBackupAttachments({
    required this.stageId,
    required Map<String, StagedBackupAttachmentPath> pathsByArchivePath,
  }) : pathsByArchivePath =
           Map<String, StagedBackupAttachmentPath>.unmodifiable(
             pathsByArchivePath,
           );

  final String stageId;
  final Map<String, StagedBackupAttachmentPath> pathsByArchivePath;
}

abstract interface class BackupAttachmentRestorePort {
  Future<Result<StagedBackupAttachments>> stage(
    List<BackupAttachment> attachments,
  );

  /// Promotes every staged attachment to its reserved final path.
  ///
  /// A failure must not leave a partially committed stage behind.
  Future<Result<void>> commit(String stageId);

  /// Removes attachments that were already committed from this stage.
  ///
  /// Used when application-data replacement fails after file commit.
  Future<Result<void>> rollback(String stageId);

  /// Removes an uncommitted stage.
  Future<Result<void>> discard(String stageId);
}
