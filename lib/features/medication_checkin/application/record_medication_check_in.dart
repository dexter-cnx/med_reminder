import 'package:uuid/uuid.dart';

import '../../../../core/result/result.dart';
import '../domain/entities/medication_check_in.dart';
import '../domain/repositories/medication_check_in_repository.dart';

class RecordMedicationCheckIn {
  RecordMedicationCheckIn(
    this._repository, {
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
  })  : _uuid = uuid,
        _now = now ?? DateTime.now;

  final MedicationCheckInRepository _repository;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<Result<MedicationCheckIn>> call({
    required String medicationId,
    required MedicationCheckInKind kind,
    String note = '',
  }) async {
    final checkIn = MedicationCheckIn(
      id: _uuid.v4(),
      medicationId: medicationId,
      recordedAt: _now(),
      kind: kind,
      note: note.trim(),
    );

    final result = await _repository.append(checkIn);
    return result.fold(
      onSuccess: (_) => Success<MedicationCheckIn>(checkIn),
      onFailure: Failed<MedicationCheckIn>.new,
    );
  }
}
