import 'package:hive/hive.dart';

abstract interface class RefillLocalDataSource {
  List<Map<dynamic, dynamic>> readRefillRecords();
  Future<void> putRefillRecord(String id, Map<String, dynamic> record);
}

class HiveRefillLocalDataSource implements RefillLocalDataSource {
  HiveRefillLocalDataSource(this._box);

  final Box<dynamic> _box;

  @override
  List<Map<dynamic, dynamic>> readRefillRecords() => _box.values
      .map((value) => Map<dynamic, dynamic>.from(value as Map))
      .toList(growable: false);

  @override
  Future<void> putRefillRecord(String id, Map<String, dynamic> record) =>
      _box.put(id, record);
}
