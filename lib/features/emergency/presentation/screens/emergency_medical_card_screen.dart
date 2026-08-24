import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../medication/domain/entities/medication.dart';
import '../../domain/entities/emergency_profile.dart';
import '../providers/emergency_profile_providers.dart';
import '../widgets/sos_action_sheet.dart';

class EmergencyMedicalCardScreen extends ConsumerStatefulWidget {
  const EmergencyMedicalCardScreen({super.key});

  @override
  ConsumerState<EmergencyMedicalCardScreen> createState() =>
      _EmergencyMedicalCardScreenState();
}

class _EmergencyMedicalCardScreenState
    extends ConsumerState<EmergencyMedicalCardScreen> {
  final _displayName = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _allergies = TextEditingController();
  final _medicalNotes = TextEditingController();
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _displayName.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _allergies.dispose();
    _medicalNotes.dispose();
    super.dispose();
  }

  void _initializeFrom(EmergencyProfile? profile) {
    if (_initialized) return;
    _initialized = true;
    _displayName.text = profile?.displayName ?? '';
    _contactName.text = profile?.emergencyContactName ?? '';
    _contactPhone.text = profile?.emergencyContactPhone ?? '';
    _allergies.text = profile?.medicationAllergies ?? '';
    _medicalNotes.text = profile?.medicalNotes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(emergencyProfileProvider);
    final card = ref.watch(emergencyMedicalCardProvider);
    _initializeFrom(profile);

    return Scaffold(
      appBar: AppBar(
        title: Text('emergency_card_title'.tr()),
        actions: [
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
          const SizedBox(height: 20),
          Text(
            'emergency_edit_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _displayName,
            decoration: InputDecoration(
              labelText: 'emergency_display_name'.tr(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactName,
            decoration: InputDecoration(
              labelText: 'emergency_contact_name'.tr(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactPhone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'emergency_contact_phone'.tr(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _allergies,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'emergency_medication_allergies'.tr(),
              helperText: 'emergency_allergies_helper'.tr(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medicalNotes,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'emergency_medical_notes'.tr(),
              helperText: 'emergency_notes_helper'.tr(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text('emergency_save'.tr()),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy || profile == null ? null : _confirmClear,
            icon: const Icon(Icons.delete_outline),
            label: Text('emergency_clear'.tr()),
          ),
          const SizedBox(height: 8),
          Text(
            'emergency_local_note'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
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

  Future<void> _save() async {
    setState(() => _busy = true);
    final saved = await ref.read(emergencyProfileProvider.notifier).save(
          EmergencyProfile(
            displayName: _displayName.text,
            emergencyContactName: _contactName.text,
            emergencyContactPhone: _contactPhone.text,
            medicationAllergies: _allergies.text,
            medicalNotes: _medicalNotes.text,
          ),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (saved ? 'emergency_saved' : 'emergency_save_failed').tr(),
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('emergency_clear_confirm_title'.tr()),
        content: Text('emergency_clear_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('emergency_clear_action'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final cleared = await ref.read(emergencyProfileProvider.notifier).clear();
    if (!mounted) return;
    if (cleared) {
      _displayName.clear();
      _contactName.clear();
      _contactPhone.clear();
      _allergies.clear();
      _medicalNotes.clear();
    }
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (cleared ? 'emergency_cleared' : 'emergency_clear_failed').tr(),
        ),
      ),
    );
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
