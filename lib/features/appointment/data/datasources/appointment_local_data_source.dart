import 'package:hive/hive.dart';

abstract interface class AppointmentLocalDataSource {
  List<Map<dynamic, dynamic>> readAppointmentRecords();
  Future<void> putAppointmentRecord(String id, Map<String, dynamic> record);
  Future<void> deleteAppointmentRecord(String id);
}

class HiveAppointmentLocalDataSource implements AppointmentLocalDataSource {
  HiveAppointmentLocalDataSource(this._box);

  final Box<dynamic> _box;

  @override
  List<Map<dynamic, dynamic>> readAppointmentRecords() => _box.values
      .map((value) => Map<dynamic, dynamic>.from(value as Map))
      .toList(growable: false);

  @override
  Future<void> putAppointmentRecord(
    String id,
    Map<String, dynamic> record,
  ) =>
      _box.put(id, record);

  @override
  Future<void> deleteAppointmentRecord(String id) => _box.delete(id);
}
