import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/medication/application/build_today_doses.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';
import 'package:med_reminder_offline/features/medication/domain/services/medication_services.dart';
import 'package:med_reminder_offline/features/medication/presentation/viewmodels/medication_view_model.dart';

void main() {
  test('today doses use injected refill-aware remaining stock', () {
    final medication = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00'],
      initialAmount: 2,
      dosagePerTime: 1,
      mode: MedicationMode.untilEmpty,
      createdAt: DateTime(2026, 8, 22),
    );
    final logs = <DoseLog>[
      DoseLog(
        id: 'l1',
        medId: 'm1',
        scheduledAt: DateTime(2026, 8, 22, 7),
        status: DoseStatus.taken,
      ),
      DoseLog(
        id: 'l2',
        medId: 'm1',
        scheduledAt: DateTime(2026, 8, 22, 7, 30),
        status: DoseStatus.taken,
      ),
    ];

    expect(medication.remaining(logs), 0);

    final doses = buildTodayDoses(
      medications: <Medication>[medication],
      logs: logs,
      stockResolver: (_, __) => 5,
      now: DateTime(2026, 8, 22, 12),
    );

    expect(doses, hasLength(1));
    expect(doses.single.remaining, 5);
  });

  test('until-empty reconciliation honors refill-aware stock', () async {
    final medication = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00'],
      initialAmount: 1,
      dosagePerTime: 1,
      mode: MedicationMode.untilEmpty,
      notificationIds: const <int>[42],
      createdAt: DateTime(2026, 8, 22),
    );
    final repository = _MemoryMedicationRepository(<Medication>[medication]);
    final scheduler = _RecordingReminderScheduler();
    final viewModel = MedicationViewModel(
      repository: repository,
      reminderScheduler: scheduler,
      photoStore: _FakePhotoStore(),
      stockResolver: (_, __) => 10,
      onFailure: (_) {},
    );
    final logs = <DoseLog>[
      DoseLog(
        id: 'l1',
        medId: 'm1',
        scheduledAt: DateTime(2026, 8, 22, 8),
        status: DoseStatus.taken,
      ),
    ];

    expect(medication.remaining(logs), 0);
    await viewModel.reconcileFromLogs('m1', logs);

    expect(scheduler.cancelledIds, isEmpty);
    expect(viewModel.state.single.notificationIds, <int>[42]);
  });

  test('low-stock warning uses refill-aware balance crossing', () async {
    final medication = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00'],
      initialAmount: 30,
      dosagePerTime: 2,
      lowThreshold: 5,
      createdAt: DateTime(2026, 8, 22),
    );
    final scheduler = _RecordingReminderScheduler();
    final viewModel = MedicationViewModel(
      repository: _MemoryMedicationRepository(<Medication>[medication]),
      reminderScheduler: scheduler,
      photoStore: _FakePhotoStore(),
      stockResolver: (_, __) => 5,
      onFailure: (_) {},
    );

    await viewModel.reconcileFromLogs('m1', const <DoseLog>[]);

    expect(scheduler.lowStockCalls, <String>['Test:5']);
  });
}

class _MemoryMedicationRepository implements MedicationRepository {
  _MemoryMedicationRepository(this.values);

  List<Medication> values;

  @override
  Result<List<Medication>> readAll() =>
      Success<List<Medication>>(List<Medication>.unmodifiable(values));

  @override
  Future<Result<void>> replaceAll(List<Medication> medications) async {
    values = List<Medication>.from(medications);
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    values = values.where((item) => item.id != id).toList(growable: false);
    return const Success<void>(null);
  }
}

class _RecordingReminderScheduler implements MedicationReminderScheduler {
  final List<int> cancelledIds = <int>[];
  final List<String> lowStockCalls = <String>[];

  @override
  Future<void> cancelIds(Iterable<int> ids) async {
    cancelledIds.addAll(ids);
  }

  @override
  Future<void> cancelSnooze(String medId, DateTime scheduledDose) async {}

  @override
  Future<List<int>> schedule(Medication medication) async =>
      medication.notificationIds;

  @override
  Future<void> scheduleSnooze({
    required String medId,
    required String medName,
    required int dosage,
    required DateTime scheduledDose,
  }) async {}

  @override
  Future<void> showLowStock(String name, int remaining) async {
    lowStockCalls.add('$name:$remaining');
  }
}

class _FakePhotoStore implements MedicationPhotoStore {
  @override
  Future<void> delete(String? path) async {}

  @override
  Future<int> pruneOrphaned(Iterable<String> referencedPaths) async => 0;
}
