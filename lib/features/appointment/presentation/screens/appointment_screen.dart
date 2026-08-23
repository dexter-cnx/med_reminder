import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/layout/responsive_layout.dart';
import '../../../doctor_visit_summary/presentation/screens/doctor_visit_summary_screen.dart';
import '../../domain/entities/doctor_appointment.dart';
import '../providers/appointment_providers.dart';

class AppointmentScreen extends ConsumerWidget {
  const AppointmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentsProvider);
    final size = MediaQuery.sizeOf(context);
    final layout = ResponsiveLayoutInfo.fromSize(size);
    final maxWidth = layout.isTablet ? size.width * 0.78 : size.width;
    final horizontalPadding =
        (size.width * 0.04).clamp(16.0, 32.0).toDouble();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                8,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DoctorVisitSummaryScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.summarize_outlined),
                  label: Text('doctor_summary_open'.tr()),
                ),
              ),
            ),
            Expanded(
              child: appointments.isEmpty
                  ? Center(child: Text('appointment_empty'.tr()))
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        8,
                        horizontalPadding,
                        16,
                      ),
                      itemCount: appointments.length,
                      itemBuilder: (_, index) {
                        final appointment = appointments[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.event_outlined),
                            title: Text(appointment.title),
                            subtitle: Text(_subtitle(context, appointment)),
                            onTap: () => showAppointmentEditor(
                              context,
                              ref,
                              appointment: appointment,
                            ),
                            trailing: IconButton(
                              tooltip: 'delete'.tr(),
                              onPressed: () => ref
                                  .read(appointmentsProvider.notifier)
                                  .delete(appointment.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(BuildContext context, DoctorAppointment appointment) {
    final local = appointment.startsAt.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
    );
    final location = appointment.location?.trim();
    return <String>[
      '$date · $time',
      if (location != null && location.isNotEmpty) location,
    ].join(' · ');
  }
}

Future<void> showAppointmentEditor(
  BuildContext context,
  WidgetRef ref, {
  DoctorAppointment? appointment,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AppointmentEditor(
        appointment: appointment,
        onSave: (draft) =>
            ref.read(appointmentsProvider.notifier).upsert(draft),
        failureMessage: () =>
            ref.read(appointmentFailureProvider)?.message ??
            'Unable to save appointment.',
      ),
    );

class _AppointmentEditor extends StatefulWidget {
  const _AppointmentEditor({
    required this.onSave,
    required this.failureMessage,
    this.appointment,
  });

  final DoctorAppointment? appointment;
  final Future<bool> Function(DoctorAppointment appointment) onSave;
  final String Function() failureMessage;

  @override
  State<_AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<_AppointmentEditor> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _note;
  late DateTime _startsAt;
  var _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final existing = widget.appointment;
    _title = TextEditingController(text: existing?.title ?? '');
    _location = TextEditingController(text: existing?.location ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _startsAt = existing?.startsAt.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = ResponsiveLayoutInfo.fromSize(size);
    final maxWidth = layout.isTablet ? size.width * 0.62 : size.width;
    final localizations = MaterialLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    widget.appointment == null
                        ? 'appointment_add'.tr()
                        : 'appointment_edit'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _title,
                    autofocus: widget.appointment == null,
                    decoration: InputDecoration(
                      labelText: 'appointment_title'.tr(),
                    ),
                  ),
                  TextField(
                    controller: _location,
                    decoration: InputDecoration(
                      labelText: 'appointment_location'.tr(),
                    ),
                  ),
                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'appointment_note'.tr(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(localizations.formatMediumDate(_startsAt)),
                    onTap: _saving ? null : _pickDate,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(
                      localizations.formatTimeOfDay(
                        TimeOfDay.fromDateTime(_startsAt),
                      ),
                    ),
                    onTap: _saving ? null : _pickTime,
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('save_offline'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startsAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startsAt.hour,
        _startsAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (picked == null) return;
    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    final existing = widget.appointment;
    final duration = existing?.endsAt?.difference(existing.startsAt);
    final draft = DoctorAppointment(
      id: existing?.id ?? const Uuid().v4(),
      title: title,
      startsAt: _startsAt,
      endsAt: duration == null ? null : _startsAt.add(duration),
      location: _nullableText(_location.text),
      note: _nullableText(_note.text),
      externalCalendarEventId: existing?.externalCalendarEventId,
    );

    setState(() {
      _saving = true;
      _saveError = null;
    });
    final saved = await widget.onSave(draft);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _saveError = widget.failureMessage();
    });
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
