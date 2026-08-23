class EmergencyProfile {
  const EmergencyProfile({
    this.displayName = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.medicationAllergies = '',
    this.medicalNotes = '',
  });

  final String displayName;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String medicationAllergies;
  final String medicalNotes;

  bool get isEmpty =>
      displayName.isEmpty &&
      emergencyContactName.isEmpty &&
      emergencyContactPhone.isEmpty &&
      medicationAllergies.isEmpty &&
      medicalNotes.isEmpty;

  EmergencyProfile normalized() => EmergencyProfile(
        displayName: displayName.trim(),
        emergencyContactName: emergencyContactName.trim(),
        emergencyContactPhone: emergencyContactPhone.trim(),
        medicationAllergies: medicationAllergies.trim(),
        medicalNotes: medicalNotes.trim(),
      );
}
