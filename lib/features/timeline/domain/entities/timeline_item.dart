import '../../../medication/domain/entities/scheduled_dose.dart';

/// Presentation-oriented read model for Besyu's daily operational timeline.
///
/// Timeline items are projections of source-of-truth domain data. They should
/// not become a second persistence model for medication, appointment, refill,
/// or check-in state.
sealed class TimelineItem {
  const TimelineItem({required this.at});

  final DateTime at;
}

final class MedicationDoseTimelineItem extends TimelineItem {
  MedicationDoseTimelineItem({required this.dose})
      : super(at: dose.scheduledAt);

  final ScheduledDose dose;
}
