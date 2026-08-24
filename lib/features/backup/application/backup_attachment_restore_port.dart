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

  Future<Result<void>> discard(String stageId);
}
