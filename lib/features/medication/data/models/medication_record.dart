import 'package:uuid/uuid.dart';

import '../../domain/entities/medication.dart';

class MedicationRecord {
  const MedicationRecord(this.value);
  final Map<String, dynamic> value;

  factory MedicationRecord.fromEntity(Medication medication) => MedicationRecord(<String, dynamic>{
        'id': medication.id,
        'name': medication.name,
        'description': medication.description,
        'initialAmount': medication.initialAmount,
        'lowThreshold': medication.lowThreshold,
        'imagePath': medication.imagePath,
        'times': medication.times,
        'dosagePerTime': medication.dosagePerTime,
        'mode': medication.mode.name,
        'daysCount': medication.daysCount,
        'createdAt': medication.createdAt.toIso8601String(),
        'notificationIds': medication.notificationIds,
      });

  Medication toEntity() {
    final rawMode = value['mode']?.toString() ?? 'forever';
    final mode = switch (rawMode) {
      'until_empty' || 'untilEmpty' => MedicationMode.untilEmpty,
      'days' => MedicationMode.days,
      _ => MedicationMode.forever,
    };
    return Medication(
      id: value['id'] as String,
      name: value['name'] as String,
      description: (value['description'] ?? value['desc'] ?? '') as String,
      initialAmount: (value['initialAmount'] ?? value['totalAmount']) as int?,
      lowThreshold: value['lowThreshold'] as int?,
      imagePath: value['imagePath'] as String?,
      times: List<String>.from(value['times'] as List? ?? const <String>[]),
      dosagePerTime: (value['dosagePerTime'] as int?) ?? 1,
      mode: mode,
      daysCount: value['daysCount'] as int?,
      createdAt: DateTime.parse(value['createdAt'] as String),
      notificationIds: List<int>.from(value['notificationIds'] as List? ?? const <int>[]),
    );
  }
}

class DoseLogRecord {
  const DoseLogRecord(this.value);
  final Map<String, dynamic> value;

  factory DoseLogRecord.fromEntity(DoseLog log) => DoseLogRecord(<String, dynamic>{
        'id': log.id,
        'medId': log.medId,
        'scheduledAt': log.scheduledAt.toIso8601String(),
        'takenAt': log.takenAt?.toIso8601String(),
        'status': log.status.name,
      });

  DoseLog toEntity() {
    if (!value.containsKey('scheduledAt') && value.containsKey('time')) {
      final oldTime = DateTime.parse(value['time'] as String);
      return DoseLog(
        id: const Uuid().v4(),
        medId: value['medId'] as String,
        scheduledAt: oldTime,
        takenAt: oldTime,
        status: DoseStatus.taken,
      );
    }
    return DoseLog(
      id: (value['id'] as String?) ?? const Uuid().v4(),
      medId: value['medId'] as String,
      scheduledAt: DateTime.parse(value['scheduledAt'] as String),
      takenAt: value['takenAt'] == null ? null : DateTime.parse(value['takenAt'] as String),
      status: DoseStatus.values.firstWhere(
        (item) => item.name == value['status'],
        orElse: () => DoseStatus.pending,
      ),
    );
  }
}
