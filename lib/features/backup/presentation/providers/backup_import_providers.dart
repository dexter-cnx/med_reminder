import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../application/backup_bundle_archive_codec.dart';
import '../../application/backup_import_port.dart';
import '../../application/medication_backup_data_port.dart';
import '../../application/restore_backup_bundle.dart';
import '../../application/zip_backup_bundle_archive_codec.dart';
import '../../infrastructure/file_picker_backup_import_port.dart';
import 'backup_restore_providers.dart';

final class BackupImportPreview {
  const BackupImportPreview({
    required this.fileName,
    required this.exportedAt,
    required this.medicationCount,
    required this.doseLogCount,
    required this.attachmentCount,
  });

  final String fileName;
  final DateTime exportedAt;
  final int medicationCount;
  final int doseLogCount;
  final int attachmentCount;
}

final class BackupImportState {
  const BackupImportState({this.busy = false, this.preview});

  final bool busy;
  final BackupImportPreview? preview;
}

final backupImportPortProvider = Provider<BackupImportPort>(
  (ref) => const FilePickerBackupImportPort(),
);

final backupImportControllerProvider =
    StateNotifierProvider<BackupImportController, BackupImportState>(
  (ref) => BackupImportController(
    importPort: ref.watch(backupImportPortProvider),
    codec: const ZipBackupBundleArchiveCodec(),
    loadRestore: () => ref.read(restoreBackupBundleProvider.future),
  ),
);

final class BackupImportController extends StateNotifier<BackupImportState> {
  BackupImportController({
    required this.importPort,
    required this.codec,
    required this.loadRestore,
  }) : super(const BackupImportState());

  final BackupImportPort importPort;
  final BackupBundleArchiveCodec codec;
  final Future<RestoreBackupBundle> Function() loadRestore;

  BackupImportSelection? _selection;

  Future<Result<BackupImportPreview?>> selectArchive() async {
    if (state.busy) return _inProgress<BackupImportPreview?>();

    state = BackupImportState(busy: true, preview: state.preview);
    try {
      final picked = await importPort.pickArchive();
      if (picked case Failed<BackupImportSelection?>(:final failure)) {
        _selection = null;
        state = const BackupImportState();
        return Failed<BackupImportPreview?>(failure);
      }

      final selection = (picked as Success<BackupImportSelection?>).value;
      if (selection == null) {
        _selection = null;
        state = const BackupImportState();
        return const Success<BackupImportPreview?>(null);
      }

      final decoded = await codec.decodeBundle(selection.bytes);
      if (decoded case Failed(:final failure)) {
        _selection = null;
        state = const BackupImportState();
        return Failed<BackupImportPreview?>(failure);
      }

      final bundle = (decoded as Success).value;
      final preview = BackupImportPreview(
        fileName: selection.fileName,
        exportedAt: bundle.snapshot.exportedAt,
        medicationCount: bundle.snapshot.records
            .where(
              (record) =>
                  record.namespace == MedicationBackupDataPort.medicationNamespace,
            )
            .length,
        doseLogCount: bundle.snapshot.records
            .where(
              (record) =>
                  record.namespace == MedicationBackupDataPort.doseLogNamespace,
            )
            .length,
        attachmentCount: bundle.attachments.length,
      );
      _selection = selection;
      state = BackupImportState(preview: preview);
      return Success<BackupImportPreview?>(preview);
    } finally {
      if (state.busy) {
        state = BackupImportState(preview: state.preview);
      }
    }
  }

  Future<Result<void>> restoreSelected() async {
    if (state.busy) return _inProgress<void>();
    final selection = _selection;
    if (selection == null) {
      return const Failed<void>(
        Failure(
          code: 'backup_import_selection_missing',
          message: 'No validated backup archive is selected.',
        ),
      );
    }

    state = BackupImportState(busy: true, preview: state.preview);
    try {
      final restore = await loadRestore();
      return await restore(selection.bytes);
    } finally {
      _selection = null;
      state = const BackupImportState();
    }
  }

  void clearSelection() {
    if (state.busy) return;
    _selection = null;
    state = const BackupImportState();
  }

  Failed<T> _inProgress<T>() => const Failed<T>(
        Failure(
          code: 'backup_import_in_progress',
          message: 'Backup import is already in progress.',
        ),
      );
}
