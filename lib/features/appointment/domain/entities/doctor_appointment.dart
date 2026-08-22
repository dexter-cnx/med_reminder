class DoctorAppointment {
  DoctorAppointment({
    required this.id,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.location,
    this.note,
    this.externalCalendarEventId,
  }) : assert(
          endsAt == null || !endsAt.isBefore(startsAt),
          'Appointment end must not be before its start.',
        );

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final String? note;

  /// Optional platform-calendar linkage metadata.
  ///
  /// The appointment domain does not depend on a calendar plugin. A future
  /// calendar adapter may populate this after explicit user confirmation.
  final String? externalCalendarEventId;
}
