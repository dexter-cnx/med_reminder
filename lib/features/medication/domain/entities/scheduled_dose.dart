import 'dose_log.dart';
import 'medication.dart';

/// Read model for one scheduled dose shown by presentation/application flows.
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
