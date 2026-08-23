import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../medication/domain/entities/medication.dart';
import '../providers/emergency_profile_providers.dart';
import '../../domain/entities/emergency_profile.dart';

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
      appBar: AppBar(title: const Text('Emergency Medical Card')),
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
                        ? 'No emergency profile saved yet'
                        : (profile.displayName.isEmpty
                            ? 'Emergency profile'
                            : profile.displayName),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This card shows only information you entered and current medication records from Besyu. It does not diagnose conditions.',
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyField(
                    label: 'Emergency contact',
                    value: _joinContact(profile),
                  ),
                  _ReadOnlyField(
                    label: 'Medication allergies',
                    value: profile?.medicationAllergies ?? '',
                  ),
                  _ReadOnlyField(
                    label: 'Medical notes',
                    value: profile?.medicalNotes ?? '',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Current medications',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (card.currentMedications.isEmpty)
                    const Text('No current medication records')
                  else
                    ...card.currentMedications.map(_MedicationSummary.new),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Edit emergency information',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactName,
            decoration:
                const InputDecoration(labelText: 'Emergency contact name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactPhone,
            keyboardType: TextInputType.phone,
            decoration:
                const InputDecoration(labelText: 'Emergency contact phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _allergies,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Medication allergies',
              helperText: 'Enter only information you know or were told.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _medicalNotes,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Medical notes',
              helperText:
                  'Optional user-entered notes. Besyu does not infer diagnoses.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save on this device'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy || profile == null ? null : _confirmClear,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear emergency information'),
          ),
          const SizedBox(height: 8),
          Text(
            'Emergency information stays on this device. Clearing it does not delete medication records.',
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
        content: Text(saved
            ? 'Emergency information saved on this device'
            : 'Unable to save emergency information'),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear emergency information?'),
        content: const Text(
          'This removes the emergency profile from this device. Medication records are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
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
        content: Text(cleared
            ? 'Emergency information cleared'
            : 'Unable to clear emergency information'),
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
