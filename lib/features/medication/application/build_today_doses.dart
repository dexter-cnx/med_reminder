import '../domain/entities/medication.dart';

/// Builds the medication portion of today's operational timeline.
///
/// Keeping this outside the ViewModel makes the deterministic scheduling/read
/// logic reusable by Home, future timeline composition, doctor summaries, and
/// MCP/application tools without depending on Flutter or Riverpod.
List<ScheduledDose> buildTodayDoses({
  required Iterable<Medication> medications,
  required Iterable<DoseLog> logs,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final doses = <ScheduledDose>[];

  for (final medication in medications) {
    if (!medication.isActiveOn(current, logs: logs)) continue;
    final remaining = medication.remaining(logs);

    for (final time in medication.times) {
      final parts = time.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final scheduled = DateTime(
        current.year,
        current.month,
        current.day,
        hour,
        minute,
      );
      final log = _findDoseLog(logs, medication.id, scheduled);

      doses.add(
        ScheduledDose(
          medication: medication,
          scheduledAt: scheduled,
          log: log,
          remaining: remaining,
        ),
      );
    }
  }

  doses.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return List<ScheduledDose>.unmodifiable(doses);
}

DoseLog? _findDoseLog(
  Iterable<DoseLog> logs,
  String medicationId,
  DateTime scheduled,
) {
  for (final log in logs) {
    if (isSameScheduledDose(log, medicationId, scheduled)) return log;
  }
  return null;
}

bool isSameScheduledDose(
  DoseLog log,
  String medicationId,
  DateTime scheduled,
) =>
    log.medId == medicationId &&
    log.scheduledAt.year == scheduled.year &&
    log.scheduledAt.month == scheduled.month &&
    log.scheduledAt.day == scheduled.day &&
    log.scheduledAt.hour == scheduled.hour &&
    log.scheduledAt.minute == scheduled.minute;
