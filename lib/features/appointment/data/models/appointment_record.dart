import '../../domain/entities/doctor_appointment.dart';

class AppointmentRecord {
  const AppointmentRecord(this.value);

  static const int schemaVersion = 1;

  final Map<String, dynamic> value;

  factory AppointmentRecord.fromEntity(DoctorAppointment appointment) =>
      AppointmentRecord(
        <String, dynamic>{
          'schemaVersion': schemaVersion,
          'id': appointment.id,
          'title': appointment.title,
          'startsAt': appointment.startsAt.toIso8601String(),
          'endsAt': appointment.endsAt?.toIso8601String(),
          'location': appointment.location,
          'note': appointment.note,
          'externalCalendarEventId': appointment.externalCalendarEventId,
        },
      );

  DoctorAppointment toEntity() {
    final id = value['id'];
    final title = value['title'];
    final startsAt = value['startsAt'];
    final endsAt = value['endsAt'];
    final location = value['location'];
    final note = value['note'];
    final externalCalendarEventId = value['externalCalendarEventId'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Appointment record has an invalid id.');
    }
    if (title is! String || title.isEmpty) {
      throw const FormatException('Appointment record has an invalid title.');
    }
    if (startsAt is! String) {
      throw const FormatException(
        'Appointment record has an invalid startsAt.',
      );
    }
    if (endsAt != null && endsAt is! String) {
      throw const FormatException('Appointment record has an invalid endsAt.');
    }
    if (location != null && location is! String) {
      throw const FormatException(
        'Appointment record has an invalid location.',
      );
    }
    if (note != null && note is! String) {
      throw const FormatException('Appointment record has an invalid note.');
    }
    if (externalCalendarEventId != null && externalCalendarEventId is! String) {
      throw const FormatException(
        'Appointment record has an invalid externalCalendarEventId.',
      );
    }

    return DoctorAppointment(
      id: id,
      title: title,
      startsAt: DateTime.parse(startsAt),
      endsAt: endsAt == null ? null : DateTime.parse(endsAt as String),
      location: location as String?,
      note: note as String?,
      externalCalendarEventId: externalCalendarEventId as String?,
    );
  }
}
