import '../../../../core/result/result.dart';
import '../entities/emergency_profile.dart';

abstract interface class EmergencyProfileRepository {
  Result<EmergencyProfile?> read();
  Future<Result<void>> save(EmergencyProfile profile);
  Future<Result<void>> clear();
}
