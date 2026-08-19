import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../../domain/services/medication_services.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => throw UnimplementedError(
    'MedicationRepository must be provided by app DI.',
  ),
);

final doseLogRepositoryProvider = Provider<DoseLogRepository>(
  (ref) =>
      throw UnimplementedError('DoseLogRepository must be provided by app DI.'),
);

final medicationReminderSchedulerProvider =
    Provider<MedicationReminderScheduler>(
      (ref) => throw UnimplementedError(
        'MedicationReminderScheduler must be provided by app DI.',
      ),
    );

final medicationPhotoStoreProvider = Provider<MedicationPhotoStore>(
  (ref) => throw UnimplementedError(
    'MedicationPhotoStore must be provided by app DI.',
  ),
);

final repositoryFailureProvider = StateProvider<Failure?>((ref) => null);

final medsProvider =
    StateNotifierProvider<MedicationViewModel, List<Medication>>(
      (ref) => MedicationViewModel(
        repository: ref.watch(medicationRepositoryProvider),
        reminderScheduler: ref.watch(medicationReminderSchedulerProvider),
        photoStore: ref.watch(medicationPhotoStoreProvider),
        onFailure: (failure) =>
            ref.read(repositoryFailureProvider.notifier).state = failure,
      ),
    );

final logsProvider = StateNotifierProvider<DoseLogViewModel, List<DoseLog>>(
  (ref) => DoseLogViewModel(
    ref.watch(doseLogRepositoryProvider),
    onFailure: (failure) =>
        ref.read(repositoryFailureProvider.notifier).state = failure,
    onTaken: (medId, logs) =>
        ref.read(medsProvider.notifier).reconcileFromLogs(medId, logs),
  ),
);

final todayDosesProvider = Provider<List<ScheduledDose>>((ref) {
  final meds = ref.watch(medsProvider);
  final logs = ref.watch(logsProvider);
  final now = DateTime.now();
  final doses = <ScheduledDose>[];

  for (final med in meds) {
    if (!med.isActiveOn(now, logs: logs)) continue;
    final remaining = med.remaining(logs);
    for (final time in med.times) {
      final parts = time.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
      DoseLog? existing;
      for (final log in logs) {
        if (_sameDose(log, med.id, scheduled)) {
          existing = log;
          break;
        }
      }
      doses.add(
        ScheduledDose(
          medication: med,
          scheduledAt: scheduled,
          log: existing,
          remaining: remaining,
        ),
      );
    }
  }

  doses.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return doses;
});

bool _sameDose(DoseLog log, String medId, DateTime scheduled) =>
    log.medId == medId &&
    log.scheduledAt.year == scheduled.year &&
    log.scheduledAt.month == scheduled.month &&
    log.scheduledAt.day == scheduled.day &&
    log.scheduledAt.hour == scheduled.hour &&
    log.scheduledAt.minute == scheduled.minute;

List<Medication> _loadMedications(
  MedicationRepository repository,
  void Function(Failure failure) onFailure,
) => repository.readAll().fold(
  onSuccess: (items) => items,
  onFailure: (failure) {
    onFailure(failure);
    return const <Medication>[];
  },
);

List<DoseLog> _loadLogs(
  DoseLogRepository repository,
  void Function(Failure failure) onFailure,
) => repository.readAll().fold(
  onSuccess: (items) => items,
  onFailure: (failure) {
    onFailure(failure);
    return const <DoseLog>[];
  },
);

class MedicationViewModel extends StateNotifier<List<Medication>> {
  MedicationViewModel({
    required MedicationRepository repository,
    required MedicationReminderScheduler reminderScheduler,
    required MedicationPhotoStore photoStore,
    required void Function(Failure failure) onFailure,
  }) : _repository = repository,
       _reminderScheduler = reminderScheduler,
       _photoStore = photoStore,
       _onFailure = onFailure,
       super(_loadMedications(repository, onFailure));

  final MedicationRepository _repository;
  final MedicationReminderScheduler _reminderScheduler;
  final MedicationPhotoStore _photoStore;
  final void Function(Failure failure) _onFailure;

