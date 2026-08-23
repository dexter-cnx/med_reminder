import '../../appointment/domain/entities/doctor_appointment.dart';
import '../../medication/domain/entities/dose_log.dart';
import '../../medication/domain/entities/medication.dart';
import '../../medication_checkin/domain/entities/medication_check_in.dart';
import '../../refill/domain/entities/refill_event.dart';
import '../domain/entities/doctor_visit_summary.dart';

class BuildDoctorVisitSummary {
  const BuildDoctorVisitSummary({this.window = const Duration(days: 30)});

  final Duration window;

  DoctorVisitSummary call({
    required DateTime now,
    required List<Medication> medications,
    required List<DoseLog> doseLogs,
    required List<RefillEvent> refillEvents,
    required List<MedicationCheckIn> checkIns,
    required List<DoctorAppointment> appointments,
  }) {
    final periodEnd = now;
    final periodStart = now.subtract(window);

    bool inPeriod(DateTime value) =>
        !value.isBefore(periodStart) && !value.isAfter(periodEnd);

    final medicationSummaries = medications.map((medication) {
      final medicationLogs = doseLogs.where(
        (log) => log.medId == medication.id && inPeriod(log.scheduledAt),
      );
      final medicationRefills = refillEvents.where(
        (event) =>
            event.medicationId == medication.id && inPeriod(event.createdAt),
      );
      final medicationCheckIns = checkIns
          .where(
            (checkIn) =>
                checkIn.medicationId == medication.id &&
                inPeriod(checkIn.recordedAt),
          )
          .toList(growable: false)
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

      return DoctorVisitMedicationSummary(
        medication: medication,
        takenCount:
            medicationLogs.where((log) => log.status == DoseStatus.taken).length,
        skippedCount: medicationLogs
            .where((log) => log.status == DoseStatus.skipped)
            .length,
        refillQuantity: medicationRefills.fold<int>(
          0,
          (total, event) => total + event.quantity,
        ),
        checkIns: List<MedicationCheckIn>.unmodifiable(medicationCheckIns),
      );
    }).toList(growable: false)
      ..sort(
        (a, b) => a.medication.name.toLowerCase().compareTo(
              b.medication.name.toLowerCase(),
            ),
      );

    final upcomingAppointments = appointments
        .where((appointment) => !appointment.startsAt.isBefore(now))
        .toList(growable: false)
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return DoctorVisitSummary(
      generatedAt: now,
      periodStart: periodStart,
      periodEnd: periodEnd,
      medications: List<DoctorVisitMedicationSummary>.unmodifiable(
        medicationSummaries,
      ),
      upcomingAppointments: List<DoctorAppointment>.unmodifiable(
        upcomingAppointments,
      ),
    );
  }
}
