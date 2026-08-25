import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/appointment/domain/entities/doctor_appointment.dart';
import 'package:med_reminder_offline/features/appointment/domain/repositories/appointment_repository.dart';
import 'package:med_reminder_offline/features/appointment/presentation/providers/appointment_providers.dart';
import 'package:med_reminder_offline/features/timeline/application/build_daily_timeline.dart';
import 'package:med_reminder_offline/features/timeline/domain/entities/timeline_item.dart';

void main() {
  test(
    'appointment provider updates feed the daily timeline projection',
    () async {
      final repository = _MemoryAppointmentRepository();
      final container = ProviderContainer(
        overrides: [
          appointmentRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final appointment = DoctorAppointment(
        id: 'visit-1',
        title: 'Cardiology follow-up',
        startsAt: DateTime(2026, 8, 22, 14, 30),
        location: 'Clinic A',
      );

      final saved = await container
          .read(appointmentsProvider.notifier)
          .upsert(appointment);

      expect(saved, isTrue);
      expect(container.read(appointmentsProvider), <DoctorAppointment>[
        appointment,
      ]);

      final timeline = buildDailyTimeline(
        appointments: container.read(appointmentsProvider),
        day: DateTime(2026, 8, 22),
      );

      expect(timeline, hasLength(1));
      expect(timeline.single, isA<AppointmentTimelineItem>());

      final deleted = await container
          .read(appointmentsProvider.notifier)
          .delete(appointment.id);

      expect(deleted, isTrue);
      expect(container.read(appointmentsProvider), isEmpty);
    },
  );
}

class _MemoryAppointmentRepository implements AppointmentRepository {
  final Map<String, DoctorAppointment> _values = <String, DoctorAppointment>{};

  @override
  Result<List<DoctorAppointment>> readAll() {
    final values = _values.values.toList(growable: false)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return Success<List<DoctorAppointment>>(values);
  }

  @override
  Future<Result<void>> upsert(DoctorAppointment appointment) async {
    _values[appointment.id] = appointment;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _values.remove(id);
    return const Success<void>(null);
  }
}
