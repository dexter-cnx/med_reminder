import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/application/build_today_doses.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/refill/application/calculate_remaining_stock.dart';
import 'package:med_reminder_offline/features/refill/domain/entities/refill_event.dart';
import 'package:med_reminder_offline/features/timeline/application/build_daily_timeline.dart';
import 'package:med_reminder_offline/features/timeline/domain/entities/timeline_item.dart';

void main() {
  test('today dose application query preserves scheduled dose identity', () {
    final medication = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['20:00', '08:00'],
      initialAmount: 10,
      createdAt: DateTime(2026, 8, 21),
    );
    final taken = DoseLog(
      id: 'l1',
      medId: 'm1',
      scheduledAt: DateTime(2026, 8, 21, 8),
      takenAt: DateTime(2026, 8, 21, 8, 5),
      status: DoseStatus.taken,
    );

    final doses = buildTodayDoses(
      medications: <Medication>[medication],
      logs: <DoseLog>[taken],
      now: DateTime(2026, 8, 21, 12),
    );

    expect(doses, hasLength(2));
    expect(doses.first.scheduledAt.hour, 8);
    expect(doses.first.isTaken, isTrue);
    expect(doses.last.scheduledAt.hour, 20);
  });

  test('remaining stock is derived from refill and taken-dose events', () {
    final medication = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00'],
      initialAmount: 10,
      dosagePerTime: 2,
      createdAt: DateTime(2026, 8, 21),
    );
    final logs = <DoseLog>[
      DoseLog(
        id: 'l1',
        medId: 'm1',
        scheduledAt: DateTime(2026, 8, 21, 8),
        status: DoseStatus.taken,
      ),
    ];
    final refills = <RefillEvent>[
      RefillEvent(
        id: 'r1',
        medicationId: 'm1',
        quantity: 20,
        createdAt: DateTime(2026, 8, 21, 9),
      ),
    ];

    expect(
      calculateRemainingStock(
        medication: medication,
        doseLogs: logs,
        refillEvents: refills,
      ),
      28,
    );
  });

  test('zero dosage preserves stock when a taken log exists', () {
    final medication = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['08:00'],
      initialAmount: 10,
      dosagePerTime: 0,
      createdAt: DateTime(2026, 8, 21),
    );
    final logs = <DoseLog>[
      DoseLog(
        id: 'l1',
        medId: 'm1',
        scheduledAt: DateTime(2026, 8, 21, 8),
        status: DoseStatus.taken,
      ),
    ];

    expect(
      calculateRemainingStock(
        medication: medication,
        doseLogs: logs,
      ),
      10,
    );
  });

  test('daily timeline is an ordered projection of feature read models', () {
    final medication = Medication(
      id: 'm1',
      name: 'Test',
      times: const <String>['20:00', '08:00'],
      createdAt: DateTime(2026, 8, 21),
    );
    final doses = buildTodayDoses(
      medications: <Medication>[medication],
      logs: const <DoseLog>[],
      now: DateTime(2026, 8, 21, 12),
    );

    final timeline = buildDailyTimeline(scheduledDoses: doses);

    expect(timeline, hasLength(2));
    expect(timeline.first, isA<MedicationDoseTimelineItem>());
    expect(timeline.first.at.hour, 8);
    expect(timeline.last.at.hour, 20);
  });
}
