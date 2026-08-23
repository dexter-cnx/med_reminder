import '../../../appointment/domain/entities/doctor_appointment.dart';
import '../../../medication/domain/entities/medication.dart';
import '../../../medication_checkin/domain/entities/medication_check_in.dart';

class DoctorVisitSummary {
  const DoctorVisitSummary({
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.medications,
    required this.upcomingAppointments,
  });

  final DateTime generatedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<DoctorVisitMedicationSummary> medications;
  final List<DoctorAppointment> upcomingAppointments;
}

class DoctorVisitMedicationSummary {
  const DoctorVisitMedicationSummary({
    required this.medication,
    required this.takenCount,
    required this.skippedCount,
    required this.refillQuantity,
    required this.checkIns,
  });

  final Medication medication;
  final int takenCount;
  final int skippedCount;
  final int refillQuantity;
  final List<MedicationCheckIn> checkIns;
}
