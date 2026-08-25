import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/backup/presentation/widgets/reminder_repair_card.dart';
import '../features/emergency/presentation/screens/emergency_profile_settings_screen.dart';
import '../features/medication/application/reminder_system_trigger_coordinator.dart';
import '../features/medication/presentation/providers/reminder_reconciliation_providers.dart';
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

  ReminderSystemTriggerCoordinator get _systemReminderTriggers =>
      ReminderSystemTriggerCoordinator(
        refreshTimezoneIfChanged: NotificationService.refreshTimezoneIfChanged,
        requestNotificationPermission:
            NotificationService.requestNotificationPermission,
        requestExactAlarmPermission:
            NotificationService.requestExactAlarmPermission,
        reconcile: ref.read(reminderReconciliationControllerProvider).trigger,
      );

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

  Future<void> _showThemePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _ThemePickerSheet(),
    );
  }

  Future<void> _requestNotifications() async {
    await _runPermissionAction(() async {
      final granted = await _systemReminderTriggers.requestNotifications();
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
      final granted = await _systemReminderTriggers.requestExactAlarm();
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
    final selectedThemeId = ref.watch(appThemeProvider);
    final themeCatalog = ref.watch(appThemeCatalogProvider);
    final selectedTheme = themeCatalog.definitionFor(selectedThemeId);

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _SectionTitle('settings_appearance'.tr()),
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text('settings_theme'.tr()),
            subtitle: Text(selectedTheme.displayName(context.locale)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showThemePicker,
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
        _SectionTitle('emergency_profile_title'.tr()),
        Card(
          child: ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: Text('emergency_edit_title'.tr()),
            subtitle: Text('emergency_local_note'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmergencyProfileSettingsScreen(),
              ),
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
        const ReminderRepairCard(),
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

class _ThemePickerSheet extends ConsumerWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedThemeId = ref.watch(appThemeProvider);
    final catalog = ref.watch(appThemeCatalogProvider);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings_theme'.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'settings_theme_desc'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: catalog.themes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final definition = catalog.themes[index];
                  return _ThemePreviewChoice(
                    definition: definition,
                    previewTheme: catalog.themeFor(definition.id),
                    selected: selectedThemeId == definition.id,
                    onTap: () => ref
                        .read(appThemeProvider.notifier)
                        .select(definition.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewChoice extends StatelessWidget {
  const _ThemePreviewChoice({
    required this.definition,
    required this.previewTheme,
    required this.selected,
    required this.onTap,
  });

  final AppThemeDefinition definition;
  final ThemeData previewTheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outerScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? outerScheme.secondaryContainer
          : outerScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? outerScheme.primary : outerScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      definition.displayName(context.locale),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (definition.id == defaultAppThemeId)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'Default',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  if (selected)
                    Icon(Icons.check_circle, color: outerScheme.primary),
                ],
              ),
              const SizedBox(height: 10),
              _ThemeCodePreview(theme: previewTheme),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeCodePreview extends StatelessWidget {
  const _ThemeCodePreview({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (previewContext) {
          final previewTheme = Theme.of(previewContext);
          final scheme = previewTheme.colorScheme;
          return IgnorePointer(
            child: Container(
              height: 154,
              decoration: BoxDecoration(
                color: previewTheme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: scheme.surface,
                    child: Row(
                      children: [
                        Icon(Icons.favorite, size: 17, color: scheme.primary),
                        const SizedBox(width: 7),
                        Text(
                          'Besyu',
                          style: previewTheme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.notifications_outlined,
                          size: 17,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: scheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.medication_outlined,
                                            size: 18,
                                            color: scheme.onPrimaryContainer,
                                          ),
                                        ),
                                        const Spacer(),
                                        SizedBox(
                                          width: 54,
                                          height: 30,
                                          child: FilledButton(
                                            onPressed: () {},
                                            style: FilledButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(54, 30),
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Container(
                                      height: 7,
                                      width: 84,
                                      decoration: BoxDecoration(
                                        color: scheme.onSurface,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Container(
                                      height: 6,
                                      width: 58,
                                      decoration: BoxDecoration(
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ColorDot(color: scheme.primary),
                              const SizedBox(height: 7),
                              _ColorDot(color: scheme.secondary),
                              const SizedBox(height: 7),
                              _ColorDot(color: scheme.tertiary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
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
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}