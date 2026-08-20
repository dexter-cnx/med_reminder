import '../../medication/domain/entities/scheduled_dose.dart';
import '../domain/entities/timeline_item.dart';

/// Composes source feature read models into one ordered daily timeline.
///
/// Appointment/refill/check-in items can be added as new TimelineItem
/// subclasses without teaching HomeScreen how to join repositories.
List<TimelineItem> buildDailyTimeline({
  Iterable<ScheduledDose> scheduledDoses = const <ScheduledDose>[],
}) {
  final items = <TimelineItem>[
    for (final dose in scheduledDoses) MedicationDoseTimelineItem(dose: dose),
  ];
  items.sort((a, b) => a.at.compareTo(b.at));
  return List<TimelineItem>.unmodifiable(items);
}
