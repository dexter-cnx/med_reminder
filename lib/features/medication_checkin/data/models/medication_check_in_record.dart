import '../../domain/entities/medication_check_in.dart';

class MedicationCheckInRecord {
  const MedicationCheckInRecord(this.value);

  final Map<String, dynamic> value;

  factory MedicationCheckInRecord.fromEntity(MedicationCheckIn checkIn) =>
      MedicationCheckInRecord(<String, dynamic>{
        'id': checkIn.id,
        'medicationId': checkIn.medicationId,
        'recordedAt': checkIn.recordedAt.toIso8601String(),
        'kind': checkIn.kind.name,
        'note': checkIn.note,
      });

  MedicationCheckIn toEntity() {
    final rawKind = value['kind']?.toString() ?? 'other';
    final kind = MedicationCheckInKind.values.firstWhere(
      (item) => item.name == rawKind,
      orElse: () => MedicationCheckInKind.other,
    );

    return MedicationCheckIn(
      id: value['id'] as String,
      medicationId: value['medicationId'] as String,
      recordedAt: DateTime.parse(value['recordedAt'] as String),
      kind: kind,
      note: (value['note'] ?? '') as String,
    );
  }
}
