import '../../medication/domain/entities/medication.dart';
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
  }) {
    final currentMedications = medications
        .where((medication) => medication.isActiveOn(now))
        .toList(growable: false)
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
