import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';
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

void main() {
  test('Riverpod can inject a non-Hive medication repository', () {
    final expected = Medication(
      id: 'med-1',
      name: 'Vitamin C',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 19),
    );
    final repository = _MemoryMedicationRepository(<Medication>[expected]);
    final container = ProviderContainer(
      overrides: <Override>[
        medicationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(medsProvider), <Medication>[expected]);
  });
}
