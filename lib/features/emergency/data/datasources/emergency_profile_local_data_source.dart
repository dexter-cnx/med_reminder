import 'package:hive/hive.dart';

abstract interface class EmergencyProfileLocalDataSource {
  Map<dynamic, dynamic>? readProfileRecord();
  Future<void> writeProfileRecord(Map<String, dynamic> record);
  Future<void> clearProfileRecord();
}

class HiveEmergencyProfileLocalDataSource
    implements EmergencyProfileLocalDataSource {
  HiveEmergencyProfileLocalDataSource(this._box);

  static const _profileKey = 'profile';

  final Box<dynamic> _box;

  @override
  Map<dynamic, dynamic>? readProfileRecord() {
    final value = _box.get(_profileKey);
    if (value == null) return null;
    return Map<dynamic, dynamic>.from(value as Map);
  }

  @override
  Future<void> writeProfileRecord(Map<String, dynamic> record) =>
      _box.put(_profileKey, record);

  @override
  Future<void> clearProfileRecord() => _box.delete(_profileKey);
}
