import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/emergency/application/build_emergency_medical_card.dart';
import 'package:med_reminder_offline/features/emergency/data/datasources/emergency_profile_local_data_source.dart';
import 'package:med_reminder_offline/features/emergency/data/models/emergency_profile_record.dart';
import 'package:med_reminder_offline/features/emergency/data/repositories/local_emergency_profile_repository.dart';
import 'package:med_reminder_offline/features/emergency/domain/entities/emergency_profile.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';

void main() {
  test('emergency profile record round-trips user-entered fields', () {
    const profile = EmergencyProfile(
      displayName: 'Dexter',
      emergencyContactName: 'Contact',
      emergencyContactPhone: '0812345678',
      medicationAllergies: 'Penicillin',
      medicalNotes: 'User-entered note',
    );

    final decoded = EmergencyProfileRecord.fromEntity(profile).toEntity();

    expect(decoded.displayName, profile.displayName);
    expect(decoded.emergencyContactName, profile.emergencyContactName);
    expect(decoded.emergencyContactPhone, profile.emergencyContactPhone);
    expect(decoded.medicationAllergies, profile.medicationAllergies);
    expect(decoded.medicalNotes, profile.medicalNotes);
  });

  test('repository normalizes fields before persistence', () async {
    final dataSource = _FakeEmergencyProfileLocalDataSource();
    final repository = LocalEmergencyProfileRepository(dataSource);

    final result = await repository.save(
      const EmergencyProfile(
        displayName: '  Dexter  ',
        emergencyContactPhone: '  0812345678  ',
      ),
    );

    expect(result.isSuccess, isTrue);
    final saved = repository.read().fold<EmergencyProfile?>(
          onSuccess: (profile) => profile,
          onFailure: (_) => null,
        );
    expect(saved?.displayName, 'Dexter');
    expect(saved?.emergencyContactPhone, '0812345678');
  });

  test('medical card derives current medication list without copying it', () {
    final now = DateTime(2026, 8, 23);
    final active = Medication(
      id: 'active',
      name: 'Active medicine',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 1),
    );
    final expired = Medication(
      id: 'expired',
      name: 'Expired medicine',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 1),
      mode: MedicationMode.days,
      daysCount: 7,
    );
    const profile = EmergencyProfile(displayName: 'Dexter');

    final card = const BuildEmergencyMedicalCard()(
      now: now,
      profile: profile,
      medications: <Medication>[expired, active],
    );

    expect(card.profile, same(profile));
    expect(card.currentMedications.map((item) => item.id), <String>['active']);
  });
}

class _FakeEmergencyProfileLocalDataSource
    implements EmergencyProfileLocalDataSource {
  Map<String, dynamic>? record;

  @override
  Future<void> clearProfileRecord() async {
    record = null;
  }

  @override
  Map<dynamic, dynamic>? readProfileRecord() => record;

  @override
  Future<void> writeProfileRecord(Map<String, dynamic> value) async {
    record = Map<String, dynamic>.from(value);
  }
}