  Future<bool> _persist() async {
    final result = await _repository.replaceAll(state);
    return result.fold(
      onSuccess: (_) => true,
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }

  Future<void> add(Medication medication) async {
    final ids = await _reminderScheduler.schedule(medication);
    state = <Medication>[...state, medication.copyWith(notificationIds: ids)];
    await _persist();
  }

  Future<void> reconcileFromLogs(String id, Iterable<DoseLog> logs) async {
    final index = state.indexWhere((med) => med.id == id);
    if (index < 0) return;

    final old = state[index];
    final remaining = old.remaining(logs);
    var updated = old;

    if (old.mode == MedicationMode.untilEmpty &&
        remaining == 0 &&
        old.notificationIds.isNotEmpty) {
      await _reminderScheduler.cancelIds(old.notificationIds);
      updated = old.copyWith(notificationIds: const <int>[]);
    }

    final threshold = old.lowThreshold;
    if (threshold != null && remaining != null) {
      final before = remaining + old.dosagePerTime;
      if (before > threshold && remaining <= threshold) {
        await _reminderScheduler.showLowStock(old.name, remaining);
      }
    }

    if (!identical(updated, old)) {
      final next = <Medication>[...state];
      next[index] = updated;
      state = next;
      await _persist();
    }
  }

  Future<void> rescheduleAll(Iterable<DoseLog> logs) async {
    final now = DateTime.now();
    final next = <Medication>[];
    for (final medication in state) {
      if (medication.isExpired(now) ||
          !medication.isActiveOn(now, logs: logs)) {
        await _reminderScheduler.cancelIds(medication.notificationIds);
        next.add(medication.copyWith(notificationIds: const <int>[]));
        continue;
      }
      final ids = await _reminderScheduler.schedule(medication);
      next.add(medication.copyWith(notificationIds: ids));
    }
    state = next;
    await _persist();
  }

  Future<void> remove(String id) async {
    final med = state.where((item) => item.id == id).firstOrNull;
    if (med == null) return;
    await _reminderScheduler.cancelIds(med.notificationIds);
    await _photoStore.delete(med.imagePath);
    final result = await _repository.delete(id);
    final deleted = result.fold(
      onSuccess: (_) => true,
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
    if (!deleted) return;
    state = state.where((item) => item.id != id).toList(growable: false);
  }
}

typedef DoseTakenCallback = Future<void> Function(
  String medId,
  List<DoseLog> logs,
);

class DoseLogViewModel extends StateNotifier<List<DoseLog>> {
  DoseLogViewModel(
    this._repository, {
    required void Function(Failure failure) onFailure,
    this.onTaken,
  }) : _onFailure = onFailure,
       super(_loadLogs(repository, onFailure));

  final DoseLogRepository _repository;
  final void Function(Failure failure) _onFailure;
  final DoseTakenCallback? onTaken;

  Future<bool> _persist() async {
    final result = await _repository.replaceAll(state);
    return result.fold(
      onSuccess: (_) => true,
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }

  Future<void> markTaken(String medId, DateTime scheduledAt) async {
    await _upsert(
      medId,
      scheduledAt,
      DoseStatus.taken,
      takenAt: DateTime.now(),
    );
    await onTaken?.call(medId, state);
  }

  Future<void> markSkipped(String medId, DateTime scheduledAt) =>
      _upsert(medId, scheduledAt, DoseStatus.skipped);

  Future<void> markSnoozed(String medId, DateTime scheduledAt) =>
      _upsert(medId, scheduledAt, DoseStatus.snoozed);

  Future<void> _upsert(
    String medId,
    DateTime scheduledAt,
    DoseStatus status, {
    DateTime? takenAt,
  }) async {
    final replacement = DoseLog(
      id: const Uuid().v4(),
      medId: medId,
      scheduledAt: scheduledAt,
      takenAt: takenAt,
      status: status,
    );
    final previous = state;
    state = <DoseLog>[
      ...state.where((log) => !_sameDose(log, medId, scheduledAt)),
      replacement,
    ];
    if (!await _persist()) {
      state = previous;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
