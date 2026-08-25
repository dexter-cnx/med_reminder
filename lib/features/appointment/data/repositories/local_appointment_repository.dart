import '../../../../core/result/result.dart';
import '../../domain/entities/doctor_appointment.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../datasources/appointment_local_data_source.dart';
import '../models/appointment_record.dart';

class LocalAppointmentRepository implements AppointmentRepository {
  LocalAppointmentRepository(this._dataSource);

  final AppointmentLocalDataSource _dataSource;

  @override
  Result<List<DoctorAppointment>> readAll() {
    try {
      final appointments =
          _dataSource
              .readAppointmentRecords()
              .map(
                (record) => AppointmentRecord(
                  Map<String, dynamic>.from(record),
                ).toEntity(),
              )
              .toList(growable: false)
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return Success<List<DoctorAppointment>>(appointments);
    } catch (error) {
      return Failed<List<DoctorAppointment>>(
        Failure(code: 'appointment_read_failed', message: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> upsert(DoctorAppointment appointment) async {
    try {
      final record = AppointmentRecord.fromEntity(appointment);
      await _dataSource.putAppointmentRecord(appointment.id, record.value);
      return const Success<void>(null);
    } catch (error) {
      return Failed<void>(
        Failure(code: 'appointment_write_failed', message: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _dataSource.deleteAppointmentRecord(id);
      return const Success<void>(null);
    } catch (error) {
      return Failed<void>(
        Failure(code: 'appointment_delete_failed', message: error.toString()),
      );
    }
  }
}
