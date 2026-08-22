import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/medication_check_in.dart';
import '../../domain/repositories/medication_check_in_repository.dart';

final medicationCheckInRepositoryProvider = Provider<MedicationCheckInRepository>(
  (ref) => throw UnimplementedError(
    'MedicationCheckInRepository must be provided by app DI.',
  ),
);

final medicationCheckInFailureProvider = StateProvider<Failure?>((ref) => null);

final medicationCheckInsProvider =
    StateNotifierProvider<MedicationCheckInViewModel, List<MedicationCheckIn>>(
  (ref) => MedicationCheckInViewModel(
    ref.watch(medicationCheckInRepositoryProvider),
    onFailure: (failure) {
      Future<void>.microtask(() {
        ref.read(medicationCheckInFailureProvider.notifier).state = failure;
      });
    },
  ),
);

class MedicationCheckInViewModel extends StateNotifier<List<MedicationCheckIn>> {
  MedicationCheckInViewModel(
    MedicationCheckInRepository repository, {
    required void Function(Failure failure) onFailure,
  })  : _repository = repository,
        _onFailure = onFailure,
        super(_load(repository, onFailure));

  final MedicationCheckInRepository _repository;
  final void Function(Failure failure) _onFailure;

  static List<MedicationCheckIn> _load(
    MedicationCheckInRepository repository,
    void Function(Failure failure) onFailure,
  ) =>
      repository.readAll().fold(
            onSuccess: (items) => List<MedicationCheckIn>.unmodifiable(items),
            onFailure: (failure) {
              onFailure(failure);
              return const <MedicationCheckIn>[];
            },
          );

  Future<bool> append(MedicationCheckIn checkIn) async {
    final result = await _repository.append(checkIn);
    return result.fold(
      onSuccess: (_) {
        final next = <MedicationCheckIn>[...state, checkIn]
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
        state = List<MedicationCheckIn>.unmodifiable(next);
        return true;
      },
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }
}
