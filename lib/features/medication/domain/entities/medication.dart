enum MedicationMode { forever, days, untilEmpty }
enum DoseStatus { pending, taken, skipped, snoozed }

class Medication {
  const Medication({
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
    return expiry == null || date.isBefore(expiry);
  }

  Medication copyWith({
    int? totalAmount,
    List<int>? notificationIds,
    String? imagePath,
  }) => Medication(
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

class DoseLog {
  const DoseLog({
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
