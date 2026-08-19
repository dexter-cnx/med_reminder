import '../entities/medication.dart';

abstract interface class MedicationReminderScheduler {
  Future<List<int>> schedule(Medication medication);
  Future<void> cancelIds(Iterable<int> ids);
  Future<void> showLowStock(String name, int remaining);
  Future<void> scheduleSnooze({
    required String medId,
    required String medName,
    required int dosage,
    required DateTime scheduledDose,
  });
  Future<void> cancelSnooze(String medId, DateTime scheduledDose);
}

abstract interface class MedicationPhotoStore {
  Future<void> delete(String? path);
}
