import 'package:hive/hive.dart';

import '../../models/medication.dart';
import '../medication_repository.dart';

class HiveMedicationRepository implements MedicationRepository {
  HiveMedicationRepository(this._box);

  final Box<dynamic> _box;

  @override
  List<Medication> readAll() => _box.values
      .map(
        (value) => Medication.fromMap(
          Map<dynamic, dynamic>.from(value as Map),
        ),
      )
      .toList(growable: false);

  @override
  Future<void> replaceAll(List<Medication> medications) async {
    await _box.clear();
    for (final medication in medications) {
      await _box.add(medication.toMap());
    }
  }
}

class HiveDoseLogRepository implements DoseLogRepository {
  HiveDoseLogRepository(this._box);

  final Box<dynamic> _box;

  @override
  List<DoseLog> readAll() => _box.values
      .map(
        (value) => DoseLog.fromMap(
          Map<dynamic, dynamic>.from(value as Map),
        ),
      )
      .toList(growable: false);

  @override
  Future<void> replaceAll(List<DoseLog> logs) async {
    await _box.clear();
    for (final log in logs) {
      await _box.add(log.toMap());
    }
  }
}
