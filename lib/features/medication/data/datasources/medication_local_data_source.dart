import 'package:hive/hive.dart';

abstract interface class MedicationLocalDataSource {
  List<Map<dynamic, dynamic>> readMedicationRecords();
  List<Map<dynamic, dynamic>> readDoseLogRecords();
  Future<void> replaceMedicationRecords(List<Map<String, dynamic>> records);
  Future<void> replaceDoseLogRecords(List<Map<String, dynamic>> records);
}

class HiveMedicationLocalDataSource implements MedicationLocalDataSource {
  HiveMedicationLocalDataSource({
    required Box<dynamic> medicationBox,
    required Box<dynamic> doseLogBox,
  })  : _medicationBox = medicationBox,
        _doseLogBox = doseLogBox;

  final Box<dynamic> _medicationBox;
  final Box<dynamic> _doseLogBox;

  @override
  List<Map<dynamic, dynamic>> readMedicationRecords() => _medicationBox.values
      .map((value) => Map<dynamic, dynamic>.from(value as Map))
      .toList(growable: false);

  @override
  List<Map<dynamic, dynamic>> readDoseLogRecords() => _doseLogBox.values
      .map((value) => Map<dynamic, dynamic>.from(value as Map))
      .toList(growable: false);

  @override
  Future<void> replaceMedicationRecords(
    List<Map<String, dynamic>> records,
  ) async {
    await _medicationBox.clear();
    for (final record in records) {
      await _medicationBox.add(record);
    }
  }

  @override
  Future<void> replaceDoseLogRecords(List<Map<String, dynamic>> records) async {
    await _doseLogBox.clear();
    for (final record in records) {
      await _doseLogBox.add(record);
    }
  }
}
