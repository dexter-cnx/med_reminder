import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/emergency_profile.dart';
import '../providers/emergency_profile_providers.dart';

class EmergencyProfileSettingsScreen extends ConsumerStatefulWidget {
  const EmergencyProfileSettingsScreen({super.key});

  @override
  ConsumerState<EmergencyProfileSettingsScreen> createState() =>
      _EmergencyProfileSettingsScreenState();
}

class _EmergencyProfileSettingsScreenState
    extends ConsumerState<EmergencyProfileSettingsScreen> {
  final _displayName = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  final _allergies = TextEditingController();
  final _medicalNotes = TextEditingController();
  EmergencyProfile? _lastLoadedProfile;
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
    if (_initialized && identical(profile, _lastLoadedProfile)) return;
    if (_initialized && _lastLoadedProfile == null && profile != null) {
      _loadControllers(profile);
      _lastLoadedProfile = profile;
      return;
    }
    if (_initialized) return;
    _initialized = true;
    _lastLoadedProfile = profile;
    _loadControllers(profile);
  }

  void _loadControllers(EmergencyProfile? profile) {
    _displayName.text = profile?.displayName ?? '';
    _contactName.text = profile?.emergencyContactName ?? '';
    _contactPhone.text = profile?.emergencyContactPhone ?? '';
    _allergies.text = profile?.medicationAllergies ?? '';
    _medicalNotes.text = profile?.medicalNotes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(emergencyProfileProvider);
    _initializeFrom(profile);

    return Scaffold(
      appBar: AppBar(title: Text('emergency_edit_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
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
      _loadControllers(null);
      _lastLoadedProfile = null;
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
