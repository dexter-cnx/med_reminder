import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../medication/domain/entities/medication.dart';
import '../../domain/entities/medication_check_in.dart';
import '../providers/medication_check_in_providers.dart';

class MedicationCheckInPanel extends ConsumerStatefulWidget {
  const MedicationCheckInPanel({required this.medication, super.key});

  final Medication medication;

  @override
  ConsumerState<MedicationCheckInPanel> createState() =>
      _MedicationCheckInPanelState();
}

class _MedicationCheckInPanelState
    extends ConsumerState<MedicationCheckInPanel> {
  final _note = TextEditingController();
  var _kind = MedicationCheckInKind.noIssue;
  var _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(
      medicationCheckInsForProvider(widget.medication.id),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'checkin_title'.tr(args: [widget.medication.name]),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'checkin_safety_note'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MedicationCheckInKind>(
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: 'checkin_observation'.tr(),
                ),
                items: MedicationCheckInKind.values
                    .map(
                      (kind) => DropdownMenuItem<MedicationCheckInKind>(
                        value: kind,
                        child: Text(_kindLabel(kind)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) => setState(
                        () => _kind = value ?? MedicationCheckInKind.noIssue,
                      ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'checkin_note'.tr(),
                  hintText: 'checkin_note_hint'.tr(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text('checkin_record'.tr()),
              ),
              const SizedBox(height: 24),
              Text(
                'checkin_history'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (history.isEmpty)
                Text('checkin_empty'.tr())
              else
                ...history.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.hasReportedIssue
                          ? Icons.notes_outlined
                          : Icons.check_circle_outline,
                    ),
                    title: Text(_kindLabel(item.kind)),
                    subtitle: Text(
                      item.note.isEmpty
                          ? _formatTimestamp(item.recordedAt)
                          : '${_formatTimestamp(item.recordedAt)}\n${item.note}',
                    ),
                    isThreeLine: item.note.isNotEmpty,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await ref
        .read(medicationCheckInsProvider.notifier)
        .record(
          medicationId: widget.medication.id,
          kind: _kind,
          note: _note.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('checkin_save_failed'.tr())));
      return;
    }
    _note.clear();
    setState(() => _kind = MedicationCheckInKind.noIssue);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('checkin_saved'.tr())));
  }

  String _kindLabel(MedicationCheckInKind kind) => switch (kind) {
    MedicationCheckInKind.noIssue => 'checkin_kind_no_issue'.tr(),
    MedicationCheckInKind.dizziness => 'checkin_kind_dizziness'.tr(),
    MedicationCheckInKind.nausea => 'checkin_kind_nausea'.tr(),
    MedicationCheckInKind.rash => 'checkin_kind_rash'.tr(),
    MedicationCheckInKind.other => 'checkin_kind_other'.tr(),
  };

  String _formatTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
