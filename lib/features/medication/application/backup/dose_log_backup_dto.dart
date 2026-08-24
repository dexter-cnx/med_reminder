import '../../../../core/result/result.dart';
import '../../domain/entities/dose_log.dart';

class DoseLogBackupDto {
  const DoseLogBackupDto._();

  static const int version = 1;

  static Map<String, Object?> encode(DoseLog log) => <String, Object?>{
        'version': version,
        'id': log.id,
        'medId': log.medId,
        'scheduledAt': log.scheduledAt.toUtc().toIso8601String(),
        'takenAt': log.takenAt?.toUtc().toIso8601String(),
        'status': log.status.name,
      };

  static Result<DoseLog> decode(Map<String, Object?> payload) {
    try {
      if (payload['version'] != version) {
        return const Failed<DoseLog>(
          Failure(
            code: 'backup_dose_log_version_unsupported',
            message: 'Unsupported dose-log backup record version.',
          ),
        );
      }

      final takenAt = _optionalString(payload, 'takenAt');
      return Success<DoseLog>(
        DoseLog(
          id: _requiredString(payload, 'id'),
          medId: _requiredString(payload, 'medId'),
          scheduledAt: DateTime.parse(
            _requiredString(payload, 'scheduledAt'),
          ),
          takenAt: takenAt == null ? null : DateTime.parse(takenAt),
          status: DoseStatus.values.byName(
            _requiredString(payload, 'status'),
          ),
        ),
      );
    } on Object {
      return const Failed<DoseLog>(
        Failure(
          code: 'backup_dose_log_invalid',
          message: 'Dose-log backup record is invalid.',
        ),
      );
    }
  }

  static String _requiredString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is String) return value;
    throw FormatException('Expected String for $key');
  }

  static String? _optionalString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null || value is String) return value as String?;
    throw FormatException('Expected String? for $key');
  }
}
