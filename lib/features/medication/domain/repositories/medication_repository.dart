import '../entities/medication.dart';

abstract interface class MedicationRepository {
  List<Medication> readAll();
  Future<void> replaceAll(List<Medication> medications);
  Future<void> delete(String id);
}

abstract interface class DoseLogRepository {
  List<DoseLog> readAll();
  Future<void> replaceAll(List<DoseLog> logs);
}
