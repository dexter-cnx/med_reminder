import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/application/reminder_scheduling_window.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';

void main() {
  const window = ReminderSchedulingWindow(maxCalendarDays: 14);

  test('keeps non-finite medication unchanged', () {
    final medication = Medication(
      id: 'forever',
      name: 'Daily',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 1),
    );

    expect(window.project(medication, DateTime(2026, 8, 25)), same(medication));
  });

  test('caps a new finite course to fourteen calendar days', () {
    final medication = Medication(
      id: 'course',
      name: 'Course',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 25, 7),
      mode: MedicationMode.days,
      daysCount: 30,
    );

    final projected = window.project(medication, DateTime(2026, 8, 25, 12));

    expect(projected, isNotNull);
    expect(projected!.createdAt, DateTime(2026, 8, 25));
    expect(projected.daysCount, 14);
  });

  test('advances an in-progress finite course to today', () {
    final medication = Medication(
      id: 'course',
      name: 'Course',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 20),
      mode: MedicationMode.days,
      daysCount: 30,
    );

    final projected = window.project(medication, DateTime(2026, 8, 25, 12));

    expect(projected, isNotNull);
    expect(projected!.createdAt, DateTime(2026, 8, 25));
    expect(projected.daysCount, 14);
  });

  test('uses only the remaining course when fewer than window days remain', () {
    final medication = Medication(
      id: 'course',
      name: 'Course',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 20),
      mode: MedicationMode.days,
      daysCount: 10,
    );

    final projected = window.project(medication, DateTime(2026, 8, 25, 12));

    expect(projected, isNotNull);
    expect(projected!.createdAt, DateTime(2026, 8, 25));
    expect(projected.daysCount, 5);
  });

  test('returns null when the finite course has ended', () {
    final medication = Medication(
      id: 'course',
      name: 'Course',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 1),
      mode: MedicationMode.days,
      daysCount: 7,
    );

    expect(window.project(medication, DateTime(2026, 8, 25)), isNull);
  });

  test('preserves a future finite course start while bounding its length', () {
    final medication = Medication(
      id: 'future',
      name: 'Future course',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 28),
      mode: MedicationMode.days,
      daysCount: 20,
    );

    final projected = window.project(medication, DateTime(2026, 8, 25));

    expect(projected, isNotNull);
    expect(projected!.createdAt, DateTime(2026, 8, 28));
    expect(projected.daysCount, 14);
  });
}
