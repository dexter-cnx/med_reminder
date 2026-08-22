import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/result/result.dart';
import '../../application/build_today_doses.dart';
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

final medicationStockResolverProvider = Provider<MedicationStockResolver>(
  (ref) => legacyMedicationStockResolver,
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

void _reportFailure(Ref ref, Failure failure) {
  Future<void>.microtask(() {
    ref.read(repositoryFailureProvider.notifier).state = failure;
  });
}

final medsProvider =
    StateNotifierProvider<MedicationViewModel, List<Medication>>(
  (ref) => MedicationViewModel(
    repository: ref.watch(medicationRepositoryProvider),
    reminderScheduler: ref.watch(medicationReminderSchedulerProvider),
    photoStore: ref.watch(medicationPhotoStoreProvider),
    stockResolver: ref.watch(medicationStockResolverProvider),
    onFailure: (failure) => _reportFailure(ref, failure),
  ),
);

final logsProvider = StateNotifierProvider<DoseLogViewModel, List<DoseLog>>(
  (ref) => DoseLogViewModel(
    ref.watch(doseLogRepositoryProvider),
    onFailure: (failure) => _reportFailure(ref, failure),
    onTaken: (medId, logs) =>
        ref.read(medsProvider.notifier).reconcileFromLogs(medId, logs),
  ),
);

final todayDosesProvider = Provider<List<ScheduledDose>>((ref) {
  return buildTodayDoses(
    medications: ref.watch(medsProvider),
    logs: ref.watch(logsProvider),
    stockResolver: ref.watch(medicationStockResolverProvider),
  );
});

bool _sameDose(DoseLog log, String medId, DateTime scheduled) =>
    isSameScheduledDose(log, medId, scheduled);

List<Medication> _loadMedications(
  MedicationRepository repository,
  void Function(Failure failure) onFailure,
) =>
    repository.readAll().fold(
          onSuccess: (items) => items,
          onFailure: (failure) {
            onFailure(failure);
            return const <Medication>[];
          },
        );

List<DoseLog> _loadLogs(
  DoseLogRepository repository,
  void Function(Failure failure) onFailure,
) =>
    repository.readAll().fold(
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
    required MedicationStockResolver stockResolver,
    required void Function(Failure failure) onFailure,
  })  : _repository = repository,
        _reminderScheduler = reminderScheduler,
        _photoStore = photoStore,
        _stockResolver = stockResolver,
        _onFailure = onFailure,
        super(_loadMedications(repository, onFailure));

  final MedicationRepository _repository;
  final MedicationReminderScheduler _reminderScheduler;
  final MedicationPhotoStore _photoStore;
  final MedicationStockResolver _stockResolver;
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
    final remaining = _stockResolver(old, logs);
    var updated = old;

    if (old.mode == MedicationMode.untilEmpty &&
        remaining == 0 &&
        old.notificationIds.isNotEmpty) {
      await _reminderScheduler.cancelIds(old.notificationIds);
      updated = old.copyWith(notificationIds: const <int>[]);
    }

    final threshold = old.lowThreshold;
    if (threshold != null && remaining != null && remaining <= threshold) {
      final before = remaining + old.dosagePerTime;
      if (before > threshold) {
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

  Future<void> refreshAfterRefill(String id, Iterable<DoseLog> logs) async {
    final index = state.indexWhere((med) => med.id == id);
    if (index < 0) return;

    final old = state[index];
    if (old.mode != MedicationMode.untilEmpty ||
        old.isExpired(DateTime.now())) {
      return;
    }

    final remaining = _stockResolver(old, logs);
    if (remaining == null || remaining == 0 || old.notificationIds.isNotEmpty) {
      return;
    }

    // The platform scheduler still guards legacy until-empty medications whose
    // initial amount is zero. Pass a scheduling snapshot with the refill-aware
    // balance so a positive refill can restore reminders without mutating the
    // medication's persisted initial amount.
    final ids = await _reminderScheduler.schedule(
      old.copyWith(initialAmount: remaining),
    );
    final next = <Medication>[...state];
    next[index] = old.copyWith(notificationIds: ids);
    state = next;
    await _persist();
  }

  Future<void> rescheduleAll(Iterable<DoseLog> logs) async {
    final now = DateTime.now();
    final next = <Medication>[];
    for (final medication in state) {
      final remaining = _stockResolver(medication, logs);
      final emptyUntilEmpty =
          medication.mode == MedicationMode.untilEmpty && remaining == 0;
      if (medication.isExpired(now) || emptyUntilEmpty) {
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
    DoseLogRepository repository, {
    required void Function(Failure failure) onFailure,
    this.onTaken,
  })  : _repository = repository,
        _onFailure = onFailure,
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
    final persisted = await _upsert(
      medId,
      scheduledAt,
      DoseStatus.taken,
      takenAt: DateTime.now(),
    );
    if (!persisted) return;
    await onTaken?.call(medId, state);
  }

  Future<void> markSkipped(String medId, DateTime scheduledAt) async {
    await _upsert(medId, scheduledAt, DoseStatus.skipped);
  }

  Future<void> markSnoozed(String medId, DateTime scheduledAt) async {
    await _upsert(medId, scheduledAt, DoseStatus.snoozed);
  }

  Future<bool> _upsert(
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
      return false;
    }
    return true;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
