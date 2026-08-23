import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/appointment/domain/entities/doctor_appointment.dart';
import 'package:med_reminder_offline/features/doctor_visit_summary/application/build_doctor_visit_summary.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/dose_log.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication_checkin/domain/entities/medication_check_in.dart';
import 'package:med_reminder_offline/features/refill/domain/entities/refill_event.dart';

void main() {
  test('summary aggregates only records inside the configured period', () {
    final now = DateTime(2026, 8, 23, 17);
    final medication = Medication(
      id: 'm1',
      name: 'Brand A',
      genericName: 'generic-a',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 1, 1),
    );

    final summary = const BuildDoctorVisitSummary()(
      now: now,
      medications: <Medication>[medication],
      doseLogs: <DoseLog>[
        DoseLog(
          id: 'taken',
          medId: 'm1',
          scheduledAt: DateTime(2026, 8, 20, 8),
          status: DoseStatus.taken,
        ),
        DoseLog(
          id: 'skipped',
          medId: 'm1',
          scheduledAt: DateTime(2026, 8, 21, 8),
          status: DoseStatus.skipped,
        ),
        DoseLog(
          id: 'old',
          medId: 'm1',
          scheduledAt: DateTime(2026, 7, 1, 8),
          status: DoseStatus.taken,
        ),
      ],
      refillEvents: <RefillEvent>[
        RefillEvent(
          id: 'r1',
          medicationId: 'm1',
          quantity: 20,
          createdAt: DateTime(2026, 8, 15),
        ),
      ],
      checkIns: <MedicationCheckIn>[
        MedicationCheckIn(
          id: 'c1',
          medicationId: 'm1',
          recordedAt: DateTime(2026, 8, 22),
          kind: MedicationCheckInKind.nausea,
          note: 'after lunch',
        ),
      ],
      appointments: <DoctorAppointment>[
        DoctorAppointment(
          id: 'past',
          title: 'Past visit',
          startsAt: DateTime(2026, 8, 1),
        ),
        DoctorAppointment(
          id: 'future',
          title: 'Next visit',
          startsAt: DateTime(2026, 9, 1),
        ),
      ],
    );

    expect(summary.medications, hasLength(1));
    final item = summary.medications.single;
    expect(item.takenCount, 1);
    expect(item.skippedCount, 1);
    expect(item.refillQuantity, 20);
    expect(item.checkIns.single.note, 'after lunch');
    expect(summary.upcomingAppointments.single.id, 'future');
  });

  test('check-ins are sorted newest first without altering source records', () {
    final source = <MedicationCheckIn>[
      MedicationCheckIn(
        id: 'old',
        medicationId: 'm1',
        recordedAt: DateTime(2026, 8, 20),
        kind: MedicationCheckInKind.noIssue,
      ),
      MedicationCheckIn(
        id: 'new',
        medicationId: 'm1',
        recordedAt: DateTime(2026, 8, 22),
        kind: MedicationCheckInKind.rash,
      ),
    ];

    final summary = const BuildDoctorVisitSummary()(
      now: DateTime(2026, 8, 23),
      medications: <Medication>[
        Medication(
          id: 'm1',
          name: 'A',
          times: const <String>['08:00'],
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
      doseLogs: const <DoseLog>[],
      refillEvents: const <RefillEvent>[],
      checkIns: source,
      appointments: const <DoctorAppointment>[],
    );

    expect(
      summary.medications.single.checkIns.map((item) => item.id),
      <String>['new', 'old'],
    );
    expect(source.map((item) => item.id), <String>['old', 'new']);
  });
}
