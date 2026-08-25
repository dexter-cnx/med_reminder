import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../features/appointment/presentation/screens/appointment_screen.dart';
import '../features/emergency/presentation/screens/emergency_medical_card_screen.dart';
import '../features/emergency/presentation/widgets/sos_action_sheet.dart';
import '../features/medication/presentation/providers/reminder_reconciliation_providers.dart';
import '../features/medication_checkin/presentation/widgets/medication_check_in_panel.dart';
import '../features/refill/presentation/widgets/refill_panel.dart';
import '../models/medication.dart';
import '../providers/meds_provider.dart';
import '../providers/timeline_provider.dart';
import '../services/live_activity_service.dart';
import '../services/notification_service.dart';
import '../services/photo_service.dart';
import '../services/watch_sync_service.dart';
import 'settings_screen.dart';
import 'widgets/daily_timeline_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  var _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reconcileReminders());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcileReminders());
    }
  }

  Future<void> _reconcileReminders() async {
    try {
      await ref.read(reminderReconciliationControllerProvider).trigger();
    } catch (_) {
      // Reconciliation is repair work. A platform notification failure must not
      // make Home unusable; the controller retries before the next lifecycle
      // opportunity can queue another repair.
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(dailyTimelineProvider);
    final meds = ref.watch(medsProvider);

    final body = switch (_tab) {
      0 => DailyTimelineView(
        items: timeline,
        onTake: _take,
        onSkip: _skip,
        onSnooze: _snooze,
      ),
      1 => _MedicationList(meds: meds),
      2 => const AppointmentScreen(),
      _ => const SettingsScreen(embedded: true),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('app_title'.tr()),
        actions: [
          TextButton.icon(
            onPressed: () => showSosActionSheet(context),
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('SOS'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
          IconButton(
            tooltip: 'emergency_card_title'.tr(),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EmergencyMedicalCardScreen(),
              ),
            ),
            icon: const Icon(Icons.medical_information_outlined),
          ),
        ],
      ),
      body: body,
      floatingActionButton: switch (_tab) {
        0 || 1 => FloatingActionButton.extended(
          onPressed: _addMedication,
          icon: const Icon(Icons.add),
          label: Text('add_med'.tr()),
        ),
        2 => FloatingActionButton.extended(
          onPressed: _addAppointment,
          icon: const Icon(Icons.event_available_outlined),
          label: Text('appointment_add'.tr()),
        ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: 'today'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.medication_outlined),
            selectedIcon: const Icon(Icons.medication),
            label: 'all_meds'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_outlined),
            selectedIcon: const Icon(Icons.event),
            label: 'appointments'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: 'settings_title'.tr(),
          ),
        ],
      ),
    );
  }

  Future<void> _take(ScheduledDose dose) async {
    await ref
        .read(logsProvider.notifier)
        .markTaken(dose.medication.id, dose.scheduledAt);
    await NotificationService.cancelSnooze(
      dose.medication.id,
      dose.scheduledAt,
    );
    await _reconcileReminders();
    await _syncCompanions();
  }

  Future<void> _skip(ScheduledDose dose) async {
    await ref
        .read(logsProvider.notifier)
        .markSkipped(dose.medication.id, dose.scheduledAt);
    await NotificationService.cancelSnooze(
      dose.medication.id,
      dose.scheduledAt,
    );
    await _reconcileReminders();
  }

  Future<void> _snooze(ScheduledDose dose) async {
    await ref
        .read(logsProvider.notifier)
        .markSnoozed(dose.medication.id, dose.scheduledAt);
    await NotificationService.scheduleSnooze(
      medId: dose.medication.id,
      medName: dose.medication.name,
      dosage: dose.medication.dosagePerTime,
      scheduledDose: dose.scheduledAt,
    );
    await _reconcileReminders();
  }

  Future<void> _syncCompanions() async {
    final meds = ref.read(medsProvider);
    try {
      await WatchSyncService.syncMeds(meds);
    } on MissingPluginException {
      // Native handoff is optional until platform wiring is installed.
    }
  }

  Future<void> _addMedication() async {
    final draft = await showModalBottomSheet<Medication>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MedicationEditor(),
    );
    if (draft == null) return;
    await ref.read(medsProvider.notifier).add(draft);
    await _reconcileReminders();
    await _syncCompanions();
    try {
      await LiveActivityService.start(
        draft.name,
        draft.dosagePerTime,
        draft.times.first,
      );
    } on MissingPluginException {
      // Native Live Activity support is an optional handoff.
    }
  }

  Future<void> _addAppointment() => showAppointmentEditor(context, ref);
}

