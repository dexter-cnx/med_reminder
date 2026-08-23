import '../../../../core/result/result.dart';
import '../../domain/entities/emergency_profile.dart';
import '../../domain/repositories/emergency_profile_repository.dart';
import '../datasources/emergency_profile_local_data_source.dart';
import '../models/emergency_profile_record.dart';

class LocalEmergencyProfileRepository implements EmergencyProfileRepository {
  LocalEmergencyProfileRepository(this._dataSource);

  final EmergencyProfileLocalDataSource _dataSource;

  @override
  Result<EmergencyProfile?> read() {
    try {
      final record = _dataSource.readProfileRecord();
      if (record == null) return const Success<EmergencyProfile?>(null);
      return Success<EmergencyProfile?>(
        EmergencyProfileRecord(Map<String, dynamic>.from(record)).toEntity(),
      );
    } catch (error) {
      return Failed<EmergencyProfile?>(
        Failure(code: 'emergency_profile_read_failed', message: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> save(EmergencyProfile profile) async {
    try {
      final record = EmergencyProfileRecord.fromEntity(profile.normalized());
      await _dataSource.writeProfileRecord(record.value);
      return const Success<void>(null);
    } catch (error) {
      return Failed<void>(
        Failure(code: 'emergency_profile_write_failed', message: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> clear() async {
    try {
      await _dataSource.clearProfileRecord();
      return const Success<void>(null);
    } catch (error) {
      return Failed<void>(
        Failure(code: 'emergency_profile_clear_failed', message: error.toString()),
      );
    }
  }
}
