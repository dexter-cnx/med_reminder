import '../../../../core/result/result.dart';
import '../../domain/entities/medication_check_in.dart';
import '../../domain/repositories/medication_check_in_repository.dart';
import '../datasources/medication_check_in_local_data_source.dart';
import '../models/medication_check_in_record.dart';

class LocalMedicationCheckInRepository implements MedicationCheckInRepository {
  LocalMedicationCheckInRepository(this._dataSource);

  final MedicationCheckInLocalDataSource _dataSource;

  @override
  Result<List<MedicationCheckIn>> readAll() {
    try {
      final items = _dataSource
          .readCheckInRecords()
          .map(
            (record) => MedicationCheckInRecord(
              Map<String, dynamic>.from(record),
            ).toEntity(),
          )
          .toList(growable: false)
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      return Success<List<MedicationCheckIn>>(items);
    } catch (error) {
      return Failed<List<MedicationCheckIn>>(
        Failure(code: 'checkin_read_failed', message: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> append(MedicationCheckIn checkIn) async {
    try {
      final record = MedicationCheckInRecord.fromEntity(checkIn);
      await _dataSource.putCheckInRecord(checkIn.id, record.value);
      return const Success<void>(null);
    } catch (error) {
      return Failed<void>(
        Failure(code: 'checkin_write_failed', message: error.toString()),
      );
    }
  }
}
