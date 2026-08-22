import '../entities/doctor_appointment.dart';

/// Optional bridge to a platform calendar.
///
/// Appointment persistence remains local and independent of the device
/// calendar. Implementations must only write after an explicit user action.
abstract interface class AppointmentCalendarGateway {
  Future<String?> upsert(DoctorAppointment appointment);
  Future<void> deleteExternalEvent(String externalEventId);
}
