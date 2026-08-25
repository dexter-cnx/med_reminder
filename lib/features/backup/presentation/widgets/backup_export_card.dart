import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../application/backup_export_port.dart';
import '../providers/backup_export_providers.dart';
import '../providers/backup_import_providers.dart';

class BackupExportCard extends ConsumerWidget {
  const BackupExportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportBusy = ref.watch(backupExportControllerProvider);
    final importState = ref.watch(backupImportControllerProvider);
    final transferBusy = exportBusy || importState.busy;
    final isThai = Localizations.localeOf(context).languageCode == 'th';

    Future<void> export() async {
      if (ref.read(backupImportControllerProvider).busy) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box?.localToGlobal(Offset.zero);
      final anchor = box == null || origin == null
          ? null
          : BackupShareAnchor(
              left: origin.dx,
              top: origin.dy,
              width: box.size.width,
              height: box.size.height,
            );
      final result = await ref
          .read(backupExportControllerProvider.notifier)
          .shareBackup(anchor: anchor);
      if (!context.mounted) return;
      final message = result.fold(
        onSuccess: (_) => isThai
            ? 'ส่งไฟล์สำรองไปยังปลายทางที่เลือกแล้ว'
            : 'The backup was handed to the selected destination.',
        onFailure: (failure) {
          if (failure.code == 'backup_export_cancelled') {
            return isThai
                ? 'ยกเลิกการส่งออกไฟล์สำรองแล้ว'
                : 'Backup export was cancelled.';
          }
          return isThai
              ? 'ไม่สามารถส่งออกไฟล์สำรองได้ กรุณาลองอีกครั้ง'
              : 'The backup could not be exported. Try again.';
        },
      );
      _showMessage(context, message);
    }

