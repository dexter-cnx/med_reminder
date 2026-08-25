import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/rebuild_restored_reminders.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';
import 'package:med_reminder_offline/features/medication/domain/services/medication_services.dart';

void main() {
  test('rebuild schedules active medication and persists generated ids',
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

    final result = await useCase();

    expect(result.isSuccess, isTrue);
    expect(scheduler.scheduledIds, <String>['med-1']);
    expect(medications.replaced.single.notificationIds, <int>[10, 11]);
  });

  test('expired medication is persisted without notification ids', () async {
    final medication = _medication(
      mode: MedicationMode.days,
      daysCount: 1,
      createdAt: DateTime(2026, 8, 20),
      notificationIds: const <int>[77],
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

    final result = await useCase();

    expect(result.isSuccess, isTrue);
    expect(scheduler.cancelledIds, <int>[77]);
    expect(medications.replaced.single.notificationIds, isEmpty);
  });

  test('scheduler failure leaves restored repository data untouched', () async {
    final medication = _medication(notificationIds: const <int>[]);
    final medications = _FakeMedicationRepository(<Medication>[medication]);
    final scheduler = _FakeReminderScheduler(throwOnSchedule: true);
    final useCase = RebuildRestoredReminders(
      medicationRepository: medications,
      doseLogRepository: _FakeDoseLogRepository(),
      reminderScheduler: scheduler,
      stockResolver: (medication, logs) => medication.initialAmount,
      now: () => DateTime(2026, 8, 25),
    );

    final result = await useCase();

    result.fold(
      onSuccess: (_) => fail('Expected reminder rebuild failure.'),
      onFailure: (failure) =>
          expect(failure.code, 'backup_restore_reminder_rebuild_failed'),
    );
    expect(medications.replaceCalls, 0);
    expect(medications.current.single.id, 'med-1');
  });
}

Medication _medication({
  MedicationMode mode = MedicationMode.forever,
  int? daysCount,
  DateTime? createdAt,
  List<int> notificationIds = const <int>[],
}) =>
    Medication(
      id: 'med-1',
      name: 'Medicine',
      times: const <String>['08:00'],
      createdAt: createdAt ?? DateTime(2026, 8, 25),
      initialAmount: 10,
      mode: mode,
      daysCount: daysCount,
      notificationIds: notificationIds,
    );

final class _FakeMedicationRepository implements MedicationRepository {
  _FakeMedicationRepository(this.current);

  List<Medication> current;
  List<Medication> replaced = const <Medication>[];
  int replaceCalls = 0;

  @override
  Result<List<Medication>> readAll() => Success<List<Medication>>(current);

  @override
  Future<Result<void>> replaceAll(List<Medication> medications) async {
    replaceCalls++;
    replaced = medications;
    current = medications;
    return const Success<void>(null);
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
    this.throwOnSchedule = false,
  });

  final List<int> scheduleIds;
  final bool throwOnSchedule;
  final List<String> scheduledIds = <String>[];
  final List<int> cancelledIds = <int>[];

  @override
  Future<List<int>> schedule(Medication medication) async {
    if (throwOnSchedule) throw StateError('schedule failed');
    scheduledIds.add(medication.id);
    return scheduleIds;
  }

  @override
  Future<void> cancelIds(Iterable<int> ids) async {
    cancelledIds.addAll(ids);
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
