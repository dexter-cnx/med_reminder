import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/result/result.dart';
import '../../../medication/application/build_today_doses.dart';
import '../../../medication/domain/repositories/medication_repository.dart';
import '../../../medication/domain/services/medication_services.dart';
import '../../../medication/presentation/viewmodels/medication_view_model.dart';
import '../../application/commit_prepared_backup_restore.dart';
import '../../application/create_backup_bundle.dart';
import '../../application/medication_backup_data_port.dart';
import '../../application/medication_photo_attachment_collector.dart';
import '../../application/prepare_backup_restore.dart';
import '../../application/rebuild_restored_reminders.dart';
import '../../application/restore_backup_bundle.dart';
import '../../application/zip_backup_bundle_archive_codec.dart';
import '../../infrastructure/file_backup_attachment_restore_port.dart';
import '../../infrastructure/file_backup_attachment_source.dart';

final backupDataPortProvider = Provider<MedicationBackupDataPort>(
  (ref) => MedicationBackupDataPort(
    medicationRepository: ref.watch(medicationRepositoryProvider),
    doseLogRepository: ref.watch(doseLogRepositoryProvider),
  ),
);

final createBackupBundleProvider = Provider<CreateBackupBundle>(
  (ref) => CreateBackupBundle(
    dataPort: ref.watch(backupDataPortProvider),
    attachmentCollector: const MedicationPhotoAttachmentCollector(
      source: FileBackupAttachmentSource(),
    ),
    codec: const ZipBackupBundleArchiveCodec(),
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

final backupRestoreMaintenanceProvider =
    FutureProvider<Result<int>>((ref) async {
  final restorePort = await ref.watch(backupRestorePortProvider.future);
  return restorePort.cleanupStaleStages(
    olderThan: const Duration(hours: 24),
  );
});

final reminderRepairControllerProvider =
    StateNotifierProvider<ReminderRepairController, bool>(
  (ref) => ReminderRepairController(
    medicationRepository: ref.watch(medicationRepositoryProvider),
    doseLogRepository: ref.watch(doseLogRepositoryProvider),
    reminderScheduler: ref.watch(medicationReminderSchedulerProvider),
    stockResolver: ref.watch(medicationStockResolverProvider),
    refreshState: () {
      ref.invalidate(logsProvider);
      ref.invalidate(medsProvider);
    },
  ),
);

final class ReminderRepairController extends StateNotifier<bool> {
  ReminderRepairController({
    required this.medicationRepository,
    required this.doseLogRepository,
    required this.reminderScheduler,
    required this.stockResolver,
    required this.refreshState,
  }) : super(false);

  final MedicationRepository medicationRepository;
  final DoseLogRepository doseLogRepository;
  final MedicationReminderScheduler reminderScheduler;
  final MedicationStockResolver stockResolver;
  final void Function() refreshState;

  Future<Result<void>> repair() async {
    if (state) {
      return const Failed<void>(
        Failure(
          code: 'backup_restore_reminder_repair_in_progress',
          message: 'Medication reminder repair is already in progress.',
        ),
      );
    }

    state = true;
    try {
      final notificationIdsResult =
          medicationRepository.readAll().fold<Result<List<int>>>(
                onSuccess: (medications) => Success<List<int>>(
                  <int>[
                    for (final medication in medications)
                      ...medication.notificationIds,
                  ],
                ),
                onFailure: (failure) => Failed<List<int>>(failure),
              );
      if (notificationIdsResult case Failed<List<int>>(:final failure)) {
        return Failed<void>(failure);
      }

      final previousNotificationIds =
          (notificationIdsResult as Success<List<int>>).value;
      final result = await RebuildRestoredReminders(
        medicationRepository: medicationRepository,
        doseLogRepository: doseLogRepository,
        reminderScheduler: reminderScheduler,
        stockResolver: stockResolver,
      )(previousNotificationIds: previousNotificationIds);

      refreshState();
      return result;
    } finally {
      state = false;
    }
  }
}

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
    captureReminderState: () =>
        ref.read(medicationRepositoryProvider).readAll().fold(
              onSuccess: (medications) => Success<List<int>>(
                <int>[
                  for (final medication in medications)
                    ...medication.notificationIds,
                ],
              ),
              onFailure: (failure) => Failed<List<int>>(failure),
            ),
    onSuccess: (previousNotificationIds) async {
      ref.invalidate(logsProvider);
      ref.invalidate(medsProvider);

      final rebuild = await RebuildRestoredReminders(
        medicationRepository: ref.read(medicationRepositoryProvider),
        doseLogRepository: ref.read(doseLogRepositoryProvider),
        reminderScheduler: ref.read(medicationReminderSchedulerProvider),
        stockResolver: ref.read(medicationStockResolverProvider),
      )(previousNotificationIds: previousNotificationIds);

      ref.invalidate(logsProvider);
      ref.invalidate(medsProvider);
      return rebuild;
    },
  );
});
