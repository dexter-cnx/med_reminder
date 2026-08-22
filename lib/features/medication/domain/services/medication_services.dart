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

/// Persists the threshold for which the current low-stock episode was alerted.
///
/// This is notification delivery state only. Remaining stock stays derived from
/// medication, dose-log, and refill events and is never persisted here.
abstract interface class LowStockAlertStateStore {
  int? alertedThreshold(String medicationId);
  Future<void> markAlerted(String medicationId, int threshold);
  Future<void> clear(String medicationId);
}

abstract interface class MedicationPhotoStore {
  Future<void> delete(String? path);
  Future<int> pruneOrphaned(Iterable<String> referencedPaths);
}
