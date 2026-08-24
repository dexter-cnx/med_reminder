import 'backup_record.dart';

class BackupSnapshot {
  BackupSnapshot({
    required this.schemaVersion,
    required this.exportedAt,
    required List<BackupRecord> records,
  }) : records = List<BackupRecord>.unmodifiable(records);

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime exportedAt;
  final List<BackupRecord> records;

  bool get isCurrentSchema => schemaVersion == currentSchemaVersion;
}
