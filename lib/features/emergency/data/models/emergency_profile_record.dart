import '../../domain/entities/emergency_profile.dart';

class EmergencyProfileRecord {
  const EmergencyProfileRecord(this.value);

  factory EmergencyProfileRecord.fromEntity(EmergencyProfile profile) =>
      EmergencyProfileRecord(<String, dynamic>{
        'displayName': profile.displayName,
        'emergencyContactName': profile.emergencyContactName,
        'emergencyContactPhone': profile.emergencyContactPhone,
        'medicationAllergies': profile.medicationAllergies,
        'medicalNotes': profile.medicalNotes,
      });

  final Map<String, dynamic> value;

  EmergencyProfile toEntity() => EmergencyProfile(
        displayName: value['displayName'] as String? ?? '',
        emergencyContactName: value['emergencyContactName'] as String? ?? '',
        emergencyContactPhone: value['emergencyContactPhone'] as String? ?? '',
        medicationAllergies: value['medicationAllergies'] as String? ?? '',
        medicalNotes: value['medicalNotes'] as String? ?? '',
      );
}
