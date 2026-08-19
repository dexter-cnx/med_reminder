import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/models/medication.dart';

void main() {
  test('days mode expires after configured day count', () {
    final med = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00'],
      mode: MedicationMode.days,
      daysCount: 3,
      createdAt: DateTime(2026, 8, 19),
    );
    expect(med.isActiveOn(DateTime(2026, 8, 21, 23, 59)), isTrue);
    expect(med.isActiveOn(DateTime(2026, 8, 22)), isFalse);
  });

  test('until empty mode becomes inactive at zero stock', () {
    final med = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00'],
      mode: MedicationMode.untilEmpty,
      totalAmount: 0,
      createdAt: DateTime(2026, 8, 19),
    );
    expect(med.isActiveOn(DateTime(2026, 8, 19)), isFalse);
  });

  test('old dose log format migrates as taken', () {
    final log = DoseLog.fromMap(<String, dynamic>{
      'medId': 'm1',
      'time': '2026-08-19T08:00:00.000',
    });
    expect(log.status, DoseStatus.taken);
    expect(log.scheduledAt.hour, 8);
  });
}
