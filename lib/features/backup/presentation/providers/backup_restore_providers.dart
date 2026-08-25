import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../medication/presentation/viewmodels/medication_view_model.dart';
import '../../application/commit_prepared_backup_restore.dart';
import '../../application/medication_backup_data_port.dart';
import '../../application/prepare_backup_restore.dart';
import '../../application/restore_backup_bundle.dart';
import '../../application/zip_backup_bundle_archive_codec.dart';
import '../../infrastructure/file_backup_attachment_restore_port.dart';

final backupDataPortProvider = Provider<MedicationBackupDataPort>(
  (ref) => MedicationBackupDataPort(
    medicationRepository: ref.watch(medicationRepositoryProvider),
    doseLogRepository: ref.watch(doseLogRepositoryProvider),
  ),
);

final backupRestorePortProvider =
    FutureProvider<FileBackupAttachmentRestorePort>(
  (ref) async {
    final documents = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    return FileBackupAttachmentRestorePort(
      documentsPath: documents.path,
      stagingRootPath: p.join(support.path, 'backup_restore_staging'),
    );
  },
);

final restoreBackupBundleProvider =
    FutureProvider<RestoreBackupBundle>((ref) async {
  final dataPort = ref.watch(backupDataPortProvider);
  final attachmentRestorePort =
      await ref.watch(backupRestorePortProvider.future);
  const codec = ZipBackupBundleArchiveCodec();

  return RestoreBackupBundle(
    prepare: PrepareBackupRestore(
      codec: codec,
      attachmentRestorePort: attachmentRestorePort,
    ),
    commit: CommitPreparedBackupRestore(
      dataPort: dataPort,
      attachmentRestorePort: attachmentRestorePort,
    ),
    onSuccess: () {
      ref.invalidate(logsProvider);
      ref.invalidate(medsProvider);
    },
  );
});
