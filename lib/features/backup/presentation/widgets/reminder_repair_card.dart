import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/backup_restore_providers.dart';

class ReminderRepairCard extends ConsumerStatefulWidget {
  const ReminderRepairCard({super.key});

  @override
  ConsumerState<ReminderRepairCard> createState() => _ReminderRepairCardState();
}

class _ReminderRepairCardState extends ConsumerState<ReminderRepairCard> {
  bool _busy = false;

  bool get _isThai => Localizations.localeOf(context).languageCode == 'th';

  String get _title => _isThai ? 'ซ่อมการแจ้งเตือนยา' : 'Repair medication reminders';
  String get _description => _isThai
      ? 'สร้างการแจ้งเตือนใหม่จากข้อมูลยาปัจจุบัน โดยไม่เปลี่ยนข้อมูลยาที่บันทึกไว้'
      : 'Rebuild reminders from current medication data without changing your saved medication records.';
  String get _action => _isThai ? 'ซ่อมการแจ้งเตือน' : 'Repair reminders';
  String get _success => _isThai
      ? 'สร้างการแจ้งเตือนยาใหม่เรียบร้อยแล้ว'
      : 'Medication reminders were rebuilt successfully.';

  String _failureMessage(String code) {
    if (_isThai) {
      return switch (code) {
        'backup_restore_reminder_state_persist_failed' =>
          'สร้างการแจ้งเตือนได้ แต่บันทึกสถานะใหม่ไม่สำเร็จ กรุณาลองอีกครั้ง',
        'backup_restore_reminder_cleanup_failed' =>
          'ซ่อมการแจ้งเตือนไม่สำเร็จทั้งหมด กรุณาลองอีกครั้ง',
        _ => 'ไม่สามารถซ่อมการแจ้งเตือนได้ กรุณาลองอีกครั้ง',
      };
    }
    return switch (code) {
      'backup_restore_reminder_state_persist_failed' =>
        'Reminders were rebuilt, but the new state could not be saved. Try again.',
      'backup_restore_reminder_cleanup_failed' =>
        'Reminder repair could not be completed safely. Try again.',
      _ => 'Medication reminders could not be repaired. Try again.',
    };
  }

  Future<void> _repair() async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = ref.read(reminderRepairControllerProvider);
    final result = await controller.repair();
    if (!mounted) return;
    setState(() => _busy = false);
    final message = result.fold(
      onSuccess: (_) => _success,
      onFailure: (failure) => _failureMessage(failure.code),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(_description),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _repair,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.build_circle_outlined),
              label: Text(_action),
            ),
          ],
        ),
      ),
    );
  }
}
