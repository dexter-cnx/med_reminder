import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../features/medication/domain/entities/scheduled_dose.dart';
import '../../features/timeline/domain/entities/timeline_item.dart';
import '../../shared/layout/responsive_layout.dart';
import 'dose_action_buttons.dart';

class DailyTimelineView extends StatelessWidget {
  const DailyTimelineView({
    required this.items,
    required this.onTake,
    required this.onSkip,
    required this.onSnooze,
    super.key,
  });

  final List<TimelineItem> items;
  final Future<void> Function(ScheduledDose) onTake;
  final Future<void> Function(ScheduledDose) onSkip;
  final Future<void> Function(ScheduledDose) onSnooze;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text('no_dose'.tr()));

    final size = MediaQuery.sizeOf(context);
    final layout = ResponsiveLayoutInfo.fromSize(size);
    if (!layout.isTablet || !layout.isLandscape) {
      return _TimelineList(
        items: items,
        onTake: onTake,
        onSkip: onSkip,
        onSnooze: onSnooze,
      );
    }

    final refillCount = items.whereType<RefillTimelineItem>().length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          flex: (layout.primaryPaneFraction * 100).round(),
          child: _TimelineList(
            items: items,
            onTake: onTake,
            onSkip: onSkip,
            onSnooze: onSnooze,
          ),
        ),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          flex: (layout.secondaryPaneFraction * 100).round(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.025,
              vertical: size.height * 0.035,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'today'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: size.height * 0.025),
                _OverviewMetric(
                  icon: Icons.timeline,
                  label: 'today'.tr(),
                  value: items.length,
                ),
                SizedBox(height: size.height * 0.015),
                _OverviewMetric(
                  icon: Icons.add_box_outlined,
                  label: 'refill_history'.tr(),
                  value: refillCount,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({
    required this.items,
    required this.onTake,
    required this.onSkip,
    required this.onSnooze,
  });

  final List<TimelineItem> items;
  final Future<void> Function(ScheduledDose) onTake;
  final Future<void> Function(ScheduledDose) onSkip;
  final Future<void> Function(ScheduledDose) onSnooze;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = (width * 0.04).clamp(16.0, 32.0).toDouble();
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        return switch (item) {
          MedicationDoseTimelineItem() => _DoseTimelineCard(
              dose: item.dose,
              onTake: onTake,
              onSkip: onSkip,
              onSnooze: onSnooze,
            ),
          RefillTimelineItem() => _RefillTimelineCard(item: item),
        };
      },
    );
  }
}

class _DoseTimelineCard extends StatelessWidget {
  const _DoseTimelineCard({
    required this.dose,
    required this.onTake,
    required this.onSkip,
    required this.onSnooze,
  });

  final ScheduledDose dose;
  final Future<void> Function(ScheduledDose) onTake;
  final Future<void> Function(ScheduledDose) onSkip;
  final Future<void> Function(ScheduledDose) onSnooze;

  @override
  Widget build(BuildContext context) {
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
            title: Text('$hour:$minute · ${med.name} × ${med.dosagePerTime}'),
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
  }
}

class _RefillTimelineCard extends StatelessWidget {
  const _RefillTimelineCard({required this.item});

  final RefillTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final event = item.event;
    final hour = event.createdAt.hour.toString().padLeft(2, '0');
    final minute = event.createdAt.minute.toString().padLeft(2, '0');
    final quantityLabel = 'refill_history_quantity'.tr(
      namedArgs: <String, String>{'count': event.quantity.toString()},
    );
    final note = event.note;
    final subtitleParts = <String>[
      if (item.medicationName.isNotEmpty) item.medicationName,
      if (note != null && note.isNotEmpty) note,
    ];

    return Card(
      child: ListTile(
        leading: const Icon(Icons.add_box_outlined),
        title: Text('$hour:$minute · $quantityLabel'),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }
}
