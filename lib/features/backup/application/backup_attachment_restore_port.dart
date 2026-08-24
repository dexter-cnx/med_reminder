import '../../../core/result/result.dart';
import '../domain/entities/backup_attachment.dart';

class StagedBackupAttachments {
  StagedBackupAttachments({
    required this.stageId,
    required Map<String, String> localPathsByArchivePath,
  }) : localPathsByArchivePath =
            Map<String, String>.unmodifiable(localPathsByArchivePath);

  final String stageId;
  final Map<String, String> localPathsByArchivePath;
}

abstract interface class BackupAttachmentRestorePort {
  Future<Result<StagedBackupAttachments>> stage(
    List<BackupAttachment> attachments,
  );

  Future<Result<void>> discard(String stageId);
}
