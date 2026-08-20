import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/app_settings_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

const _profileAgeKey = 'profile_age';
const _profileSexKey = 'profile_sex';
const _languageCodeKey = 'language_code';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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

  Future<void> _setLanguage(String languageCode) async {
    await _settings.put(_languageCodeKey, languageCode);
    if (!mounted || languageCode == context.locale.languageCode) return;
    await context.setLocale(Locale(languageCode));
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
    final languageCode = context.locale.languageCode == 'th' ? 'th' : 'en';
    final selectedTheme = ref.watch(appThemeProvider);
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _SectionTitle('settings_appearance'.tr()),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'settings_theme'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'settings_theme_desc'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ...AppThemeId.values.map(
                  (themeId) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ThemeChoice(
                      themeId: themeId,
                      selected: selectedTheme == themeId,
                      onTap: () =>
                          ref.read(appThemeProvider.notifier).select(themeId),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle('settings_language'.tr()),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>('language-$languageCode'),
              initialValue: languageCode,
              decoration: InputDecoration(
                labelText: 'settings_language'.tr(),
                helperText: 'settings_language_desc'.tr(),
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: 'en',
                  child: Text('settings_language_english'.tr()),
                ),
                DropdownMenuItem(
                  value: 'th',
                  child: Text('settings_language_thai'.tr()),
                ),
              ],
              onChanged: (value) {
                if (value != null) _setLanguage(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
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
                leading: const Icon(Icons.favorite_outline),
                title: const Text('Besyu'),
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
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text('settings_title'.tr())),
      body: content,
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

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.themeId,
    required this.selected,
    required this.onTap,
  });

  final AppThemeId themeId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewTheme = AppThemeCatalog.themeFor(themeId);
    final scheme = previewTheme.colorScheme;
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_themeLabel(themeId).tr())),
              if (selected) const Icon(Icons.check_circle),
            ],
          ),
        ),
      ),
    );
  }

  String _themeLabel(AppThemeId id) {
    switch (id) {
      case AppThemeId.besyuBlue:
        return 'theme_besyu_blue';
      case AppThemeId.warmSand:
        return 'theme_warm_sand';
      case AppThemeId.sageCare:
        return 'theme_sage_care';
      case AppThemeId.lavenderCalm:
        return 'theme_lavender_calm';
      case AppThemeId.midnight:
        return 'theme_midnight';
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
