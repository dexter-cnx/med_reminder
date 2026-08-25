import '../../../../core/result/result.dart';
import '../../domain/entities/medication.dart';

class MedicationBackupDto {
  const MedicationBackupDto._();

  static const int version = 1;

  static Map<String, Object?> encode(Medication medication) =>
      <String, Object?>{
        'version': version,
        'id': medication.id,
        'name': medication.name,
        'genericName': medication.genericName,
        'description': medication.description,
        'times': medication.times,
        'createdAt': _encodeLocalDateTime(medication.createdAt),
        'initialAmount': medication.initialAmount,
        'lowThreshold': medication.lowThreshold,
        'imagePath': medication.imagePath,
        'dosagePerTime': medication.dosagePerTime,
        'mode': medication.mode.name,
        'dosePlan': medication.dosePlan.name,
        'daysCount': medication.daysCount,
      };

  static Result<Medication> decode(Map<String, Object?> payload) {
    try {
      if (payload['version'] != version) {
        return const Failed<Medication>(
          Failure(
            code: 'backup_medication_version_unsupported',
            message: 'Unsupported medication backup record version.',
          ),
        );
      }

      final timesValue = payload['times'];
      if (timesValue is! List) {
        return const Failed<Medication>(
          Failure(
            code: 'backup_medication_invalid',
            message: 'Medication backup record has invalid times.',
          ),
        );
      }

      final medication = Medication(
        id: _requiredString(payload, 'id'),
        name: _requiredString(payload, 'name'),
        genericName: _optionalString(payload, 'genericName') ?? '',
        description: _optionalString(payload, 'description') ?? '',
        times: timesValue.map((value) => value as String).toList(),
        createdAt: _decodeLocalDateTime(_requiredString(payload, 'createdAt')),
        initialAmount: _optionalInt(payload, 'initialAmount'),
        lowThreshold: _optionalInt(payload, 'lowThreshold'),
        imagePath: _optionalString(payload, 'imagePath'),
        dosagePerTime: _optionalInt(payload, 'dosagePerTime') ?? 1,
        mode: MedicationMode.values.byName(_requiredString(payload, 'mode')),
        dosePlan: MedicationDosePlan.values.byName(
          _optionalString(payload, 'dosePlan') ??
              MedicationDosePlan.scheduled.name,
        ),
        daysCount: _optionalInt(payload, 'daysCount'),
      );

      return Success<Medication>(medication);
    } on Object {
      return const Failed<Medication>(
        Failure(
          code: 'backup_medication_invalid',
          message: 'Medication backup record is invalid.',
        ),
      );
    }
  }

  static String _encodeLocalDateTime(DateTime value) => DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  ).toIso8601String();

  static DateTime _decodeLocalDateTime(String value) {
    final parsed = DateTime.parse(value);
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
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

  static int? _optionalInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null || value is int) return value as int?;
    throw FormatException('Expected int? for $key');
  }
}
