import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/app_settings_service.dart';
import '../services/notification_service.dart';

const _profileAgeKey = 'profile_age';
const _profileSexKey = 'profile_sex';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ageController = TextEditingController();
  String _sex = 'not_specified';
  bool _savingProfile = false;
  bool _permissionBusy = false;

  Box<dynamic> get _settings => Hive.box<dynamic>('settings');

  @override
  void initState() {
    super.initState();
    final age = _settings.get(_profileAgeKey);
    if (age is int) _ageController.text = age.toString();
    final sex = _settings.get(_profileSexKey);
    if (sex is String && _sexValues.contains(sex)) _sex = sex;
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    final rawAge = _ageController.text.trim();
    final age = rawAge.isEmpty ? null : int.tryParse(rawAge);
    if (rawAge.isNotEmpty && (age == null || age < 1 || age > 120)) {
      _showMessage('settings_age_invalid'.tr());
      return;
    }

    setState(() => _savingProfile = true);
    try {
      if (age == null) {
        await _settings.delete(_profileAgeKey);
      } else {
        await _settings.put(_profileAgeKey, age);
      }
      await _settings.put(_profileSexKey, _sex);
      if (mounted) _showMessage('settings_profile_saved'.tr());
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _requestNotifications() async {
    await _runPermissionAction(() async {
      final granted = await NotificationService.requestNotificationPermission();
      if (!mounted) return;
      _showMessage(
        (granted
                ? 'onboarding_permission_enabled'
                : 'onboarding_permission_not_enabled')
            .tr(),
      );
    });
  }

  Future<void> _requestExactAlarm() async {
    await _runPermissionAction(() async {
      final granted = await NotificationService.requestExactAlarmPermission();
      if (!mounted) return;
      _showMessage(
        (granted
                ? 'onboarding_permission_enabled'
                : 'onboarding_permission_not_enabled')
            .tr(),
      );
    });
  }

  Future<void> _openAppSettings() async {
    await _runPermissionAction(() async {
      final opened = await AppSettingsService.open();
      if (!opened && mounted) _showMessage('settings_open_failed'.tr());
    });
  }

  Future<void> _runPermissionAction(Future<void> Function() action) async {
    if (_permissionBusy) return;
    setState(() => _permissionBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _permissionBusy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionTitle('settings_profile'.tr()),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'settings_age'.tr(),
                      helperText: 'settings_age_optional'.tr(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _sex,
                    decoration: InputDecoration(labelText: 'settings_sex'.tr()),
                    items: _sexValues
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(_sexLabel(value).tr()),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setState(() => _sex = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _savingProfile ? null : _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: Text('settings_save_profile'.tr()),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'settings_profile_local'.tr(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('settings_permissions'.tr()),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text('settings_notifications'.tr()),
                  subtitle: Text('settings_notifications_desc'.tr()),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !_permissionBusy,
                  onTap: _requestNotifications,
                ),
                if (Platform.isAndroid) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.alarm_outlined),
                    title: Text('settings_precise_reminders'.tr()),
                    subtitle: Text('settings_precise_reminders_desc'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !_permissionBusy,
                    onTap: _requestExactAlarm,
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text('settings_camera_photos'.tr()),
                  subtitle: Text('settings_camera_photos_desc'.tr()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text('settings_system_permissions'.tr()),
                  subtitle: Text('settings_system_permissions_desc'.tr()),
                  trailing: const Icon(Icons.open_in_new),
                  enabled: !_permissionBusy,
                  onTap: _openAppSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('settings_about'.tr()),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.medication_outlined),
                  title: const Text('Med Reminder'),
                  subtitle: Text('settings_about_desc'.tr()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text('settings_version'.tr()),
                  trailing: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: Text('settings_offline_title'.tr()),
                  subtitle: Text('settings_offline_desc'.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sexLabel(String value) {
    switch (value) {
      case 'female':
        return 'settings_sex_female';
      case 'male':
        return 'settings_sex_male';
      case 'other':
        return 'settings_sex_other';
      default:
        return 'settings_sex_not_specified';
    }
  }
}

const _sexValues = <String>['not_specified', 'female', 'male', 'other'];

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
