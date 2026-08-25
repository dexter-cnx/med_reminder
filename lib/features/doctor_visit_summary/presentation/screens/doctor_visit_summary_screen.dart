import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../medication_checkin/domain/entities/medication_check_in.dart';
import '../../../../shared/layout/responsive_layout.dart';
import '../../domain/entities/doctor_visit_summary.dart';
import '../providers/doctor_visit_summary_provider.dart';

class DoctorVisitSummaryScreen extends ConsumerWidget {
  const DoctorVisitSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(doctorVisitSummaryProvider);
    final size = MediaQuery.sizeOf(context);
    final layout = ResponsiveLayoutInfo.fromSize(size);
    final maxWidth = layout.isTablet ? size.width * 0.78 : size.width;
    final localizations = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('doctor_summary_title'.tr())),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              Text(
                'doctor_summary_disclaimer'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'doctor_summary_period'.tr(
                  namedArgs: <String, String>{
                    'from': localizations.formatMediumDate(summary.periodStart),
                    'to': localizations.formatMediumDate(summary.periodEnd),
                  },
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (summary.medications.isEmpty)
                Text('doctor_summary_no_meds'.tr())
              else
                ...summary.medications.map(
                  (item) => _MedicationSummaryCard(item: item),
                ),
              const SizedBox(height: 20),
              Text(
                'doctor_summary_upcoming_appointments'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (summary.upcomingAppointments.isEmpty)
                Text('doctor_summary_no_appointments'.tr())
              else
                ...summary.upcomingAppointments
                    .take(3)
                    .map(
                      (appointment) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: Text(appointment.title),
                        subtitle: Text(
                          '${localizations.formatMediumDate(appointment.startsAt.toLocal())} · '
                          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(appointment.startsAt.toLocal()))}',
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationSummaryCard extends StatelessWidget {
  const _MedicationSummaryCard({required this.item});

  final DoctorVisitMedicationSummary item;

  @override
  Widget build(BuildContext context) {
    final medication = item.medication;
    final genericName = medication.genericName.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              medication.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (genericName.isNotEmpty)
              Text(genericName, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'doctor_summary_dose_facts'.tr(
                namedArgs: <String, String>{
                  'taken': '${item.takenCount}',
                  'skipped': '${item.skippedCount}',
                },
              ),
            ),
            Text(
              'doctor_summary_refills'.tr(
                namedArgs: <String, String>{'count': '${item.refillQuantity}'},
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'doctor_summary_observations'.tr(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (item.checkIns.isEmpty)
              Text('doctor_summary_no_observations'.tr())
            else
              ...item.checkIns
                  .take(5)
                  .map(
                    (checkIn) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_checkInText(context, checkIn)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _checkInText(BuildContext context, MedicationCheckIn checkIn) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(checkIn.recordedAt.toLocal());
    final note = checkIn.note.trim();
    final label = switch (checkIn.kind) {
      MedicationCheckInKind.noIssue => 'checkin_kind_no_issue'.tr(),
      MedicationCheckInKind.dizziness => 'checkin_kind_dizziness'.tr(),
      MedicationCheckInKind.nausea => 'checkin_kind_nausea'.tr(),
      MedicationCheckInKind.rash => 'checkin_kind_rash'.tr(),
      MedicationCheckInKind.other => 'checkin_kind_other'.tr(),
    };
    return note.isEmpty ? '$date · $label' : '$date · $label · $note';
  }
}