    Future<void> import() async {
      if (ref.read(backupExportControllerProvider)) return;
      final selected = await ref
          .read(backupImportControllerProvider.notifier)
          .selectArchive();
      if (!context.mounted) return;

      if (selected case Failed<BackupImportPreview?>(:final failure)) {
        _showMessage(context, _importFailureMessage(isThai, failure.code));
        return;
      }
      final preview = (selected as Success<BackupImportPreview?>).value;
      if (preview == null) return;

      final confirmed =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded),
              title: Text(
                isThai
                    ? 'แทนที่ข้อมูลด้วยไฟล์สำรอง?'
                    : 'Replace data with backup?',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isThai
                          ? 'การกู้คืนนี้จะแทนที่ข้อมูลยาและบันทึกการกินยาปัจจุบันทั้งหมด ข้อมูลปัจจุบันที่ไม่มีอยู่ในไฟล์สำรองจะถูกลบ'
                          : 'This restore replaces all current medication and dose-log data. Current data that is not in the backup will be removed.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isThai
                          ? 'ควรส่งออกข้อมูลปัจจุบันก่อน หากต้องการเก็บสำเนาไว้ การดำเนินการนี้ย้อนกลับจากในแอปไม่ได้'
                          : 'Export your current data first if you need a copy. This action cannot be undone inside the app.',
                      style: Theme.of(dialogContext).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    _PreviewRow(
                      label: isThai ? 'ไฟล์' : 'File',
                      value: preview.fileName,
                    ),
                    _PreviewRow(
                      label: isThai ? 'สร้างเมื่อ' : 'Exported',
                      value: _formatDateTime(preview.exportedAt.toLocal()),
                    ),
                    _PreviewRow(
                      label: isThai ? 'รายการยา' : 'Medications',
                      value: preview.medicationCount.toString(),
                    ),
                    _PreviewRow(
                      label: isThai ? 'บันทึกการกินยา' : 'Dose logs',
                      value: preview.doseLogCount.toString(),
                    ),
                    _PreviewRow(
                      label: isThai ? 'รูปยา' : 'Medication photos',
                      value: preview.attachmentCount.toString(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    isThai ? 'แทนที่และกู้คืน' : 'Replace and restore',
                  ),
                ),
              ],
            ),
          ) ??
          false;
      if (!context.mounted) return;
      if (!confirmed) {
        ref.read(backupImportControllerProvider.notifier).clearSelection();
        return;
      }

      final restored = await ref
          .read(backupImportControllerProvider.notifier)
          .restoreSelected();
      if (!context.mounted) return;
      final message = restored.fold(
        onSuccess: (_) => isThai
            ? 'กู้คืนข้อมูลจากไฟล์สำรองเรียบร้อยแล้ว'
            : 'Backup restored successfully.',
        onFailure: (failure) => _restoreFailureMessage(isThai, failure.code),
      );
      _showMessage(context, message);
    }

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.backup_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isThai ? 'ส่งออกข้อมูลสำรอง' : 'Export backup',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isThai
                                ? 'สร้างไฟล์ ZIP แบบออฟไลน์ที่มีข้อมูลยา บันทึกการกินยา และรูปยาที่เกี่ยวข้อง แล้วเลือกตำแหน่งจัดเก็บผ่านระบบ'
                                : 'Create an offline ZIP containing medication records, dose logs, and referenced medication photos, then choose where to save or share it.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isThai
                      ? 'Besyu จะไม่อัปโหลดไฟล์นี้ คุณเป็นผู้เลือกปลายทางเอง'
                      : 'Besyu does not upload this file. You choose the destination.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: transferBusy ? null : export,
                  icon: exportBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_outlined),
                  label: Text(
                    exportBusy
                        ? (isThai ? 'กำลังสร้างไฟล์สำรอง…' : 'Creating backup…')
                        : (isThai ? 'ส่งออกไฟล์สำรอง' : 'Export backup'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.restore_page_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isThai ? 'นำเข้าข้อมูลสำรอง' : 'Import backup',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isThai
                                ? 'เลือกไฟล์ ZIP ของ Besyu ระบบจะตรวจสอบไฟล์และแสดงรายละเอียดก่อนขออนุญาตแทนที่ข้อมูลปัจจุบัน'
                                : 'Choose a Besyu ZIP backup. The archive is validated and summarized before you are asked to replace current data.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isThai
                      ? 'การเลือกไฟล์เพียงอย่างเดียวยังไม่เปลี่ยนข้อมูลใด ๆ'
                      : 'Selecting a file alone does not change any saved data.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: transferBusy ? null : import,
                  icon: importState.busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open_outlined),
                  label: Text(
                    importState.busy
                        ? (isThai
                              ? 'กำลังตรวจสอบหรือกู้คืน…'
                              : 'Validating or restoring…')
                        : (isThai ? 'เลือกไฟล์สำรอง' : 'Choose backup file'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _importFailureMessage(bool isThai, String code) {
    if (code == 'backup_import_too_large') {
      return isThai
          ? 'ไฟล์สำรองมีขนาดใหญ่เกินกว่าที่แอปรองรับในขณะนี้'
          : 'The backup is larger than the app can import right now.';
    }
    if (code == 'backup_import_pick_failed') {
      return isThai
          ? 'ไม่สามารถอ่านไฟล์สำรองที่เลือกได้ กรุณาลองอีกครั้ง'
          : 'The selected backup could not be read. Try again.';
    }
    return isThai
        ? 'ไฟล์นี้ไม่ใช่ข้อมูลสำรอง Besyu ที่รองรับ หรือไฟล์อาจเสียหาย'
        : 'This is not a supported Besyu backup, or the archive may be damaged.';
  }

  static String _restoreFailureMessage(bool isThai, String code) {
    const reminderFailures = <String>{
      'backup_restore_reminder_rebuild_failed',
      'backup_restore_reminder_state_persist_failed',
      'backup_restore_reminder_cleanup_failed',
    };
    if (reminderFailures.contains(code)) {
      return isThai
          ? 'ข้อมูลถูกกู้คืนแล้ว แต่การแจ้งเตือนยายังไม่พร้อม กรุณาใช้ “ซ่อมการแจ้งเตือนยา” ก่อนพึ่งพาการเตือน'
          : 'Data was restored, but medication reminders are not ready. Use “Repair medication reminders” before relying on alerts.';
    }
    if (code == 'backup_restore_rollback_failed' ||
        code == 'backup_restore_attachment_rollback_failed') {
      return isThai
          ? 'การกู้คืนไม่สามารถย้อนการเปลี่ยนแปลงได้ครบถ้วน ข้อมูลอาจอยู่ในสถานะไม่สมบูรณ์ กรุณาตรวจสอบข้อมูลก่อนใช้งานต่อ'
          : 'Restore could not fully roll back its changes. Data may be incomplete; review it before continuing.';
    }
    return isThai
        ? 'ไม่สามารถกู้คืนข้อมูลได้ ข้อมูลเดิมควรยังคงอยู่ กรุณาตรวจสอบไฟล์แล้วลองอีกครั้ง'
        : 'The backup could not be restored. Existing data should remain unchanged; verify the archive and try again.';
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
