import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/medication.dart';
import '../services/notification_service.dart';
import '../services/photo_service.dart';

final medsProvider = StateNotifierProvider<MedsNotifier, List<Medication>>(
  (ref) => MedsNotifier(),
);
final logsProvider = StateNotifierProvider<LogsNotifier, List<DoseLog>>(
  (ref) => LogsNotifier(),
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

class MedsNotifier extends StateNotifier<List<Medication>> {
  MedsNotifier() : super(const <Medication>[]) {
    _load();
  }

  Box<dynamic> get _box => Hive.box('meds');

  void _load() {
    state = _box.values
        .map((value) => Medication.fromMap(Map<dynamic, dynamic>.from(value as Map)))
        .toList();
  }

  Future<void> _save() async {
    await _box.clear();
    for (final med in state) {
      await _box.add(med.toMap());
    }
  }

  Future<void> add(Medication med) async {
    final ids = await NotificationService.scheduleForMed(med);
    state = <Medication>[...state, med.copyWith(notificationIds: ids)];
    await _save();
  }

  Future<void> updateStock(String id, int requestedAmount) async {
    final index = state.indexWhere((med) => med.id == id);
    if (index < 0) return;
    final old = state[index];
    final newAmount = requestedAmount < 0 ? 0 : requestedAmount;
    var updated = old.copyWith(totalAmount: newAmount);

    if (old.mode == MedicationMode.untilEmpty && newAmount == 0) {
      await NotificationService.cancelIds(old.notificationIds);
      updated = updated.copyWith(notificationIds: const <int>[]);
    }

    final threshold = old.lowThreshold;
    if (threshold != null && old.totalAmount != null && old.totalAmount! > threshold && newAmount <= threshold) {
      await NotificationService.showLowStock(old.name, newAmount);
    }

    final next = <Medication>[...state];
    next[index] = updated;
    state = next;
    await _save();
  }

  Future<void> remove(String id) async {
    final med = state.where((item) => item.id == id).firstOrNull;
    if (med == null) return;
    await NotificationService.cancelIds(med.notificationIds);
    await PhotoService.deletePhoto(med.imagePath);
    state = state.where((item) => item.id != id).toList();
    await _save();
  }
}

class LogsNotifier extends StateNotifier<List<DoseLog>> {
  LogsNotifier() : super(const <DoseLog>[]) {
    _load();
  }

  Box<dynamic> get _box => Hive.box('logs');

  void _load() {
    state = _box.values
        .map((value) => DoseLog.fromMap(Map<dynamic, dynamic>.from(value as Map)))
        .toList();
  }

  Future<void> _save() async {
    await _box.clear();
    for (final log in state) {
      await _box.add(log.toMap());
    }
  }

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
    await _save();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
