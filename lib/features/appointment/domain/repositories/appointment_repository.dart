import '../../../../core/result/result.dart';
import '../entities/doctor_appointment.dart';

abstract interface class AppointmentRepository {
  Result<List<DoctorAppointment>> readAll();
  Future<Result<void>> upsert(DoctorAppointment appointment);
  Future<Result<void>> delete(String id);
}
