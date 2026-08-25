import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/medication/application/build_today_doses.dart';
import 'package:med_reminder_offline/features/medication/application/reconcile_medication_reminders.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';
import 'package:med_reminder_offline/features/medication/domain/services/medication_services.dart';

void main() {
  test(
    'reconcile cancels old ids, skips PRN, and persists rebuilt ids',
    () async {
      final medications = <Medication>[
        _medication(id: 'scheduled', notificationIds: const <int>[11, 12]),
        _medication(
          id: 'prn',
          dosePlan: MedicationDosePlan.asNeeded,
          notificationIds: const <int>[21],
        ),
      ];
      final repository = _FakeMedicationRepository(medications);
      final scheduler = _FakeScheduler();
      final useCase = ReconcileMedicationReminders(
        medicationRepository: repository,
        doseLogRepository: const _FakeDoseLogRepository(),
        reminderScheduler: scheduler,
        stockResolver: legacyMedicationStockResolver,
        now: () => DateTime(2026, 8, 25, 12),
      );

      final result = await useCase();

      expect(result.isSuccess, isTrue);
      expect(scheduler.cancelCalls.first, <int>[11, 12, 21]);
      expect(scheduler.scheduledMedicationIds, <String>['scheduled']);
      expect(repository.lastReplaced, hasLength(2));
      expect(repository.lastReplaced![0].notificationIds, <int>[101]);
      expect(repository.lastReplaced![1].notificationIds, isEmpty);
    },
  );

  test('partial scheduling failure cleans newly created ids', () async {
    final repository = _FakeMedicationRepository(<Medication>[
      _medication(id: 'one', notificationIds: const <int>[1]),
      _medication(id: 'two', notificationIds: const <int>[2]),
    ]);
    final scheduler = _FakeScheduler(failOnMedicationId: 'two');
    final useCase = ReconcileMedicationReminders(
      medicationRepository: repository,
      doseLogRepository: const _FakeDoseLogRepository(),
      reminderScheduler: scheduler,
      stockResolver: legacyMedicationStockResolver,
      now: () => DateTime(2026, 8, 25, 12),
    );

    final result = await useCase();

    result.fold(
      onSuccess: (_) => fail('Expected reconciliation failure.'),
      onFailure: (failure) =>
          expect(failure.code, 'medication_reminder_reconcile_failed'),
    );
    expect(scheduler.cancelCalls, <List<int>>[
      <int>[1, 2],
      <int>[101],
    ]);
    expect(repository.lastReplaced, isNull);
  });
}

Medication _medication({
  required String id,
  MedicationDosePlan dosePlan = MedicationDosePlan.scheduled,
  List<int> notificationIds = const <int>[],
}) => Medication(
  id: id,
  name: id,
  times: const <String>['08:00'],
  createdAt: DateTime(2026, 8, 1),
  dosePlan: dosePlan,
  notificationIds: notificationIds,
);

final class _FakeMedicationRepository implements MedicationRepository {
  _FakeMedicationRepository(this.medications);

  final List<Medication> medications;
  List<Medication>? lastReplaced;

  @override
  Result<List<Medication>> readAll() => Success<List<Medication>>(medications);

  @override
  Future<Result<void>> replaceAll(List<Medication> medications) async {
    lastReplaced = medications;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> delete(String id) async => const Success<void>(null);
}

final class _FakeDoseLogRepository implements DoseLogRepository {
  const _FakeDoseLogRepository();

  @override
  Result<List<DoseLog>> readAll() => const Success<List<DoseLog>>(<DoseLog>[]);

  @override
  Future<Result<void>> replaceAll(List<DoseLog> logs) async =>
      const Success<void>(null);
}

final class _FakeScheduler implements MedicationReminderScheduler {
  _FakeScheduler({this.failOnMedicationId});

  final String? failOnMedicationId;
  final List<List<int>> cancelCalls = <List<int>>[];
  final List<String> scheduledMedicationIds = <String>[];
  var _nextId = 101;

  @override
  Future<List<int>> schedule(Medication medication) async {
    if (medication.id == failOnMedicationId) {
      throw StateError('schedule failed');
    }
    scheduledMedicationIds.add(medication.id);
    return <int>[_nextId++];
  }

  @override
  Future<void> cancelIds(Iterable<int> ids) async {
    cancelCalls.add(ids.toList(growable: false));
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
