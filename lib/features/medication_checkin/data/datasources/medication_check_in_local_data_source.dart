import 'package:hive/hive.dart';

abstract interface class MedicationCheckInLocalDataSource {
  List<Map<dynamic, dynamic>> readCheckInRecords();
  Future<void> putCheckInRecord(String id, Map<String, dynamic> record);
}

class HiveMedicationCheckInLocalDataSource
    implements MedicationCheckInLocalDataSource {
  HiveMedicationCheckInLocalDataSource(this._box);

  final Box<dynamic> _box;

  @override
  List<Map<dynamic, dynamic>> readCheckInRecords() => _box.values
      .map((value) => Map<dynamic, dynamic>.from(value as Map))
      .toList(growable: false);

  @override
  Future<void> putCheckInRecord(String id, Map<String, dynamic> record) =>
      _box.put(id, record);
}
