import '../../../../core/result/result.dart';
import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../datasources/medication_local_data_source.dart';
import '../models/medication_record.dart';

class LocalMedicationRepository implements MedicationRepository {
  LocalMedicationRepository(this._dataSource);
  final MedicationLocalDataSource _dataSource;

  @override
  Result<List<Medication>> readAll() {
    try {
      final items = _dataSource
          .readMedicationRecords()
          .map((record) => MedicationRecord(Map<String, dynamic>.from(record)).toEntity())
          .toList(growable: false);
      return Success<List<Medication>>(items);
    } catch (error) {
      return Failed<List<Medication>>(
        Failure(code: 'medication_read_failed', message: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> replaceAll(List<Medication> medications) async {
    try {
      await _dataSource.replaceMedicationRecords(
        medications.map((item) => MedicationRecord.fromEntity(item).value).toList(growable: false),
      );
      return const Success<void>(null);
    } catch (error) {
      return Failed<void>(
        Failure(code: 'medication_write_failed', message: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    return readAll().fold(
      onSuccess: (items) => replaceAll(
        items.where((item) => item.id != id).toList(growable: false),
      ),
      onFailure: (failure) async => Failed<void>(failure),
    );
  }
}

class LocalDoseLogRepository implements DoseLogRepository {
  LocalDoseLogRepository(this._dataSource);
  final MedicationLocalDataSource _dataSource;

  @override
  Result<List<DoseLog>> readAll() {
    try {
      final items = _dataSource
          .readDoseLogRecords()
          .map((record) => DoseLogRecord(Map<String, dynamic>.from(record)).toEntity())
          .toList(growable: false);
      return Success<List<DoseLog>>(items);
    } catch (error) {
      return Failed<List<DoseLog>>(
        Failure(code: 'dose_log_read_failed', message: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> replaceAll(List<DoseLog> logs) async {
    try {
      await _dataSource.replaceDoseLogRecords(
        logs.map((item) => DoseLogRecord.fromEntity(item).value).toList(growable: false),
      );
      return const Success<void>(null);
    } catch (error) {
      return Failed<void>(
        Failure(code: 'dose_log_write_failed', message: error.toString()),
      );
    }
  }
}
