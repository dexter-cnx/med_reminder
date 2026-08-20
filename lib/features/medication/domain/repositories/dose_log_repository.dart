import '../../../../core/result/result.dart';
import '../entities/dose_log.dart';

abstract interface class DoseLogRepository {
  Result<List<DoseLog>> readAll();
  Future<Result<void>> replaceAll(List<DoseLog> logs);
}
