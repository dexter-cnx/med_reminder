import '../../../../core/result/result.dart';
import '../entities/medication.dart';

abstract interface class MedicationRepository {
  Result<List<Medication>> readAll();
  Future<Result<void>> replaceAll(List<Medication> medications);
  Future<Result<void>> delete(String id);
}

abstract interface class DoseLogRepository {
  Result<List<DoseLog>> readAll();
  Future<Result<void>> replaceAll(List<DoseLog> logs);
}
