import '../../../core/result/result.dart';
import '../../medication/application/build_today_doses.dart';
import '../../medication/domain/entities/medication.dart';
import '../../medication/domain/repositories/medication_repository.dart';
import '../../medication/domain/services/medication_services.dart';

final class RebuildRestoredReminders {
  const RebuildRestoredReminders({
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

  Future<Result<void>> call({
    Iterable<int> previousNotificationIds = const <int>[],
  }) async {
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
    final rebuiltById = <String, Medication>{};
    final sourceById = <String, Medication>{
      for (final medication in medications) medication.id: medication,
    };
    final createdIdsByMedication = <String, List<int>>{};
    final createdIds = <int>[];

    try {
      await reminderScheduler.cancelIds(previousNotificationIds);
      final now = _now();
      for (final medication in medications) {
        final remaining = stockResolver(medication, logs);
        final shouldNotSchedule =
            medication.isExpired(now) ||
            (medication.mode == MedicationMode.untilEmpty && remaining == 0);
        if (shouldNotSchedule) {
          rebuiltById[medication.id] = medication.copyWith(
            notificationIds: const <int>[],
          );
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
        rebuiltById[medication.id] = medication.copyWith(notificationIds: ids);
      }
    } on Object {
      return _cleanupCreatedIds(
        createdIds,
        failureCode: 'backup_restore_reminder_rebuild_failed',
        failureMessage:
            'Backup data was restored, but medication reminders could not be rebuilt.',
      );
    }

    final latestResult = medicationRepository.readAll();
    if (latestResult case Failed<List<Medication>>()) {
      return _cleanupCreatedIds(
        createdIds,
        failureCode: 'backup_restore_reminder_state_persist_failed',
        failureMessage:
            'Backup data was restored, but rebuilt reminder state could not be saved.',
      );
    }

    final latest = (latestResult as Success<List<Medication>>).value;
    final merged = <Medication>[];
    final retainedCreatedIds = <int>[];
    final staleCreatedIds = <int>[];

    for (final medication in latest) {
      final source = sourceById[medication.id];
      final rebuilt = rebuiltById[medication.id];
      final ids = createdIdsByMedication[medication.id] ?? const <int>[];
      if (source == null ||
          rebuilt == null ||
          !_sameReminderDefinition(source, medication)) {
        staleCreatedIds.addAll(ids);
        merged.add(medication);
        continue;
      }

      retainedCreatedIds.addAll(ids);
      merged.add(medication.copyWith(notificationIds: rebuilt.notificationIds));
    }

    final latestIds = latest.map((medication) => medication.id).toSet();
    for (final entry in createdIdsByMedication.entries) {
      if (!latestIds.contains(entry.key)) staleCreatedIds.addAll(entry.value);
    }

    try {
      if (staleCreatedIds.isNotEmpty) {
        await reminderScheduler.cancelIds(staleCreatedIds);
      }
    } on Object {
      return _cleanupCreatedIds(
        retainedCreatedIds,
        failureCode: 'backup_restore_reminder_cleanup_failed',
        failureMessage:
            'Backup data was restored, but obsolete rebuilt reminders could not be cleaned up.',
      );
    }

    final persisted = await medicationRepository.replaceAll(merged);
    if (persisted case Failed<void>()) {
      return _cleanupCreatedIds(
        retainedCreatedIds,
        failureCode: 'backup_restore_reminder_state_persist_failed',
        failureMessage:
            'Backup data was restored, but rebuilt reminder state could not be saved.',
      );
    }
    return const Success<void>(null);
  }

  Future<Result<void>> _cleanupCreatedIds(
    Iterable<int> createdIds, {
    required String failureCode,
    required String failureMessage,
  }) async {
    try {
      await reminderScheduler.cancelIds(createdIds);
    } on Object {
      return const Failed<void>(
        Failure(
          code: 'backup_restore_reminder_cleanup_failed',
          message:
              'Backup data was restored, but partially rebuilt reminders could not be cleaned up.',
        ),
      );
    }
    return Failed<void>(Failure(code: failureCode, message: failureMessage));
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
