import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/medication.dart';
import '../../domain/repositories/medication_repository.dart';
import '../../domain/services/medication_services.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => throw UnimplementedError('MedicationRepository must be provided by app DI.'),
);

final doseLogRepositoryProvider = Provider<DoseLogRepository>(
  (ref) => throw UnimplementedError('DoseLogRepository must be provided by app DI.'),
);

final medicationReminderSchedulerProvider = Provider<MedicationReminderScheduler>(
  (ref) => throw UnimplementedError('MedicationReminderScheduler must be provided by app DI.'),
);

final medicationPhotoStoreProvider = Provider<MedicationPhotoStore>(
  (ref) => throw UnimplementedError('MedicationPhotoStore must be provided by app DI.'),
);

final medsProvider = StateNotifierProvider<MedicationViewModel, List<Medication>>(
  (ref) => MedicationViewModel(
    repository: ref.watch(medicationRepositoryProvider),
    reminderScheduler: ref.watch(medicationReminderSchedulerProvider),
    photoStore: ref.watch(medicationPhotoStoreProvider),
  ),
);

final logsProvider = StateNotifierProvider<DoseLogViewModel, List<DoseLog>>(
  (ref) => DoseLogViewModel(ref.watch(doseLogRepositoryProvider)),
);

final todayDosesProvider = Provider<List<ScheduledDose>>((ref) {
  final meds = ref.watch(medsProvider);
  final logs = ref.watch(logsProvider);
  final now = DateTime.now();
  final doses = <ScheduledDose>[];

  for (final med in meds) {
    if (!med.isActiveOn(now)) continue;
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
      doses.add(ScheduledDose(medication: med, scheduledAt: scheduled, log: existing));
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

class MedicationViewModel extends StateNotifier<List<Medication>> {
  MedicationViewModel({
    required MedicationRepository repository,
    required MedicationReminderScheduler reminderScheduler,
    required MedicationPhotoStore photoStore,
  })  : _repository = repository,
        _reminderScheduler = reminderScheduler,
        _photoStore = photoStore,
        super(repository.readAll());

  final MedicationRepository _repository;
  final MedicationReminderScheduler _reminderScheduler;
  final MedicationPhotoStore _photoStore;

  Future<void> _persist() => _repository.replaceAll(state);

  Future<void> add(Medication medication) async {
    final ids = await _reminderScheduler.schedule(medication);
    state = <Medication>[
      ...state,
      medication.copyWith(notificationIds: ids),
    ];
    await _persist();
  }

  Future<void> updateStock(String id, int requestedAmount) async {
    final index = state.indexWhere((med) => med.id == id);
    if (index < 0) return;

    final old = state[index];
    final newAmount = requestedAmount < 0 ? 0 : requestedAmount;
    var updated = old.copyWith(totalAmount: newAmount);

    if (old.mode == MedicationMode.untilEmpty && newAmount == 0) {
      await _reminderScheduler.cancelIds(old.notificationIds);
      updated = updated.copyWith(notificationIds: const <int>[]);
    }

    final threshold = old.lowThreshold;
    if (threshold != null &&
        old.totalAmount != null &&
        old.totalAmount! > threshold &&
        newAmount <= threshold) {
      await _reminderScheduler.showLowStock(old.name, newAmount);
    }

    final next = <Medication>[...state];
    next[index] = updated;
    state = next;
    await _persist();
  }

  Future<void> remove(String id) async {
    final med = state.where((item) => item.id == id).firstOrNull;
    if (med == null) return;

    await _reminderScheduler.cancelIds(med.notificationIds);
    await _photoStore.delete(med.imagePath);
    state = state.where((item) => item.id != id).toList(growable: false);
    await _persist();
  }
}

class DoseLogViewModel extends StateNotifier<List<DoseLog>> {
  DoseLogViewModel(this._repository) : super(_repository.readAll());

  final DoseLogRepository _repository;

  Future<void> _persist() => _repository.replaceAll(state);

  Future<void> markTaken(String medId, DateTime scheduledAt) =>
      _upsert(medId, scheduledAt, DoseStatus.taken, takenAt: DateTime.now());

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
    state = <DoseLog>[
      ...state.where((log) => !_sameDose(log, medId, scheduledAt)),
      replacement,
    ];
    await _persist();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
