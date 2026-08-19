import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/data/models/medication_record.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';

void main() {
  test('days mode exposes expiry date and expires after configured day count', () {
    final med = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00'],
      mode: MedicationMode.days,
      daysCount: 3,
      createdAt: DateTime(2026, 8, 19),
    );

    expect(med.expiryDate, DateTime(2026, 8, 21));
    expect(med.isExpired(DateTime(2026, 8, 21, 23, 59)), isFalse);
    expect(med.isExpired(DateTime(2026, 8, 22)), isTrue);
  });

  test('remaining is derived from taken dose logs only', () {
    final med = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00', '20:00'],
      initialAmount: 10,
      dosagePerTime: 2,
      mode: MedicationMode.untilEmpty,
      createdAt: DateTime(2026, 8, 19),
    );
    final logs = <DoseLog>[
      DoseLog(
        id: 'l1',
        medId: 'm1',
        scheduledAt: DateTime(2026, 8, 19, 8),
        takenAt: DateTime(2026, 8, 19, 8, 5),
        status: DoseStatus.taken,
      ),
      DoseLog(
        id: 'l2',
        medId: 'm1',
        scheduledAt: DateTime(2026, 8, 19, 20),
        status: DoseStatus.skipped,
      ),
    ];

    expect(med.remaining(logs), 8);
    expect(med.isEmpty(logs), isFalse);
  });

  test('legacy totalAmount maps into initialAmount', () {
    const record = MedicationRecord(<String, dynamic>{
      'id': 'm1',
      'name': 'Legacy',
      'times': <String>['08:00'],
      'createdAt': '2026-08-19T00:00:00.000',
      'totalAmount': 30,
    });

    expect(record.toEntity().initialAmount, 30);
  });

  test('old dose log record migrates as taken in the data layer', () {
    const record = DoseLogRecord(<String, dynamic>{
      'medId': 'm1',
      'time': '2026-08-19T08:00:00.000',
    });
    final log = record.toEntity();
    expect(log.status, DoseStatus.taken);
    expect(log.scheduledAt.hour, 8);
  });
}
