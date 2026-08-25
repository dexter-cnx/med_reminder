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
    final sourceById = <String, Medication>{
      for (final medication in medications) medication.id: medication,
    };
    final previousIds = <int>[
      for (final medication in medications) ...medication.notificationIds,
    ];
    final createdIdsByMedication = <String, List<int>>{};
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
          createdIdsByMedication[medication.id] = const <int>[];
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
        createdIdsByMedication[medication.id] = ids;
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

    final latestResult = medicationRepository.readAll();
    if (latestResult case Failed<List<Medication>>(:final failure)) {
      return _cleanupCreated(createdIds, failure);
    }
    final latest = (latestResult as Success<List<Medication>>).value;
    final latestIds = latest.map((medication) => medication.id).toSet();
    final merged = <Medication>[];
    final retainedCreatedIds = <int>[];
    final staleCreatedIds = <int>[];

    for (final medication in latest) {
      final source = sourceById[medication.id];
      final ids = createdIdsByMedication[medication.id] ?? const <int>[];
      if (source == null || !_sameReminderDefinition(source, medication)) {
        staleCreatedIds.addAll(ids);
        merged.add(medication);
        continue;
      }

      retainedCreatedIds.addAll(ids);
      merged.add(medication.copyWith(notificationIds: ids));
    }

    for (final entry in createdIdsByMedication.entries) {
      if (!latestIds.contains(entry.key)) {
        staleCreatedIds.addAll(entry.value);
      }
    }

    try {
      if (staleCreatedIds.isNotEmpty) {
        await reminderScheduler.cancelIds(staleCreatedIds);
      }
    } on Object {
      return _cleanupCreated(
        retainedCreatedIds,
        const Failure(
          code: 'medication_reminder_reconcile_cleanup_failed',
          message:
              'Obsolete reconciled medication reminders could not be cleaned up.',
        ),
      );
    }

    final persisted = await medicationRepository.replaceAll(merged);
    if (persisted case Failed<void>(:final failure)) {
      return _cleanupCreated(retainedCreatedIds, failure);
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

bool _sameReminderDefinition(Medication before, Medication after) =>
    before.name == after.name &&
    before.times.length == after.times.length &&
    _sameStrings(before.times, after.times) &&
    before.createdAt == after.createdAt &&
    before.initialAmount == after.initialAmount &&
    before.dosagePerTime == after.dosagePerTime &&
    before.mode == after.mode &&
    before.dosePlan == after.dosePlan &&
    before.daysCount == after.daysCount;

bool _sameStrings(List<String> left, List<String> right) {
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
