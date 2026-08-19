import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/medication.dart';
import '../providers/meds_provider.dart';
import '../services/live_activity_service.dart';
import '../services/notification_service.dart';
import '../services/photo_service.dart';
import '../services/watch_sync_service.dart';
import 'widgets/dose_action_buttons.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final doses = ref.watch(todayDosesProvider);
    final meds = ref.watch(medsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('app_title'.tr()),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.setLocale(
              context.locale.languageCode == 'th'
                  ? const Locale('en')
                  : const Locale('th'),
            ),
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: _tab == 0
          ? _TodayList(
              doses: doses,
              onTake: _take,
              onSkip: _skip,
              onSnooze: _snooze,
            )
          : _MedicationList(meds: meds),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedication,
        icon: const Icon(Icons.add),
        label: Text('add_med'.tr()),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (value) => setState(() => _tab = value),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.today),
            label: 'today'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.medication),
            label: 'all_meds'.tr(),
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
}

class _TodayList extends StatelessWidget {
  const _TodayList({
    required this.doses,
    required this.onTake,
    required this.onSkip,
    required this.onSnooze,
  });

  final List<ScheduledDose> doses;
  final Future<void> Function(ScheduledDose) onTake;
  final Future<void> Function(ScheduledDose) onSkip;
  final Future<void> Function(ScheduledDose) onSnooze;

  @override
  Widget build(BuildContext context) {
    if (doses.isEmpty) return Center(child: Text('no_dose'.tr()));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: doses.length,
      itemBuilder: (_, index) {
        final dose = doses[index];
        final med = dose.medication;
        final hour = dose.scheduledAt.hour.toString().padLeft(2, '0');
        final minute = dose.scheduledAt.minute.toString().padLeft(2, '0');
        final hasActions = !dose.isTaken && !dose.isSkipped;
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ListTile(
                leading: med.imagePath == null
                    ? const Icon(Icons.medication)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(med.imagePath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                title: Text(
                  '$hour:$minute · ${med.name} × ${med.dosagePerTime}',
                ),
                subtitle: Text(
                  'remaining'.tr(
                    namedArgs: <String, String>{
                      'count': '${dose.remaining ?? '-'}',
                    },
                  ),
                ),
                trailing: dose.isTaken
                    ? const Icon(Icons.check_circle)
                    : dose.isSkipped
                    ? Text('skipped'.tr())
                    : null,
              ),
              if (hasActions)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: DoseActionButtons(
                      takeLabel: 'take'.tr(),
                      skipLabel: 'skip'.tr(),
                      snoozeLabel: 'snooze'.tr(),
                      onTake: () => onTake(dose),
                      onSkip: () => onSkip(dose),
                      onSnooze: () => onSnooze(dose),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

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
            trailing: IconButton(
              onPressed: () => ref.read(medsProvider.notifier).remove(med.id),
              icon: const Icon(Icons.delete_outline),
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
              value: _mode,
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
