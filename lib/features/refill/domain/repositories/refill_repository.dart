import '../../../../core/result/result.dart';
import '../entities/refill_event.dart';

abstract interface class RefillRepository {
  Result<List<RefillEvent>> readAll();
  Future<Result<void>> append(RefillEvent event);
}
