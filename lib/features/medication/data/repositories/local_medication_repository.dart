import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../datasources/medication_local_data_source.dart';
import '../models/medication_record.dart';

class LocalMedicationRepository implements MedicationRepository {
  LocalMedicationRepository(this._dataSource);
  final MedicationLocalDataSource _dataSource;

  @override
  List<Medication> readAll() => _dataSource
      .readMedicationRecords()
      .map((record) => MedicationRecord(Map<String, dynamic>.from(record)).toEntity())
      .toList(growable: false);

  @override
  Future<void> replaceAll(List<Medication> medications) =>
      _dataSource.replaceMedicationRecords(
        medications.map((item) => MedicationRecord.fromEntity(item).value).toList(growable: false),
      );
}

class LocalDoseLogRepository implements DoseLogRepository {
  LocalDoseLogRepository(this._dataSource);
  final MedicationLocalDataSource _dataSource;

  @override
  List<DoseLog> readAll() => _dataSource
      .readDoseLogRecords()
      .map((record) => DoseLogRecord(Map<String, dynamic>.from(record)).toEntity())
      .toList(growable: false);

  @override
  Future<void> replaceAll(List<DoseLog> logs) => _dataSource.replaceDoseLogRecords(
        logs.map((item) => DoseLogRecord.fromEntity(item).value).toList(growable: false),
      );
}
