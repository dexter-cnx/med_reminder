import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';
import 'package:med_reminder_offline/features/medication/domain/services/medication_services.dart';
import 'package:med_reminder_offline/features/medication/presentation/viewmodels/medication_view_model.dart';

class _MedicationRepository implements MedicationRepository {
  _MedicationRepository(this.values);
  List<Medication> values;

  @override
  List<Medication> readAll() => List<Medication>.unmodifiable(values);

  @override
  Future<void> replaceAll(List<Medication> medications) async {
    values = List<Medication>.from(medications);
  }
}

class _LogRepository implements DoseLogRepository {
  _LogRepository(this.values);
  List<DoseLog> values;

  @override
  List<DoseLog> readAll() => List<DoseLog>.unmodifiable(values);

  @override
  Future<void> replaceAll(List<DoseLog> logs) async {
    values = List<DoseLog>.from(logs);
  }
}

class _Scheduler implements MedicationReminderScheduler {
  @override
  Future<List<int>> schedule(Medication medication) async => const <int>[];
  @override
  Future<void> cancelIds(Iterable<int> ids) async {}
  @override
  Future<void> cancelSnooze(String medId, DateTime scheduledDose) async {}
  @override
  Future<void> scheduleSnooze({required String medId, required String medName, required int dosage, required DateTime scheduledDose}) async {}
  @override
  Future<void> showLowStock(String name, int remaining) async {}
}

class _PhotoStore implements MedicationPhotoStore {
  @override
  Future<void> delete(String? path) async {}
}

void main() {
  test('08:00 taken does not mark 20:00 as taken', () {
    final now = DateTime.now();
    final medication = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00', '20:00'],
      initialAmount: 10,
      createdAt: DateTime(now.year, now.month, now.day),
    );
    final takenMorning = DoseLog(
      id: 'l1',
      medId: 'm1',
      scheduledAt: DateTime(now.year, now.month, now.day, 8),
      takenAt: DateTime(now.year, now.month, now.day, 8, 5),
      status: DoseStatus.taken,
    );

    final container = ProviderContainer(
      overrides: [
        medicationRepositoryProvider.overrideWithValue(_MedicationRepository(<Medication>[medication])),
        doseLogRepositoryProvider.overrideWithValue(_LogRepository(<DoseLog>[takenMorning])),
        medicationReminderSchedulerProvider.overrideWithValue(_Scheduler()),
        medicationPhotoStoreProvider.overrideWithValue(_PhotoStore()),
      ],
    );
    addTearDown(container.dispose);

    final doses = container.read(todayDosesProvider);
    final morning = doses.singleWhere((dose) => dose.scheduledAt.hour == 8);
    final evening = doses.singleWhere((dose) => dose.scheduledAt.hour == 20);

    expect(morning.isTaken, isTrue);
    expect(evening.isTaken, isFalse);
    expect(evening.log, isNull);
  });
}
