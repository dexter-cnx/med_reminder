import '../../../../core/result/result.dart';
import '../entities/medication.dart';

export 'dose_log_repository.dart';

abstract interface class MedicationRepository {
  Result<List<Medication>> readAll();
  Future<Result<void>> replaceAll(List<Medication> medications);
  Future<Result<void>> delete(String id);
}
