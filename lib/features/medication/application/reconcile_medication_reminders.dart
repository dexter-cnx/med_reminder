import '../../../core/result/result.dart';
import 'build_today_doses.dart';
import '../domain/entities/medication.dart';
import '../domain/repositories/medication_repository.dart';
import '../domain/services/medication_services.dart';

final class ReconcileMedicationReminders {
  const ReconcileMedicationReminders({
    required this.medicationRepository,
    required this.doseLogRepository,
    required this.reminderScheduler,
    required this.stockResolver,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MedicationRepository medicationRepository;
  final DoseLogRepository doseLogRepository;
  final MedicationReminderScheduler reminderScheduler;
  final MedicationStockResolver stockResolver;
  final DateTime Function() _now;

  Future<Result<void>> call() async {
    final medicationsResult = medicationRepository.readAll();
    if (medicationsResult case Failed<List<Medication>>(:final failure)) {
      return Failed<void>(failure);
    }
    final logsResult = doseLogRepository.readAll();
    if (logsResult case Failed<List<DoseLog>>(:final failure)) {
      return Failed<void>(failure);
    }

    final medications = (medicationsResult as Success<List<Medication>>).value;
    final logs = (logsResult as Success<List<DoseLog>>).value;
    final previousIds = <int>[
      for (final medication in medications) ...medication.notificationIds,
    ];
    final rebuilt = <Medication>[];
    final createdIds = <int>[];

    try {
      await reminderScheduler.cancelIds(previousIds);
      final now = _now();
      for (final medication in medications) {
        final remaining = stockResolver(medication, logs);
        final shouldNotSchedule =
            medication.isAsNeeded ||
            medication.isExpired(now) ||
            (medication.mode == MedicationMode.untilEmpty && remaining == 0);
        if (shouldNotSchedule) {
          rebuilt.add(medication.copyWith(notificationIds: const <int>[]));
          continue;
        }

        final schedulingSnapshot =
            medication.mode == MedicationMode.untilEmpty &&
                remaining != null &&
                remaining > 0
            ? medication.copyWith(initialAmount: remaining)
            : medication;
        final ids = await reminderScheduler.schedule(schedulingSnapshot);
        createdIds.addAll(ids);
        rebuilt.add(medication.copyWith(notificationIds: ids));
      }
    } on Object {
      return _cleanupCreated(
        createdIds,
        const Failure(
          code: 'medication_reminder_reconcile_failed',
          message: 'Medication reminders could not be reconciled.',
        ),
      );
    }

    final persisted = await medicationRepository.replaceAll(rebuilt);
    if (persisted case Failed<void>(:final failure)) {
      return _cleanupCreated(createdIds, failure);
    }
    return const Success<void>(null);
  }

  Future<Result<void>> _cleanupCreated(
    Iterable<int> createdIds,
    Failure failure,
  ) async {
    try {
      await reminderScheduler.cancelIds(createdIds);
    } on Object {
      return const Failed<void>(
        Failure(
          code: 'medication_reminder_reconcile_cleanup_failed',
          message:
              'Medication reminder reconciliation failed and partial schedules could not be cleaned up.',
        ),
      );
    }
    return Failed<void>(failure);
  }
}
