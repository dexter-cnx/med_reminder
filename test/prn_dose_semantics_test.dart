import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/application/build_today_doses.dart';
import 'package:med_reminder_offline/features/medication/data/models/medication_record.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';

void main() {
  test('PRN dose plan is independent from medication duration mode', () {
    final medication = Medication(
      id: 'prn-1',
      name: 'PRN medication',
      times: const <String>[],
      dosePlan: MedicationDosePlan.asNeeded,
      mode: MedicationMode.days,
      daysCount: 7,
      createdAt: DateTime(2026, 8, 22),
    );

    expect(medication.isAsNeeded, isTrue);
    expect(medication.mode, MedicationMode.days);
    expect(medication.expiryDate, DateTime(2026, 8, 28));
  });

  test('PRN medication does not create scheduled Today doses', () {
    final medication = Medication(
      id: 'prn-1',
      name: 'PRN medication',
      times: const <String>['08:00', '20:00'],
      dosePlan: MedicationDosePlan.asNeeded,
      createdAt: DateTime(2026, 8, 22),
    );

    final doses = buildTodayDoses(
      medications: <Medication>[medication],
      logs: const <DoseLog>[],
      now: DateTime(2026, 8, 22, 12),
    );

    expect(doses, isEmpty);
  });

  test('scheduled medication behavior remains unchanged', () {
    final medication = Medication(
      id: 'scheduled-1',
      name: 'Scheduled medication',
      times: const <String>['08:00', '20:00'],
      createdAt: DateTime(2026, 8, 22),
    );

    final doses = buildTodayDoses(
      medications: <Medication>[medication],
      logs: const <DoseLog>[],
      now: DateTime(2026, 8, 22, 12),
    );

    expect(doses, hasLength(2));
  });

  test('PRN dose plan round-trips through medication persistence', () {
    final medication = Medication(
      id: 'prn-1',
      name: 'PRN medication',
      times: const <String>[],
      dosePlan: MedicationDosePlan.asNeeded,
      createdAt: DateTime(2026, 8, 22),
    );

    final restored = MedicationRecord.fromEntity(medication).toEntity();

    expect(restored.dosePlan, MedicationDosePlan.asNeeded);
    expect(restored.isAsNeeded, isTrue);
  });

  test('legacy medication records default to scheduled dose plan', () {
    const record = MedicationRecord(<String, dynamic>{
      'id': 'legacy-1',
      'name': 'Legacy medication',
      'times': <String>['08:00'],
      'createdAt': '2026-08-22T00:00:00.000',
    });

    expect(record.toEntity().dosePlan, MedicationDosePlan.scheduled);
  });

  test('legacy PRN spelling is accepted by persistence adapter', () {
    const record = MedicationRecord(<String, dynamic>{
      'id': 'prn-legacy',
      'name': 'PRN legacy medication',
      'times': <String>[],
      'dosePlan': 'prn',
      'createdAt': '2026-08-22T00:00:00.000',
    });

    expect(record.toEntity().dosePlan, MedicationDosePlan.asNeeded);
  });
}
