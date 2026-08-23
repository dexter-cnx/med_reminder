import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../application/query_medication_check_ins.dart';
import '../../application/record_medication_check_in.dart';
import '../../domain/entities/medication_check_in.dart';
import '../../domain/repositories/medication_check_in_repository.dart';

final medicationCheckInRepositoryProvider =
    Provider<MedicationCheckInRepository>(
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

final medicationCheckInsForProvider =
    Provider.family<List<MedicationCheckIn>, String>((ref, medicationId) {
  final items = ref.watch(medicationCheckInsProvider);
  return const QueryMedicationCheckIns()(
    checkIns: items,
    medicationId: medicationId,
  );
});

class MedicationCheckInViewModel
    extends StateNotifier<List<MedicationCheckIn>> {
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

  Future<bool> record({
    required String medicationId,
    required MedicationCheckInKind kind,
    String note = '',
  }) async {
    final result = await RecordMedicationCheckIn(_repository)(
      medicationId: medicationId,
      kind: kind,
      note: note,
    );
    return result.fold(
      onSuccess: (checkIn) {
        _replaceInState(checkIn);
        return true;
      },
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }

  Future<bool> append(MedicationCheckIn checkIn) async {
    final result = await _repository.append(checkIn);
    return result.fold(
      onSuccess: (_) {
        _replaceInState(checkIn);
        return true;
      },
      onFailure: (failure) {
        _onFailure(failure);
        return false;
      },
    );
  }

  void _replaceInState(MedicationCheckIn checkIn) {
    final next = <MedicationCheckIn>[
      ...state.where((item) => item.id != checkIn.id),
      checkIn,
    ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    state = List<MedicationCheckIn>.unmodifiable(next);
  }
}
