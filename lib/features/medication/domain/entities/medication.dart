import 'dose_log.dart';

export 'dose_log.dart';
export 'scheduled_dose.dart';

enum MedicationMode { forever, days, untilEmpty }

class Medication {
  Medication({
    required this.id,
    required this.name,
    required List<String> times,
    required this.createdAt,
    this.description = '',
    this.initialAmount,
    this.lowThreshold,
    this.imagePath,
    this.dosagePerTime = 1,
    this.mode = MedicationMode.forever,
    this.daysCount,
    List<int> notificationIds = const <int>[],
  })  : times = List<String>.unmodifiable(times),
        notificationIds = List<int>.unmodifiable(notificationIds);

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
    final takenCount =
        logs.where((log) => log.medId == id && log.isTaken).length;
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
    int? initialAmount,
    List<int>? notificationIds,
    String? imagePath,
  }) =>
      Medication(
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
