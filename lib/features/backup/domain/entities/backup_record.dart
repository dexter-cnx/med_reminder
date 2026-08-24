class BackupRecord {
  BackupRecord({
    required this.namespace,
    required this.id,
    required Map<String, Object?> payload,
  }) : payload = _freezeMap(payload);

  final String namespace;
  final String id;
  final Map<String, Object?> payload;
}

Map<String, Object?> _freezeMap(Map<String, Object?> source) {
  return Map<String, Object?>.unmodifiable(
    source.map(
      (key, value) => MapEntry<String, Object?>(key, _freezeValue(value)),
    ),
  );
}

Object? _freezeValue(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map<Object?>(_freezeValue));
  }
  if (value is Map<String, Object?>) {
    return _freezeMap(value);
  }
  throw ArgumentError.value(
    value,
    'value',
    'Backup payload values must be JSON-compatible primitives, lists, or string-keyed maps.',
  );
}
