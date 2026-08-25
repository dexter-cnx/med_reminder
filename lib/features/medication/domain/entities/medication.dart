import 'dose_log.dart';

export 'dose_log.dart';
export 'scheduled_dose.dart';

enum MedicationMode { forever, days, untilEmpty }

/// Describes how a medication dose is initiated.
///
/// This is intentionally separate from [MedicationMode]. [MedicationMode]
/// controls how long a medication course remains active, while [dosePlan]
/// controls whether doses are scheduled ahead of time or taken only when
/// needed (PRN / pro re nata).
enum MedicationDosePlan { scheduled, asNeeded }

class Medication {
  Medication({
    required this.id,
    required this.name,
    required List<String> times,
    required this.createdAt,
    this.genericName = '',
    this.description = '',
    this.initialAmount,
    this.lowThreshold,
    this.imagePath,
    this.dosagePerTime = 1,
    this.mode = MedicationMode.forever,
    this.dosePlan = MedicationDosePlan.scheduled,
    this.daysCount,
    List<int> notificationIds = const <int>[],
  }) : times = List<String>.unmodifiable(times),
       notificationIds = List<int>.unmodifiable(notificationIds);

  final String id;

  /// User-facing medication name, typically a trade/brand name or label name.
  final String name;

  /// Generic/medical drug name, for example "paracetamol".
  ///
  /// Kept separate from [name] so Besyu can display both the familiar label
  /// name and the medically meaningful generic name without conflating them.
  final String genericName;
  final String description;
  final List<String> times;
  final DateTime createdAt;
  final int? initialAmount;
  final int? lowThreshold;
  final String? imagePath;
  final int dosagePerTime;
  final MedicationMode mode;
  final MedicationDosePlan dosePlan;
  final int? daysCount;
  final List<int> notificationIds;

  bool get isAsNeeded => dosePlan == MedicationDosePlan.asNeeded;

  bool get hasScheduledDoses => dosePlan == MedicationDosePlan.scheduled;

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
    final takenCount = logs
        .where((log) => log.medId == id && log.isTaken)
        .length;
    final value = initial - (takenCount * dosagePerTime);
    return value < 0 ? 0 : value;
  }

  bool isLowStock(Iterable<DoseLog> logs) {
    final threshold = lowThreshold;
    final value = remaining(logs);
    return threshold != null && value != null && value <= threshold;
  }

  bool isEmpty(Iterable<DoseLog> logs) => remaining(logs) == 0;

  bool isActiveOn(DateTime date, {Iterable<DoseLog> logs = const <DoseLog>[]}) {
    if (mode == MedicationMode.untilEmpty && isEmpty(logs)) return false;
    return !isExpired(date);
  }

  Medication copyWith({
    String? genericName,
    int? initialAmount,
    List<int>? notificationIds,
    String? imagePath,
    MedicationDosePlan? dosePlan,
    DateTime? createdAt,
    int? daysCount,
  }) => Medication(
    id: id,
    name: name,
    genericName: genericName ?? this.genericName,
    description: description,
    initialAmount: initialAmount ?? this.initialAmount,
    lowThreshold: lowThreshold,
    imagePath: imagePath ?? this.imagePath,
    times: times,
    dosagePerTime: dosagePerTime,
    mode: mode,
    dosePlan: dosePlan ?? this.dosePlan,
    daysCount: daysCount ?? this.daysCount,
    createdAt: createdAt ?? this.createdAt,
    notificationIds: notificationIds ?? this.notificationIds,
  );
}