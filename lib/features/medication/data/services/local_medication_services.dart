import '../../../../services/notification_service.dart';
import '../../../../services/photo_service.dart';
import '../../domain/entities/medication.dart';
import '../../domain/services/medication_services.dart';

class LocalMedicationReminderScheduler implements MedicationReminderScheduler {
  const LocalMedicationReminderScheduler();

  @override
  Future<List<int>> schedule(Medication medication) =>
      NotificationService.scheduleForMed(medication);

  @override
  Future<void> cancelIds(Iterable<int> ids) => NotificationService.cancelIds(ids);

  @override
  Future<void> showLowStock(String name, int remaining) =>
      NotificationService.showLowStock(name, remaining);

  @override
  Future<void> scheduleSnooze({
    required String medId,
    required String medName,
    required int dosage,
    required DateTime scheduledDose,
  }) =>
      NotificationService.scheduleSnooze(
        medId: medId,
        medName: medName,
        dosage: dosage,
        scheduledDose: scheduledDose,
      );

  @override
  Future<void> cancelSnooze(String medId, DateTime scheduledDose) =>
      NotificationService.cancelSnooze(medId, scheduledDose);
}

class LocalMedicationPhotoStore implements MedicationPhotoStore {
  const LocalMedicationPhotoStore();

  @override
  Future<void> delete(String? path) => PhotoService.deletePhoto(path);

  @override
  Future<int> pruneOrphaned(Iterable<String> referencedPaths) =>
      PhotoService.pruneOrphaned(referencedPaths);
}
