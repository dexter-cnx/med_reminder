import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../medication/domain/entities/medication.dart';
import '../../domain/entities/emergency_profile.dart';
import '../providers/emergency_profile_providers.dart';
import '../widgets/sos_action_sheet.dart';
import 'emergency_profile_settings_screen.dart';

class EmergencyMedicalCardScreen extends ConsumerWidget {
  const EmergencyMedicalCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(emergencyProfileProvider);
    final card = ref.watch(emergencyMedicalCardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('emergency_card_title'.tr()),
        actions: [
          IconButton(
            tooltip: 'emergency_edit_title'.tr(),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmergencyProfileSettingsScreen(),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          TextButton.icon(
            onPressed: () => showSosActionSheet(context),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('SOS'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    profile == null || profile.isEmpty
                        ? 'emergency_profile_empty'.tr()
                        : (profile.displayName.isEmpty
                            ? 'emergency_profile_title'.tr()
                            : profile.displayName),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('emergency_card_disclaimer'.tr()),
                  const SizedBox(height: 16),
                  _ReadOnlyField(
                    label: 'emergency_contact'.tr(),
                    value: _joinContact(profile),
                  ),
                  _ReadOnlyField(
                    label: 'emergency_medication_allergies'.tr(),
                    value: profile?.medicationAllergies ?? '',
                  ),
                  _ReadOnlyField(
                    label: 'emergency_medical_notes'.tr(),
                    value: profile?.medicalNotes ?? '',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'emergency_current_medications'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (card.currentMedications.isEmpty)
                    Text('emergency_no_current_medications'.tr())
                  else
                    ...card.currentMedications.map(_MedicationSummary.new),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _joinContact(EmergencyProfile? profile) {
    if (profile == null) return '';
    return <String>[
      profile.emergencyContactName,
      profile.emergencyContactPhone,
    ].where((value) => value.isNotEmpty).join(' · ');
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value),
        ],
      ),
    );
  }
}

class _MedicationSummary extends StatelessWidget {
  const _MedicationSummary(this.medication);

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.medication_outlined),
      title: Text(medication.name),
      subtitle:
          medication.genericName.isEmpty ? null : Text(medication.genericName),
    );
  }
}
