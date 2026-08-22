import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/appointment/data/datasources/appointment_local_data_source.dart';
import 'package:med_reminder_offline/features/appointment/data/repositories/local_appointment_repository.dart';
import 'package:med_reminder_offline/features/appointment/domain/entities/doctor_appointment.dart';
import 'package:med_reminder_offline/features/timeline/application/build_daily_timeline.dart';
import 'package:med_reminder_offline/features/timeline/domain/entities/timeline_item.dart';

void main() {
  test('appointment repository persists and sorts by start time', () async {
    final dataSource = _MemoryAppointmentDataSource();
    final repository = LocalAppointmentRepository(dataSource);
    final later = DoctorAppointment(
      id: 'later',
      title: 'Follow-up',
      startsAt: DateTime(2026, 8, 22, 15),
    );
    final earlier = DoctorAppointment(
      id: 'earlier',
      title: 'Clinic visit',
      startsAt: DateTime(2026, 8, 22, 9),
      location: 'Clinic A',
      note: 'Bring medication list',
    );

    expect(await repository.upsert(later), isNotNull);
    expect(await repository.upsert(earlier), isNotNull);

    final appointments = repository.readAll().fold(
          onSuccess: (items) => items,
          onFailure: (failure) => throw StateError(failure.message),
        );

    expect(appointments.map((item) => item.id), <String>['earlier', 'later']);
    expect(appointments.first.location, 'Clinic A');
    expect(appointments.first.note, 'Bring medication list');
  });

  test('daily timeline projects only appointments for the requested day', () {
    final today = DoctorAppointment(
      id: 'today',
      title: 'Doctor appointment',
      startsAt: DateTime(2026, 8, 22, 10, 30),
    );
    final tomorrow = DoctorAppointment(
      id: 'tomorrow',
      title: 'Tomorrow appointment',
      startsAt: DateTime(2026, 8, 23, 9),
    );

    final items = buildDailyTimeline(
      appointments: <DoctorAppointment>[today, tomorrow],
      day: DateTime(2026, 8, 22),
    );

    expect(items, hasLength(1));
    final item = items.single as AppointmentTimelineItem;
    expect(item.appointment.id, 'today');
    expect(item.at, DateTime(2026, 8, 22, 10, 30));
  });
}

class _MemoryAppointmentDataSource implements AppointmentLocalDataSource {
  final Map<String, Map<String, dynamic>> values =
      <String, Map<String, dynamic>>{};

  @override
  List<Map<dynamic, dynamic>> readAppointmentRecords() => values.values
      .map<Map<dynamic, dynamic>>((value) => Map<dynamic, dynamic>.from(value))
      .toList(growable: false);

  @override
  Future<void> putAppointmentRecord(
    String id,
    Map<String, dynamic> record,
  ) async {
    values[id] = Map<String, dynamic>.from(record);
  }

  @override
  Future<void> deleteAppointmentRecord(String id) async {
    values.remove(id);
  }
}
