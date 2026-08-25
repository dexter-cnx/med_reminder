import '../../../core/result/result.dart';
import 'build_today_doses.dart';
import '../domain/entities/medication.dart';
import '../domain/repositories/medication_repository.dart';
import '../domain/services/medication_services.dart';

final class ReminderReconciliationFailureProfile {
  const ReminderReconciliationFailureProfile({
    required this.scheduleFailure,
    required this.cleanupFailure,
    this.latestReadFailure,
    this.persistFailure,
  });

  final Failure scheduleFailure;
  final Failure cleanupFailure;
  final Failure Function(Failure failure)? latestReadFailure;
  final Failure Function(Failure failure)? persistFailure;
}

final class ReminderReconciliationTransaction {
  const ReminderReconciliationTransaction({
    required this.medicationRepository,
    required this.doseLogRepository,
    required this.reminderScheduler,
    required this.stockResolver,
    required this.failures,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MedicationRepository medicationRepository;
  final DoseLogRepository doseLogRepository;
  final MedicationReminderScheduler reminderScheduler;
  final MedicationStockResolver stockResolver;
  final ReminderReconciliationFailureProfile failures;
  final DateTime Function() _now;

  Future<Result<void>> run({Iterable<int>? previousNotificationIds}) async {
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
    final previousIds =
        previousNotificationIds?.toList(growable: false) ??
        <int>[
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
      return _cleanupCreated(createdIds, failures.scheduleFailure);
    }

    final latestResult = medicationRepository.readAll();
    if (latestResult case Failed<List<Medication>>(:final failure)) {
      final mapped = failures.latestReadFailure?.call(failure) ?? failure;
      return _cleanupCreated(createdIds, mapped);
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
      return _cleanupCreated(retainedCreatedIds, failures.cleanupFailure);
    }

    final persisted = await medicationRepository.replaceAll(merged);
    if (persisted case Failed<void>(:final failure)) {
      final mapped = failures.persistFailure?.call(failure) ?? failure;
      return _cleanupCreated(retainedCreatedIds, mapped);
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
      return Failed<void>(failures.cleanupFailure);
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
