import 'dart:typed_data';

import 'backup_snapshot.dart';

class BackupAttachment {
  BackupAttachment({
    required this.archivePath,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final String archivePath;
  final Uint8List bytes;
}

class BackupAttachmentBundle {
  BackupAttachmentBundle({
    required this.snapshot,
    required List<BackupAttachment> attachments,
  }) : attachments = List<BackupAttachment>.unmodifiable(attachments);

  final BackupSnapshot snapshot;
  final List<BackupAttachment> attachments;
}