enum _MedicationAction { refill, delete }

class _MedicationList extends ConsumerWidget {
  const _MedicationList({required this.meds});
  final List<Medication> meds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meds.length,
      itemBuilder: (_, index) {
        final med = meds[index];
        return Card(
          child: ListTile(
            title: Text(med.name),
            subtitle: Text('${med.times.join(', ')} · ${med.mode.name}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: 'checkin_action'.tr(),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => MedicationCheckInPanel(medication: med),
                  ),
                  icon: const Icon(Icons.fact_check_outlined),
                ),
                PopupMenuButton<_MedicationAction>(
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  onSelected: (action) async {
                    switch (action) {
                      case _MedicationAction.refill:
                        await showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => RefillPanel(medication: med),
                        );
                        await ref
                            .read(reminderReconciliationControllerProvider)
                            .trigger();
                      case _MedicationAction.delete:
                        await ref.read(medsProvider.notifier).remove(med.id);
                        await ref
                            .read(reminderReconciliationControllerProvider)
                            .trigger();
                    }
                  },
                  itemBuilder: (context) => <PopupMenuEntry<_MedicationAction>>[
                    PopupMenuItem<_MedicationAction>(
                      value: _MedicationAction.refill,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add_box_outlined),
                        title: Text('refill_action'.tr()),
                      ),
                    ),
                    PopupMenuItem<_MedicationAction>(
                      value: _MedicationAction.delete,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_outline),
                        title: Text('delete'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MedicationEditor extends StatefulWidget {
  const _MedicationEditor();

  @override
  State<_MedicationEditor> createState() => _MedicationEditorState();
}

class _MedicationEditorState extends State<_MedicationEditor> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _stock = TextEditingController(text: '30');
  final _threshold = TextEditingController(text: '5');
  final _dosage = TextEditingController(text: '1');
  final _days = TextEditingController(text: '7');
  final _times = <String>['08:00'];
  var _mode = MedicationMode.forever;
  String? _photoPath;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _stock.dispose();
    _threshold.dispose();
    _dosage.dispose();
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        24,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('add_med'.tr(), style: Theme.of(context).textTheme.titleLarge),
            if (_photoPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Image.file(File(_photoPath!), height: 120),
              ),
            TextButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text('camera_local'.tr()),
            ),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: 'med_name'.tr()),
            ),
            TextField(
              controller: _description,
              decoration: InputDecoration(labelText: 'med_desc'.tr()),
            ),
            TextField(
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'total_amount'.tr()),
            ),
            TextField(
              controller: _threshold,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'low_threshold'.tr()),
            ),
            TextField(
              controller: _dosage,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'dosage'.tr()),
            ),
            const SizedBox(height: 12),
            ..._times.asMap().entries.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                trailing: IconButton(
                  onPressed: () => _editTime(entry.key),
                  icon: const Icon(Icons.schedule),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _times.add('12:00')),
              icon: const Icon(Icons.add),
              label: Text('add_time'.tr()),
            ),
            DropdownButtonFormField<MedicationMode>(
              initialValue: _mode,
              items: <DropdownMenuItem<MedicationMode>>[
                DropdownMenuItem(
                  value: MedicationMode.forever,
                  child: Text('mode_forever'.tr()),
                ),
                DropdownMenuItem(
                  value: MedicationMode.days,
                  child: Text('mode_days'.tr()),
                ),
                DropdownMenuItem(
                  value: MedicationMode.untilEmpty,
                  child: Text('mode_until_empty'.tr()),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _mode = value ?? MedicationMode.forever),
            ),
            if (_mode == MedicationMode.days)
              TextField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Days'),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text('save_offline'.tr())),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera);
    if (image == null) return;
    final persisted = await PhotoService.persistPhoto(image.path);
    if (!mounted) return;
    setState(() => _photoPath = persisted);
  }

  Future<void> _editTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(
      () => _times[index] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty || _times.isEmpty) return;
    final medication = Medication(
      id: const Uuid().v4(),
      name: name,
      description: _description.text.trim(),
      initialAmount: int.tryParse(_stock.text),
      lowThreshold: int.tryParse(_threshold.text),
      imagePath: _photoPath,
      times: List<String>.unmodifiable(_times),
      dosagePerTime: int.tryParse(_dosage.text) ?? 1,
      mode: _mode,
      daysCount: _mode == MedicationMode.days ? int.tryParse(_days.text) : null,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).pop(medication);
  }
}
