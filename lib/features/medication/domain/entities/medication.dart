enum MedicationMode { forever, days, untilEmpty }
enum DoseStatus { pending, taken, skipped, snoozed }

class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.times,
    required this.createdAt,
    this.description = '',
    this.initialAmount,
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
  final int? initialAmount;
  final int? lowThreshold;
  final String? imagePath;
  final int dosagePerTime;
  final MedicationMode mode;
  final int? daysCount;
  final List<int> notificationIds;

  @Deprecated('Use initialAmount for configured stock and remaining(logs) for current stock.')
  int? get totalAmount => initialAmount;

  DateTime? get expiryExclusive {
    if (mode != MedicationMode.days || daysCount == null) return null;
    final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
    return start.add(Duration(days: daysCount!));
  }

  DateTime? get expiryDate {
    final exclusive = expiryExclusive;
    return exclusive?.subtract(const Duration(days: 1));
  }

  bool isExpired(DateTime date) {
    final expiry = expiryExclusive;
    return expiry != null && !date.isBefore(expiry);
  }

  int? remaining(Iterable<DoseLog> logs) {
    final initial = initialAmount;
    if (initial == null) return null;
    final takenCount = logs.where((log) => log.medId == id && log.status == DoseStatus.taken).length;
    final value = initial - (takenCount * dosagePerTime);
    return value < 0 ? 0 : value;
  }

  bool isEmpty(Iterable<DoseLog> logs) => remaining(logs) == 0;

  bool isActiveOn(DateTime date, {Iterable<DoseLog> logs = const <DoseLog>[]}) {
    if (mode == MedicationMode.untilEmpty && isEmpty(logs)) return false;
    return !isExpired(date);
  }

  Medication copyWith({
    int? initialAmount,
    List<int>? notificationIds,
    String? imagePath,
  }) => Medication(
        id: id,
        name: name,
        description: description,
        initialAmount: initialAmount ?? this.initialAmount,
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
    this.remaining,
  });

  final Medication medication;
  final DateTime scheduledAt;
  final DoseLog? log;
  final int? remaining;

  bool get isTaken => log?.status == DoseStatus.taken;
  bool get isSkipped => log?.status == DoseStatus.skipped;
  bool get isSnoozed => log?.status == DoseStatus.snoozed;
}
