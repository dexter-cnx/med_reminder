import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/backup_export_port.dart';
import '../providers/backup_export_providers.dart';

class BackupExportCard extends ConsumerWidget {
  const BackupExportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(backupExportControllerProvider);
    final isThai = Localizations.localeOf(context).languageCode == 'th';

    Future<void> export() async {
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    return Card(
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
              onPressed: busy ? null : export,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_outlined),
              label: Text(
                busy
                    ? (isThai ? 'กำลังสร้างไฟล์สำรอง…' : 'Creating backup…')
                    : (isThai ? 'ส่งออกไฟล์สำรอง' : 'Export backup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
