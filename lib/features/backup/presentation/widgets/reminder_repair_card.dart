import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/backup_restore_providers.dart';

class ReminderRepairCard extends ConsumerWidget {
  const ReminderRepairCard({super.key});

  bool _isThai(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'th';

  String _title(BuildContext context) =>
      _isThai(context) ? 'ซ่อมการแจ้งเตือนยา' : 'Repair medication reminders';
  String _description(BuildContext context) => _isThai(context)
      ? 'สร้างการแจ้งเตือนใหม่จากข้อมูลยาปัจจุบัน โดยไม่เปลี่ยนข้อมูลยาที่บันทึกไว้'
      : 'Rebuild reminders from current medication data without changing your saved medication records.';
  String _action(BuildContext context) =>
      _isThai(context) ? 'ซ่อมการแจ้งเตือน' : 'Repair reminders';
  String _success(BuildContext context) => _isThai(context)
      ? 'สร้างการแจ้งเตือนยาใหม่เรียบร้อยแล้ว'
      : 'Medication reminders were rebuilt successfully.';

  String _failureMessage(BuildContext context, String code) {
    if (_isThai(context)) {
      return switch (code) {
        'backup_restore_reminder_state_persist_failed' =>
          'ไม่สามารถบันทึกสถานะการแจ้งเตือนได้ ระบบยกเลิกการแจ้งเตือนที่สร้างใหม่แล้ว กรุณาลองซ่อมอีกครั้งก่อนพึ่งพาการเตือน',
        'backup_restore_reminder_cleanup_failed' =>
          'ซ่อมการแจ้งเตือนไม่สำเร็จทั้งหมด กรุณาลองอีกครั้งและตรวจสอบการแจ้งเตือนยา',
        'backup_restore_reminder_repair_in_progress' =>
          'กำลังซ่อมการแจ้งเตือนอยู่ กรุณารอให้เสร็จก่อน',
        _ =>
          'ไม่สามารถซ่อมการแจ้งเตือนได้ การแจ้งเตือนยาอาจยังไม่พร้อม กรุณาลองอีกครั้ง',
      };
    }
    return switch (code) {
      'backup_restore_reminder_state_persist_failed' =>
        'Reminder state could not be saved, so newly created reminders were removed. Repair reminders again before relying on medication alerts.',
      'backup_restore_reminder_cleanup_failed' =>
        'Reminder repair could not be completed safely. Try again and verify your medication reminders.',
      'backup_restore_reminder_repair_in_progress' =>
        'Reminder repair is already in progress. Let it finish before trying again.',
      _ =>
        'Medication reminders could not be repaired and may still be unavailable. Try again.',
    };
  }

  Future<void> _repair(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(reminderRepairControllerProvider.notifier).repair();
    if (!context.mounted) return;
    final message = result.fold(
      onSuccess: (_) => _success(context),
      onFailure: (failure) => _failureMessage(context, failure.code),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(reminderRepairControllerProvider);
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
                      Text(
                        _title(context),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(_description(context)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : () => _repair(context, ref),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.build_circle_outlined),
              label: Text(_action(context)),
            ),
          ],
        ),
      ),
    );
  }
}
