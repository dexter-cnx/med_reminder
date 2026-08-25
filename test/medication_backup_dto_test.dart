import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/application/backup/dose_log_backup_dto.dart';
import 'package:med_reminder_offline/features/medication/application/backup/medication_backup_dto.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';

void main() {
  test(
    'medication backup DTO round-trips domain data without notification IDs',
    () {
      final medication = Medication(
        id: 'med-1',
        name: 'Tylenol',
        genericName: 'paracetamol',
        description: '500 mg tablet',
        times: const <String>['08:00', '20:00'],
        createdAt: DateTime(2026, 8, 24, 0, 30),
        initialAmount: 20,
        lowThreshold: 5,
        imagePath: '/local/med-1.jpg',
        dosagePerTime: 2,
        mode: MedicationMode.days,
        dosePlan: MedicationDosePlan.scheduled,
        daysCount: 7,
        notificationIds: const <int>[101, 102],
      );

      final payload = MedicationBackupDto.encode(medication);
      final decoded = MedicationBackupDto.decode(payload);

      expect(payload.containsKey('notificationIds'), isFalse);
      expect(payload['createdAt'], '2026-08-24T00:30:00.000');
      decoded.fold(
        onSuccess: (value) {
          expect(value.id, medication.id);
          expect(value.name, medication.name);
          expect(value.genericName, medication.genericName);
          expect(value.description, medication.description);
          expect(value.times, medication.times);
          expect(value.createdAt, medication.createdAt);
          expect(value.createdAt.isUtc, isFalse);
          expect(value.initialAmount, medication.initialAmount);
          expect(value.lowThreshold, medication.lowThreshold);
          expect(value.imagePath, medication.imagePath);
          expect(value.dosagePerTime, medication.dosagePerTime);
          expect(value.mode, medication.mode);
          expect(value.dosePlan, medication.dosePlan);
          expect(value.daysCount, medication.daysCount);
          expect(value.notificationIds, isEmpty);
        },
        onFailure: (failure) => fail(failure.toString()),
      );
    },
  );

  test('dose log backup DTO preserves scheduled local wall-clock time', () {
    final log = DoseLog(
      id: 'log-1',
      medId: 'med-1',
      scheduledAt: DateTime(2026, 8, 24, 8),
      takenAt: DateTime.utc(2026, 8, 24, 1, 5),
      status: DoseStatus.taken,
    );

    final payload = DoseLogBackupDto.encode(log);
    final decoded = DoseLogBackupDto.decode(payload);

    expect(payload['scheduledAt'], '2026-08-24T08:00:00.000');
    expect(payload['takenAt'], '2026-08-24T01:05:00.000Z');
    decoded.fold(
      onSuccess: (value) {
        expect(value.id, log.id);
        expect(value.medId, log.medId);
        expect(value.scheduledAt, log.scheduledAt);
        expect(value.scheduledAt.isUtc, isFalse);
        expect(value.takenAt?.toUtc(), log.takenAt?.toUtc());
        expect(value.status, log.status);
      },
      onFailure: (failure) => fail(failure.toString()),
    );
  });

  test('DTOs reject unsupported record versions', () {
    final medication = MedicationBackupDto.decode(<String, Object?>{
      'version': 2,
    });
    final doseLog = DoseLogBackupDto.decode(<String, Object?>{'version': 2});

    expect(medication.isFailure, isTrue);
    expect(doseLog.isFailure, isTrue);
  });
}
