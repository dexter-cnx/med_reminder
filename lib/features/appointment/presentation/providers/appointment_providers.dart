import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/doctor_appointment.dart';
import '../../domain/repositories/appointment_repository.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => throw UnimplementedError(
    'AppointmentRepository must be provided by app DI.',
  ),
);

final appointmentFailureProvider = StateProvider<Failure?>((ref) => null);

final appointmentsProvider =
    StateNotifierProvider<AppointmentViewModel, List<DoctorAppointment>>(
  (ref) => AppointmentViewModel(
    ref.watch(appointmentRepositoryProvider),
    onFailure: (failure) {
      Future<void>.microtask(() {
        ref.read(appointmentFailureProvider.notifier).state = failure;
      });
    },
  ),
);

class AppointmentViewModel extends StateNotifier<List<DoctorAppointment>> {
  AppointmentViewModel(
    AppointmentRepository repository, {
    required void Function(Failure failure) onFailure,
  })  : _repository = repository,
        _onFailure = onFailure,
        super(_load(repository, onFailure));

  final AppointmentRepository _repository;
  final void Function(Failure failure) _onFailure;

  static List<DoctorAppointment> _load(
    AppointmentRepository repository,
    void Function(Failure failure) onFailure,
  ) =>
      repository.readAll().fold(
            onSuccess: (items) => List<DoctorAppointment>.unmodifiable(items),
            onFailure: (failure) {
              onFailure(failure);
              return const <DoctorAppointment>[];
            },
          );

  Future<bool> upsert(DoctorAppointment appointment) async {
    final result = await _repository.upsert(appointment);
    return result.fold(
      onSuccess: (_) {
        final next = <DoctorAppointment>[
          ...state.where((item) => item.id != appointment.id),
          appointment,
        ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        state = List<DoctorAppointment>.unmodifiable(next);
        return true;
      },
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }

  Future<bool> delete(String id) async {
    final result = await _repository.delete(id);
    return result.fold(
      onSuccess: (_) {
        state = List<DoctorAppointment>.unmodifiable(
          state.where((item) => item.id != id),
        );
        return true;
      },
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }
}
