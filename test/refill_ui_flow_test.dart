import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';
import 'package:med_reminder_offline/features/medication/domain/services/medication_services.dart';
import 'package:med_reminder_offline/features/medication/presentation/viewmodels/medication_view_model.dart';
import 'package:med_reminder_offline/features/refill/domain/entities/refill_event.dart';
import 'package:med_reminder_offline/features/refill/domain/repositories/refill_repository.dart';
import 'package:med_reminder_offline/features/refill/presentation/providers/refill_providers.dart';

void main() {
  test('refill view model appends and keeps chronological state', () async {
    final older = RefillEvent(
      id: 'older',
      medicationId: 'med-1',
      quantity: 10,
      createdAt: DateTime(2026, 8, 20),
    );
    final repository = _MemoryRefillRepository(<RefillEvent>[older]);
    Failure? failure;
    final viewModel = RefillViewModel(
      repository,
      onFailure: (value) => failure = value,
    );
    final newer = RefillEvent(
      id: 'newer',
      medicationId: 'med-1',
      quantity: 20,
      createdAt: DateTime(2026, 8, 22),
      note: 'pharmacy',
    );

    expect(await viewModel.append(newer), isTrue);
    expect(
      viewModel.state.map((event) => event.id),
      <String>['older', 'newer'],
    );
    expect(repository.values.length, 2);
    expect(failure, isNull);
  });

  test('refill append failure leaves view model state unchanged', () async {
    final repository = _FailingRefillRepository();
    Failure? failure;
    final viewModel = RefillViewModel(
      repository,
      onFailure: (value) => failure = value,
    );
    final event = RefillEvent(
      id: 'refill-1',
      medicationId: 'med-1',
      quantity: 10,
      createdAt: DateTime(2026, 8, 22),
    );

    expect(await viewModel.append(event), isFalse);
    expect(viewModel.state, isEmpty);
    expect(failure?.code, 'refill_write_failed');
  });

  test(
    'refill can restore reminders for zero-initial until-empty stock',
    () async {
      final medication = Medication(
        id: 'med-1',
        name: 'Vitamin C',
        times: const <String>['08:00'],
        createdAt: DateTime(2026, 8, 20),
        initialAmount: 0,
        mode: MedicationMode.untilEmpty,
        notificationIds: const <int>[],
      );
      final repository = _MemoryMedicationRepository(<Medication>[medication]);
      final scheduler = _TrackingReminderScheduler();
      final viewModel = MedicationViewModel(
        repository: repository,
        reminderScheduler: scheduler,
        lowStockAlertStateStore: _MemoryLowStockAlertStateStore(),
        photoStore: _FakePhotoStore(),
        stockResolver: (_, __) => 12,
        onFailure: (_) {},
      );

      await viewModel.refreshAfterRefill('med-1', const <DoseLog>[]);

      expect(scheduler.scheduleCalls, 1);
      expect(scheduler.lastScheduledInitialAmount, 12);
      expect(viewModel.state.single.initialAmount, 0);
      expect(viewModel.state.single.notificationIds, <int>[101]);
      expect(repository.values.single.initialAmount, 0);
      expect(repository.values.single.notificationIds, <int>[101]);
    },
  );
}

class _MemoryRefillRepository implements RefillRepository {
  _MemoryRefillRepository(this.values);

  final List<RefillEvent> values;

  @override
  Result<List<RefillEvent>> readAll() =>
      Success<List<RefillEvent>>(List<RefillEvent>.unmodifiable(values));

  @override
  Future<Result<void>> append(RefillEvent event) async {
    values.removeWhere((item) => item.id == event.id);
    values.add(event);
    return const Success<void>(null);
  }
}

class _FailingRefillRepository implements RefillRepository {
  @override
  Result<List<RefillEvent>> readAll() =>
      const Success<List<RefillEvent>>(<RefillEvent>[]);

  @override
  Future<Result<void>> append(RefillEvent event) async => const Failed<void>(
        Failure(code: 'refill_write_failed', message: 'boom'),
      );
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

class _TrackingReminderScheduler implements MedicationReminderScheduler {
  var scheduleCalls = 0;
  int? lastScheduledInitialAmount;

  @override
  Future<List<int>> schedule(Medication medication) async {
    scheduleCalls++;
    lastScheduledInitialAmount = medication.initialAmount;
    return const <int>[101];
  }

  @override
  Future<void> cancelIds(Iterable<int> ids) async {}

  @override
  Future<void> cancelSnooze(String medId, DateTime scheduledDose) async {}

  @override
  Future<void> scheduleSnooze({
    required String medId,
    required String medName,
    required int dosage,
    required DateTime scheduledDose,
  }) async {}

  @override
  Future<void> showLowStock(String name, int remaining) async {}
}

class _MemoryLowStockAlertStateStore implements LowStockAlertStateStore {
  final Map<String, int> _thresholds = <String, int>{};

  @override
  int? alertedThreshold(String medicationId) => _thresholds[medicationId];

  @override
  Future<void> markAlerted(String medicationId, int threshold) async {
    _thresholds[medicationId] = threshold;
  }

  @override
  Future<void> clear(String medicationId) async {
    _thresholds.remove(medicationId);
  }
}

class _FakePhotoStore implements MedicationPhotoStore {
  @override
  Future<void> delete(String? path) async {}

  @override
  Future<int> pruneOrphaned(Iterable<String> referencedPaths) async => 0;
}
