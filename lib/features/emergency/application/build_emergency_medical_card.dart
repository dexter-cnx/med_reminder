import '../../medication/domain/entities/medication.dart';
import '../../refill/application/calculate_remaining_stock.dart';
import '../../refill/domain/entities/refill_event.dart';
import '../domain/entities/emergency_profile.dart';

class EmergencyMedicalCard {
  const EmergencyMedicalCard({
    required this.generatedAt,
    required this.profile,
    required this.currentMedications,
  });

  final DateTime generatedAt;
  final EmergencyProfile? profile;
  final List<Medication> currentMedications;
}

class BuildEmergencyMedicalCard {
  const BuildEmergencyMedicalCard();

  EmergencyMedicalCard call({
    required DateTime now,
    required EmergencyProfile? profile,
    required Iterable<Medication> medications,
    Iterable<DoseLog> doseLogs = const <DoseLog>[],
    Iterable<RefillEvent> refillEvents = const <RefillEvent>[],
  }) {
    bool isCurrent(Medication medication) {
      if (medication.isExpired(now)) return false;
      if (medication.mode != MedicationMode.untilEmpty) return true;

      final remaining = calculateRemainingStock(
        medication: medication,
        doseLogs: doseLogs,
        refillEvents: refillEvents,
      );
      return remaining != 0;
    }

    final currentMedications =
        medications.where(isCurrent).toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return EmergencyMedicalCard(
      generatedAt: now,
      profile: profile,
      currentMedications: List<Medication>.unmodifiable(currentMedications),
    );
  }
}
