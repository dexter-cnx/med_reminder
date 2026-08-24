import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/medication_backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_record.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';
import 'package:med_reminder_offline/features/medication/application/backup/medication_backup_dto.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/repositories/medication_repository.dart';

void main() {
  test('capture excludes dose logs whose medication no longer exists',
      () async {
    final medication = _medication('med-1');
    final medicationRepository =
        _FakeMedicationRepository(<Medication>[medication]);
    final doseLogRepository = _FakeDoseLogRepository(<DoseLog>[
      _doseLog('log-1', 'med-1'),
      _doseLog('orphan-log', 'deleted-med'),
    ]);
    final port = MedicationBackupDataPort(
      medicationRepository: medicationRepository,
      doseLogRepository: doseLogRepository,
      now: () => DateTime.utc(2026, 8, 24, 12),
    );

    final result = await port.capture();

    result.fold(
      onSuccess: (snapshot) {
        expect(
          snapshot.records.map((record) => record.id),
          containsAll(<String>['med-1', 'log-1']),
        );
        expect(
          snapshot.records.map((record) => record.id),
          isNot(contains('orphan-log')),
        );
      },
      onFailure: (failure) => fail(failure.toString()),
    );
  });

  test('restore rolls medication data back when first replacement fails',
      () async {
    final oldMedication = _medication('old-med');
    final newMedication = _medication('new-med');
    final medicationRepository = _FakeMedicationRepository(
      <Medication>[oldMedication],
      failFirstReplaceAfterMutation: true,
    );
    final doseLogRepository = _FakeDoseLogRepository(<DoseLog>[]);
    final port = MedicationBackupDataPort(
      medicationRepository: medicationRepository,
      doseLogRepository: doseLogRepository,
    );
    final snapshot = BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      exportedAt: DateTime.utc(2026, 8, 24),
      records: <BackupRecord>[
        BackupRecord(
          namespace: MedicationBackupDataPort.medicationNamespace,
          id: newMedication.id,
          payload: MedicationBackupDto.encode(newMedication),
        ),
      ],
    );

    final result = await port.restoreAtomically(snapshot);

    expect(result.isFailure, isTrue);
    expect(medicationRepository.values.map((value) => value.id),
        <String>['old-med']);
    expect(medicationRepository.replaceCalls, 2);
    expect(doseLogRepository.replaceCalls, 0);
  });
}

Medication _medication(String id) => Medication(
      id: id,
      name: 'Medication $id',
      genericName: 'generic',
      description: 'description',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 24),
      mode: MedicationMode.forever,
      dosePlan: MedicationDosePlan.scheduled,
    );

DoseLog _doseLog(String id, String medId) => DoseLog(
      id: id,
      medId: medId,
      scheduledAt: DateTime(2026, 8, 24, 8),
      status: DoseStatus.pending,
    );

final class _FakeMedicationRepository implements MedicationRepository {
  _FakeMedicationRepository(
    List<Medication> values, {
    this.failFirstReplaceAfterMutation = false,
  }) : values = List<Medication>.of(values);

  List<Medication> values;
  final bool failFirstReplaceAfterMutation;
  int replaceCalls = 0;

  @override
  Result<List<Medication>> readAll() => Success<List<Medication>>(
        List<Medication>.of(values),
      );

  @override
  Future<Result<void>> replaceAll(List<Medication> medications) async {
    replaceCalls += 1;
    values = List<Medication>.of(medications);
    if (failFirstReplaceAfterMutation && replaceCalls == 1) {
      return const Failed<void>(
        Failure(
            code: 'replace_failed', message: 'Simulated partial replacement.'),
      );
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    values.removeWhere((value) => value.id == id);
    return const Success<void>(null);
  }
}

final class _FakeDoseLogRepository implements DoseLogRepository {
  _FakeDoseLogRepository(List<DoseLog> values)
      : values = List<DoseLog>.of(values);

  List<DoseLog> values;
  int replaceCalls = 0;

  @override
  Result<List<DoseLog>> readAll() => Success<List<DoseLog>>(
        List<DoseLog>.of(values),
      );

  @override
  Future<Result<void>> replaceAll(List<DoseLog> logs) async {
    replaceCalls += 1;
    values = List<DoseLog>.of(logs);
    return const Success<void>(null);
  }
}
