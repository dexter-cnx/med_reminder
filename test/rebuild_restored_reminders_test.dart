import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/rebuild_restored_reminders.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';
import 'package:med_reminder_offline/features/medication/domain/services/medication_services.dart';

void main() {
  test('rebuild cancels pre-restore ids, schedules active medication, and persists generated ids',
      () async {
    final medication = _medication(notificationIds: const <int>[]);
    final medications = _FakeMedicationRepository(<Medication>[medication]);
    final scheduler = _FakeReminderScheduler(scheduleIds: const <int>[10, 11]);
    final useCase = RebuildRestoredReminders(
      medicationRepository: medications,
      doseLogRepository: _FakeDoseLogRepository(),
      reminderScheduler: scheduler,
      stockResolver: (medication, logs) => medication.initialAmount,
      now: () => DateTime(2026, 8, 25),
    );

    final result = await useCase(
      previousNotificationIds: const <int>[70, 71],
    );

    expect(result.isSuccess, isTrue);
    expect(scheduler.cancelledBatches.first, <int>[70, 71]);
    expect(scheduler.scheduledIds, <String>['med-1']);
    expect(medications.replaced.single.notificationIds, <int>[10, 11]);
  });

  test('expired medication is persisted without notification ids', () async {
    final medication = _medication(
      mode: MedicationMode.days,
      daysCount: 1,
      createdAt: DateTime(2026, 8, 20),
      notificationIds: const <int>[],
    );
    final medications = _FakeMedicationRepository(<Medication>[medication]);
    final scheduler = _FakeReminderScheduler();
    final useCase = RebuildRestoredReminders(
      medicationRepository: medications,
      doseLogRepository: _FakeDoseLogRepository(),
      reminderScheduler: scheduler,
      stockResolver: (medication, logs) => medication.initialAmount,
      now: () => DateTime(2026, 8, 25),
    );

    final result = await useCase(
      previousNotificationIds: const <int>[77],
    );

    expect(result.isSuccess, isTrue);
    expect(scheduler.cancelledBatches.first, <int>[77]);
    expect(medications.replaced.single.notificationIds, isEmpty);
  });

  test('later scheduler failure cancels ids created earlier in rebuild', () async {
    final medications = _FakeMedicationRepository(<Medication>[
      _medication(id: 'med-1'),
      _medication(id: 'med-2'),
    ]);
    final scheduler = _FakeReminderScheduler(
      scheduleIds: const <int>[10],
      throwOnScheduleCall: 2,
    );
    final useCase = RebuildRestoredReminders(
      medicationRepository: medications,
      doseLogRepository: _FakeDoseLogRepository(),
      reminderScheduler: scheduler,
      stockResolver: (medication, logs) => medication.initialAmount,
      now: () => DateTime(2026, 8, 25),
    );

    final result = await useCase(
      previousNotificationIds: const <int>[90],
    );

    result.fold(
      onSuccess: (_) => fail('Expected reminder rebuild failure.'),
      onFailure: (failure) =>
          expect(failure.code, 'backup_restore_reminder_rebuild_failed'),
    );
    expect(medications.replaceCalls, 0);
    expect(scheduler.cancelledBatches, <List<int>>[
      <int>[90],
      <int>[10],
    ]);
  });

  test('persist failure cancels all newly created reminder ids', () async {
    final medications = _FakeMedicationRepository(
      <Medication>[_medication()],
      replaceResult: const Failed<void>(
        Failure(code: 'write_failed', message: 'write failed'),
      ),
    );
    final scheduler = _FakeReminderScheduler(scheduleIds: const <int>[10, 11]);
    final useCase = RebuildRestoredReminders(
      medicationRepository: medications,
      doseLogRepository: _FakeDoseLogRepository(),
      reminderScheduler: scheduler,
      stockResolver: (medication, logs) => medication.initialAmount,
      now: () => DateTime(2026, 8, 25),
    );

    final result = await useCase();

    result.fold(
      onSuccess: (_) => fail('Expected persist failure.'),
      onFailure: (failure) => expect(
        failure.code,
        'backup_restore_reminder_state_persist_failed',
      ),
    );
    expect(scheduler.cancelledBatches.last, <int>[10, 11]);
  });
}

Medication _medication({
  String id = 'med-1',
  MedicationMode mode = MedicationMode.forever,
  int? daysCount,
  DateTime? createdAt,
  List<int> notificationIds = const <int>[],
}) =>
    Medication(
      id: id,
      name: 'Medicine',
      times: const <String>['08:00'],
      createdAt: createdAt ?? DateTime(2026, 8, 25),
      initialAmount: 10,
      mode: mode,
      daysCount: daysCount,
      notificationIds: notificationIds,
    );

final class _FakeMedicationRepository implements MedicationRepository {
  _FakeMedicationRepository(
    this.current, {
    this.replaceResult = const Success<void>(null),
  });

  List<Medication> current;
  final Result<void> replaceResult;
  List<Medication> replaced = const <Medication>[];
  int replaceCalls = 0;

  @override
  Result<List<Medication>> readAll() => Success<List<Medication>>(current);

  @override
  Future<Result<void>> replaceAll(List<Medication> medications) async {
    replaceCalls++;
    replaced = medications;
    if (replaceResult case Success<void>()) current = medications;
    return replaceResult;
  }

  @override
  Future<Result<void>> delete(String id) async => const Success<void>(null);
}

final class _FakeDoseLogRepository implements DoseLogRepository {
  @override
  Result<List<DoseLog>> readAll() => const Success<List<DoseLog>>(<DoseLog>[]);

  @override
  Future<Result<void>> replaceAll(List<DoseLog> logs) async =>
      const Success<void>(null);
}

final class _FakeReminderScheduler implements MedicationReminderScheduler {
  _FakeReminderScheduler({
    this.scheduleIds = const <int>[1],
    this.throwOnScheduleCall,
  });

  final List<int> scheduleIds;
  final int? throwOnScheduleCall;
  final List<String> scheduledIds = <String>[];
  final List<List<int>> cancelledBatches = <List<int>>[];
  int _scheduleCalls = 0;

  @override
  Future<List<int>> schedule(Medication medication) async {
    _scheduleCalls++;
    if (_scheduleCalls == throwOnScheduleCall) {
      throw StateError('schedule failed');
    }
    scheduledIds.add(medication.id);
    return scheduleIds;
  }

  @override
  Future<void> cancelIds(Iterable<int> ids) async {
    cancelledBatches.add(ids.toList(growable: false));
  }

  @override
  Future<void> showLowStock(String name, int remaining) async {}

  @override
  Future<void> scheduleSnooze({
    required String medId,
    required String medName,
    required int dosage,
    required DateTime scheduledDose,
  }) async {}

  @override
  Future<void> cancelSnooze(String medId, DateTime scheduledDose) async {}
}
