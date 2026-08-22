import '../../medication/domain/entities/scheduled_dose.dart';
import '../../refill/domain/entities/refill_event.dart';
import '../domain/entities/timeline_item.dart';

/// Composes source feature read models into one ordered daily timeline.
///
/// Timeline remains a projection only. Source features continue to own their
/// persistence and lifecycle.
List<TimelineItem> buildDailyTimeline({
  Iterable<ScheduledDose> scheduledDoses = const <ScheduledDose>[],
  Iterable<RefillEvent> refillEvents = const <RefillEvent>[],
  Map<String, String> medicationNames = const <String, String>{},
  DateTime? day,
}) {
  final targetDay = day ?? DateTime.now();
  final items = <TimelineItem>[
    for (final dose in scheduledDoses)
      if (_isSameDay(dose.scheduledAt, targetDay))
        MedicationDoseTimelineItem(dose: dose),
    for (final event in refillEvents)
      if (_isSameDay(event.createdAt, targetDay))
        RefillTimelineItem(
          event: event,
          medicationName: medicationNames[event.medicationId] ?? '',
        ),
  ];
  items.sort((a, b) => a.at.compareTo(b.at));
  return List<TimelineItem>.unmodifiable(items);
}

bool _isSameDay(DateTime value, DateTime day) =>
    value.year == day.year &&
    value.month == day.month &&
    value.day == day.day;
