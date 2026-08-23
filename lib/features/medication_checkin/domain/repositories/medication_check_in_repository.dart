import '../../../../core/result/result.dart';
import '../entities/medication_check_in.dart';

abstract interface class MedicationCheckInRepository {
  Result<List<MedicationCheckIn>> readAll();
  Future<Result<void>> append(MedicationCheckIn checkIn);
}
