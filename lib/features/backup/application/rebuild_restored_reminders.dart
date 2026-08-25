import '../../../core/result/result.dart';
import '../../medication/application/build_today_doses.dart';
import '../../medication/application/reminder_reconciliation_transaction.dart';
import '../../medication/domain/repositories/medication_repository.dart';
import '../../medication/domain/services/medication_services.dart';

final class RebuildRestoredReminders {
  const RebuildRestoredReminders({
    required this.medicationRepository,
    required this.doseLogRepository,
    required this.reminderScheduler,
    required this.stockResolver,
    DateTime Function()? now,
  }) : _now = now;

  final MedicationRepository medicationRepository;
  final DoseLogRepository doseLogRepository;
  final MedicationReminderScheduler reminderScheduler;
  final MedicationStockResolver stockResolver;
  final DateTime Function()? _now;

  Future<Result<void>> call({
    Iterable<int> previousNotificationIds = const <int>[],
  }) => ReminderReconciliationTransaction(
    medicationRepository: medicationRepository,
    doseLogRepository: doseLogRepository,
    reminderScheduler: reminderScheduler,
    stockResolver: stockResolver,
    now: _now,
    failures: ReminderReconciliationFailureProfile(
      scheduleFailure: const Failure(
        code: 'backup_restore_reminder_rebuild_failed',
        message:
            'Backup data was restored, but medication reminders could not be rebuilt.',
      ),
      cleanupFailure: const Failure(
        code: 'backup_restore_reminder_cleanup_failed',
        message:
            'Backup data was restored, but partially rebuilt reminders could not be cleaned up.',
      ),
      latestReadFailure: (_) => const Failure(
        code: 'backup_restore_reminder_state_persist_failed',
        message:
            'Backup data was restored, but rebuilt reminder state could not be saved.',
      ),
      persistFailure: (_) => const Failure(
        code: 'backup_restore_reminder_state_persist_failed',
        message:
            'Backup data was restored, but rebuilt reminder state could not be saved.',
      ),
    ),
  ).run(previousNotificationIds: previousNotificationIds);
}
