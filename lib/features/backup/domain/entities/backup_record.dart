class BackupRecord {
  BackupRecord({
    required this.namespace,
    required this.id,
    required Map<String, Object?> payload,
  }) : payload = Map<String, Object?>.unmodifiable(payload);

  final String namespace;
  final String id;
  final Map<String, Object?> payload;
}
