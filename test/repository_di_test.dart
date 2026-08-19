import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';
import 'package:med_reminder_offline/features/medication/domain/services/medication_services.dart';
import 'package:med_reminder_offline/features/medication/presentation/viewmodels/medication_view_model.dart';

class _MemoryMedicationRepository implements MedicationRepository {
  _MemoryMedicationRepository(this.values);

  List<Medication> values;

  @override
  List<Medication> readAll() => List<Medication>.unmodifiable(values);

  @override
  Future<void> replaceAll(List<Medication> medications) async {
    values = List<Medication>.from(medications);
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
}
