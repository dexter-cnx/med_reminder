import '../../../core/result/result.dart';
import '../../medication/application/backup/dose_log_backup_dto.dart';
import '../../medication/application/backup/medication_backup_dto.dart';
import '../../medication/domain/entities/medication.dart';
import '../../medication/domain/repositories/medication_repository.dart';
import '../domain/entities/backup_record.dart';
import '../domain/entities/backup_snapshot.dart';
import 'backup_data_port.dart';

final class MedicationBackupDataPort implements BackupDataPort {
  MedicationBackupDataPort({
    required MedicationRepository medicationRepository,
    required DoseLogRepository doseLogRepository,
    DateTime Function()? now,
  })  : _medicationRepository = medicationRepository,
        _doseLogRepository = doseLogRepository,
        _now = now ?? DateTime.now;

  static const medicationNamespace = 'medication';
  static const doseLogNamespace = 'dose_log';

  final MedicationRepository _medicationRepository;
  final DoseLogRepository _doseLogRepository;
  final DateTime Function() _now;

  @override
  Future<Result<BackupSnapshot>> capture() async {
    final medications = _medicationRepository.readAll();
    if (medications case Failed<List<Medication>>(:final failure)) {
      return Failed<BackupSnapshot>(failure);
    }
    final logs = _doseLogRepository.readAll();
    if (logs case Failed<List<DoseLog>>(:final failure)) {
      return Failed<BackupSnapshot>(failure);
    }

    final medicationValues = (medications as Success<List<Medication>>).value;
    final medicationIds = medicationValues.map((value) => value.id).toSet();
    final logValues = (logs as Success<List<DoseLog>>)
        .value
        .where((log) => medicationIds.contains(log.medId));
    return Success<BackupSnapshot>(
      BackupSnapshot(
        schemaVersion: BackupSnapshot.currentSchemaVersion,
        exportedAt: _now().toUtc(),
        records: <BackupRecord>[
          for (final medication in medicationValues)
            BackupRecord(
              namespace: medicationNamespace,
              id: medication.id,
              payload: MedicationBackupDto.encode(medication),
            ),
          for (final log in logValues)
            BackupRecord(
              namespace: doseLogNamespace,
              id: log.id,
              payload: DoseLogBackupDto.encode(log),
            ),
        ],
      ),
    );
  }

  @override
  Future<Result<void>> restoreAtomically(BackupSnapshot snapshot) async {
    final decoded = _preflight(snapshot.records);
    if (decoded case Failed<_DecodedBackup>(:final failure)) {
      return Failed<void>(failure);
    }
    final incoming = (decoded as Success<_DecodedBackup>).value;

    final currentMedications = _medicationRepository.readAll();
    if (currentMedications case Failed<List<Medication>>(:final failure)) {
      return Failed<void>(failure);
    }
    final currentLogs = _doseLogRepository.readAll();
    if (currentLogs case Failed<List<DoseLog>>(:final failure)) {
      return Failed<void>(failure);
    }

    final oldMedications =
        (currentMedications as Success<List<Medication>>).value;
    final oldLogs = (currentLogs as Success<List<DoseLog>>).value;

    final medicationResult =
        await _medicationRepository.replaceAll(incoming.medications);
    if (medicationResult case Failed<void>(:final failure)) {
      final medicationRollback =
          await _medicationRepository.replaceAll(oldMedications);
      if (medicationRollback.isFailure) {
        return const Failed<void>(
          Failure(
            code: 'backup_restore_rollback_failed',
            message:
                'Restore failed and the previous data could not be fully restored.',
          ),
        );
      }
      return Failed<void>(failure);
    }

    final logResult = await _doseLogRepository.replaceAll(incoming.logs);
    if (logResult case Failed<void>(:final failure)) {
      final medicationRollback =
          await _medicationRepository.replaceAll(oldMedications);
      final logRollback = await _doseLogRepository.replaceAll(oldLogs);
      if (medicationRollback.isFailure || logRollback.isFailure) {
        return const Failed<void>(
          Failure(
            code: 'backup_restore_rollback_failed',
            message:
                'Restore failed and the previous data could not be fully restored.',
          ),
        );
      }
      return Failed<void>(failure);
    }

    return const Success<void>(null);
  }

  Result<_DecodedBackup> _preflight(List<BackupRecord> records) {
    final medications = <Medication>[];
    final logs = <DoseLog>[];
    final seen = <String>{};

    for (final record in records) {
      final identity = '${record.namespace}:${record.id}';
      if (!seen.add(identity)) {
        return const Failed<_DecodedBackup>(
          Failure(
            code: 'backup_duplicate_record',
            message: 'Backup contains duplicate record identifiers.',
          ),
        );
      }

      switch (record.namespace) {
        case medicationNamespace:
          final result = MedicationBackupDto.decode(record.payload);
          if (result case Failed<Medication>(:final failure)) {
            return Failed<_DecodedBackup>(failure);
          }
          final medication = (result as Success<Medication>).value;
          if (medication.id != record.id) {
            return const Failed<_DecodedBackup>(
              Failure(
                code: 'backup_record_id_mismatch',
                message: 'Backup record ID does not match its payload.',
              ),
            );
          }
          medications.add(medication);
        case doseLogNamespace:
          final result = DoseLogBackupDto.decode(record.payload);
          if (result case Failed<DoseLog>(:final failure)) {
            return Failed<_DecodedBackup>(failure);
          }
          final log = (result as Success<DoseLog>).value;
          if (log.id != record.id) {
            return const Failed<_DecodedBackup>(
              Failure(
                code: 'backup_record_id_mismatch',
                message: 'Backup record ID does not match its payload.',
              ),
            );
          }
          logs.add(log);
        default:
          return const Failed<_DecodedBackup>(
            Failure(
              code: 'backup_namespace_unsupported',
              message: 'Backup contains an unsupported record namespace.',
            ),
          );
      }
    }

    final medicationIds = medications.map((value) => value.id).toSet();
    if (logs.any((log) => !medicationIds.contains(log.medId))) {
      return const Failed<_DecodedBackup>(
        Failure(
          code: 'backup_dose_log_medication_missing',
          message: 'Backup contains a dose log for a missing medication.',
        ),
      );
    }

    return Success<_DecodedBackup>(
      _DecodedBackup(medications: medications, logs: logs),
    );
  }
}

final class _DecodedBackup {
  const _DecodedBackup({required this.medications, required this.logs});

  final List<Medication> medications;
  final List<DoseLog> logs;
}
