import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';
import 'package:med_reminder_offline/features/medication/domain/services/medication_services.dart';
import 'package:med_reminder_offline/features/medication/presentation/viewmodels/medication_view_model.dart';

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

class _FakeReminderScheduler implements MedicationReminderScheduler {
  @override
  Future<void> cancelIds(Iterable<int> ids) async {}

  @override
  Future<void> cancelSnooze(String medId, DateTime scheduledDose) async {}

  @override
  Future<List<int>> schedule(Medication medication) async => const <int>[];

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

class _FakePhotoStore implements MedicationPhotoStore {
  @override
  Future<void> delete(String? path) async {}

  @override
  Future<int> pruneOrphaned(Iterable<String> referencedPaths) async => 0;
}

void main() {
  test('Riverpod can inject non-Hive infrastructure into the ViewModel', () {
    final expected = Medication(
      id: 'med-1',
      name: 'Vitamin C',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 19),
    );
    final repository = _MemoryMedicationRepository(<Medication>[expected]);
    final container = ProviderContainer(
      overrides: [
        medicationRepositoryProvider.overrideWithValue(repository),
        medicationReminderSchedulerProvider.overrideWithValue(_FakeReminderScheduler()),
        medicationPhotoStoreProvider.overrideWithValue(_FakePhotoStore()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(medsProvider), <Medication>[expected]);
  });

  test('repository failure is exposed through Riverpod presentation state', () {
    final repository = _FailingMedicationRepository();
    final container = ProviderContainer(
      overrides: [
        medicationRepositoryProvider.overrideWithValue(repository),
        medicationReminderSchedulerProvider.overrideWithValue(_FakeReminderScheduler()),
        medicationPhotoStoreProvider.overrideWithValue(_FakePhotoStore()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(medsProvider), isEmpty);
    expect(container.read(repositoryFailureProvider)?.code, 'test_read_failed');
  });
}

class _FailingMedicationRepository implements MedicationRepository {
  @override
  Result<List<Medication>> readAll() => const Failed<List<Medication>>(
        Failure(code: 'test_read_failed', message: 'boom'),
      );

  @override
  Future<Result<void>> replaceAll(List<Medication> medications) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> delete(String id) async => const Success<void>(null);
}
