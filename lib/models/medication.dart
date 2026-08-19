import 'package:uuid/uuid.dart';

enum MedicationMode { forever, days, untilEmpty }
enum DoseStatus { pending, taken, skipped, snoozed }

class Medication {
  Medication({
    required this.id,
    required this.name,
    required this.times,
    required this.createdAt,
    this.description = '',
    this.totalAmount,
    this.lowThreshold,
    this.imagePath,
    this.dosagePerTime = 1,
    this.mode = MedicationMode.forever,
    this.daysCount,
    this.notificationIds = const <int>[],
  });

  final String id;
  final String name;
  final String description;
  final List<String> times;
  final DateTime createdAt;
  final int? totalAmount;
  final int? lowThreshold;
  final String? imagePath;
  final int dosagePerTime;
  final MedicationMode mode;
  final int? daysCount;
  final List<int> notificationIds;

  DateTime? get expiryExclusive {
    if (mode != MedicationMode.days || daysCount == null) return null;
    final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
    return start.add(Duration(days: daysCount!));
  }

  bool get isEmpty => totalAmount != null && totalAmount! <= 0;

  bool isActiveOn(DateTime date) {
    if (mode == MedicationMode.untilEmpty && isEmpty) return false;
    final expiry = expiryExclusive;
    if (expiry == null) return true;
    return date.isBefore(expiry);
  }

  Medication copyWith({
    int? totalAmount,
    List<int>? notificationIds,
    String? imagePath,
  }) {
    return Medication(
      id: id,
      name: name,
      description: description,
      totalAmount: totalAmount ?? this.totalAmount,
      lowThreshold: lowThreshold,
      imagePath: imagePath ?? this.imagePath,
      times: times,
      dosagePerTime: dosagePerTime,
      mode: mode,
      daysCount: daysCount,
      createdAt: createdAt,
      notificationIds: notificationIds ?? this.notificationIds,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'totalAmount': totalAmount,
        'lowThreshold': lowThreshold,
        'imagePath': imagePath,
        'times': times,
        'dosagePerTime': dosagePerTime,
        'mode': mode.name,
        'daysCount': daysCount,
        'createdAt': createdAt.toIso8601String(),
        'notificationIds': notificationIds,
      };

  static Medication fromMap(Map<dynamic, dynamic> map) {
    final rawMode = map['mode']?.toString() ?? 'forever';
    final mode = switch (rawMode) {
      'until_empty' || 'untilEmpty' => MedicationMode.untilEmpty,
      'days' => MedicationMode.days,
      _ => MedicationMode.forever,
    };
    return Medication(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] ?? map['desc'] ?? '') as String,
      totalAmount: map['totalAmount'] as int?,
      lowThreshold: map['lowThreshold'] as int?,
      imagePath: map['imagePath'] as String?,
      times: List<String>.from(map['times'] as List? ?? const <String>[]),
      dosagePerTime: (map['dosagePerTime'] as int?) ?? 1,
      mode: mode,
      daysCount: map['daysCount'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      notificationIds: List<int>.from(map['notificationIds'] as List? ?? const <int>[]),
    );
  }
}

class DoseLog {
  DoseLog({
    required this.id,
    required this.medId,
    required this.scheduledAt,
    this.takenAt,
    this.status = DoseStatus.pending,
  });

  final String id;
  final String medId;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final DoseStatus status;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'medId': medId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'takenAt': takenAt?.toIso8601String(),
        'status': status.name,
      };

  static DoseLog fromMap(Map<dynamic, dynamic> map) {
    if (!map.containsKey('scheduledAt') && map.containsKey('time')) {
      final oldTime = DateTime.parse(map['time'] as String);
      return DoseLog(
        id: const Uuid().v4(),
        medId: map['medId'] as String,
        scheduledAt: oldTime,
        takenAt: oldTime,
        status: DoseStatus.taken,
      );
    }
    return DoseLog(
      id: (map['id'] as String?) ?? const Uuid().v4(),
      medId: map['medId'] as String,
      scheduledAt: DateTime.parse(map['scheduledAt'] as String),
      takenAt: map['takenAt'] == null ? null : DateTime.parse(map['takenAt'] as String),
      status: DoseStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => DoseStatus.pending,
      ),
    );
  }
}

class ScheduledDose {
  const ScheduledDose({
    required this.medication,
    required this.scheduledAt,
    this.log,
  });

  final Medication medication;
  final DateTime scheduledAt;
  final DoseLog? log;

  bool get isTaken => log?.status == DoseStatus.taken;
  bool get isSkipped => log?.status == DoseStatus.skipped;
  bool get isSnoozed => log?.status == DoseStatus.snoozed;
}
