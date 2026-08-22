import '../../../../core/result/result.dart';
import '../../domain/entities/refill_event.dart';
import '../../domain/repositories/refill_repository.dart';
import '../datasources/refill_local_data_source.dart';
import '../models/refill_record.dart';

class LocalRefillRepository implements RefillRepository {
  LocalRefillRepository(this._dataSource);

  final RefillLocalDataSource _dataSource;

  @override
  Result<List<RefillEvent>> readAll() {
    try {
      final events = _dataSource
          .readRefillRecords()
          .map(
            (record) =>
                RefillRecord(Map<String, dynamic>.from(record)).toEntity(),
          )
          .toList(growable: false)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return Success<List<RefillEvent>>(events);
    } catch (error) {
      return Failed<List<RefillEvent>>(
        Failure(code: 'refill_read_failed', message: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> append(RefillEvent event) async {
    try {
      final record = RefillRecord.fromEntity(event);
      await _dataSource.putRefillRecord(event.id, record.value);
      return const Success<void>(null);
    } catch (error) {
      return Failed<void>(
        Failure(code: 'refill_write_failed', message: error.toString()),
      );
    }
  }
}
