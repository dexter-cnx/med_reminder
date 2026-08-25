import '../../../core/result/result.dart';
import 'build_today_doses.dart';
import 'reminder_reconciliation_transaction.dart';
import '../domain/repositories/medication_repository.dart';
import '../domain/services/medication_services.dart';

final class ReconcileMedicationReminders {
  const ReconcileMedicationReminders({
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

  Future<Result<void>> call() => ReminderReconciliationTransaction(
    medicationRepository: medicationRepository,
    doseLogRepository: doseLogRepository,
    reminderScheduler: reminderScheduler,
    stockResolver: stockResolver,
    now: _now,
    failures: const ReminderReconciliationFailureProfile(
      scheduleFailure: Failure(
        code: 'medication_reminder_reconcile_failed',
        message: 'Medication reminders could not be reconciled.',
      ),
      cleanupFailure: Failure(
        code: 'medication_reminder_reconcile_cleanup_failed',
        message:
            'Medication reminder reconciliation failed and partial schedules could not be cleaned up.',
      ),
    ),
  ).run();
}
