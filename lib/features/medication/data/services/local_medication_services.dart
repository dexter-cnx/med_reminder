import 'package:hive/hive.dart';

import '../../../../services/notification_service.dart';
import '../../../../services/photo_service.dart';
import '../../application/reminder_scheduling_window.dart';
import '../../domain/entities/medication.dart';
import '../../domain/services/medication_services.dart';

class LocalMedicationReminderScheduler implements MedicationReminderScheduler {
  const LocalMedicationReminderScheduler();

  @override
  Future<List<int>> schedule(Medication medication) async {
    final projected = defaultReminderSchedulingWindow.project(
      medication,
      DateTime.now(),
    );
    if (projected == null) {
      await NotificationService.cancelIds(medication.notificationIds);
      return const <int>[];
    }
    return NotificationService.scheduleForMed(projected);
  }

  @override
  Future<void> cancelIds(Iterable<int> ids) =>
      NotificationService.cancelIds(ids);

  @override
  Future<void> showLowStock(String name, int remaining) =>
      NotificationService.showLowStock(name, remaining);

  @override
  Future<void> scheduleSnooze({
    required String medId,
    required String medName,
    required int dosage,
    required DateTime scheduledDose,
  }) => NotificationService.scheduleSnooze(
    medId: medId,
    medName: medName,
    dosage: dosage,
    scheduledDose: scheduledDose,
  );

  @override
  Future<void> cancelSnooze(String medId, DateTime scheduledDose) =>
      NotificationService.cancelSnooze(medId, scheduledDose);
}

class HiveLowStockAlertStateStore implements LowStockAlertStateStore {
  HiveLowStockAlertStateStore(this._settingsBox);

  static const _keyPrefix = 'low_stock_alert_threshold:';

  final Box<dynamic> _settingsBox;

  String _key(String medicationId) => '$_keyPrefix$medicationId';

  @override
  int? alertedThreshold(String medicationId) {
    final value = _settingsBox.get(_key(medicationId));
    return value is int ? value : null;
  }

  @override
  Future<void> markAlerted(String medicationId, int threshold) =>
      _settingsBox.put(_key(medicationId), threshold);

  @override
  Future<void> clear(String medicationId) =>
      _settingsBox.delete(_key(medicationId));
}

class LocalMedicationPhotoStore implements MedicationPhotoStore {
  const LocalMedicationPhotoStore();

  @override
  Future<void> delete(String? path) => PhotoService.deletePhoto(path);

  @override
  Future<int> pruneOrphaned(Iterable<String> referencedPaths) =>
      PhotoService.pruneOrphaned(referencedPaths);
}