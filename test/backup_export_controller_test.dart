import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_attachment_source.dart';
import 'package:med_reminder_offline/features/backup/application/backup_bundle_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/application/backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/backup_export_port.dart';
import 'package:med_reminder_offline/features/backup/application/create_backup_bundle.dart';
import 'package:med_reminder_offline/features/backup/application/medication_photo_attachment_collector.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_attachment.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';
import 'package:med_reminder_offline/features/backup/presentation/providers/backup_export_providers.dart';

void main() {
  test('share cancellation is returned and busy state is cleared', () async {
    final port = _FakeExportPort(
      result: const Failed<void>(
        Failure(
          code: 'backup_export_cancelled',
          message: 'Share sheet dismissed.',
        ),
      ),
    );
    final controller = BackupExportController(
      createBundle: _successfulCreateBundle(),
      exportPort: port,
      now: () => DateTime(2026, 8, 25, 14, 5, 9),
    );

    final result = await controller.shareBackup();

    expect(result, isA<Failed<void>>());
    expect((result as Failed<void>).failure.code, 'backup_export_cancelled');
    expect(controller.state, isFalse);
    expect(port.shareCalls, 1);
    expect(port.lastFileName, 'besyu-backup-20260825-140509.zip');
  });

  test(
    'share transport failure is preserved and busy state is cleared',
    () async {
      final port = _FakeExportPort(
        result: const Failed<void>(
          Failure(
            code: 'backup_export_share_failed',
            message: 'Share transport failed.',
          ),
        ),
      );
      final controller = BackupExportController(
        createBundle: _successfulCreateBundle(),
        exportPort: port,
      );

      final result = await controller.shareBackup();

      expect(result, isA<Failed<void>>());
      expect(
        (result as Failed<void>).failure.code,
        'backup_export_share_failed',
      );
      expect(controller.state, isFalse);
      expect(port.shareCalls, 1);
    },
  );

  test(
    'concurrent export is rejected without starting a second transfer',
    () async {
      final completer = Completer<Result<void>>();
      final port = _FakeExportPort(completer: completer);
      final controller = BackupExportController(
        createBundle: _successfulCreateBundle(),
        exportPort: port,
      );

      final first = controller.shareBackup();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state, isTrue);

      final second = await controller.shareBackup();

      expect(second, isA<Failed<void>>());
      expect(
        (second as Failed<void>).failure.code,
        'backup_export_in_progress',
      );
      expect(port.shareCalls, 1);

      completer.complete(const Success<void>(null));
      expect((await first).isSuccess, isTrue);
      expect(controller.state, isFalse);
    },
  );
}

CreateBackupBundle _successfulCreateBundle() {
  final snapshot = BackupSnapshot(
    schemaVersion: BackupSnapshot.currentSchemaVersion,
    exportedAt: DateTime.utc(2026, 8, 25),
    records: const [],
  );
  return CreateBackupBundle(
    dataPort: _FakeDataPort(snapshot),
    attachmentCollector: const MedicationPhotoAttachmentCollector(
      source: _UnusedAttachmentSource(),
    ),
    codec: const _FakeBundleCodec(),
  );
}

final class _FakeDataPort implements BackupDataPort {
  const _FakeDataPort(this.snapshot);

  final BackupSnapshot snapshot;

  @override
  Future<Result<BackupSnapshot>> capture() async => Success(snapshot);

  @override
  Future<Result<void>> restoreAtomically(BackupSnapshot snapshot) async =>
      const Success<void>(null);
}

final class _UnusedAttachmentSource implements BackupAttachmentSource {
  const _UnusedAttachmentSource();

  @override
  Future<Result<Uint8List>> read(String sourcePath) async =>
      throw StateError('No attachment should be read.');
}

final class _FakeBundleCodec implements BackupBundleArchiveCodec {
  const _FakeBundleCodec();

  @override
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle) async =>
      Success<Uint8List>(Uint8List.fromList(<int>[80, 75, 3, 4]));

  @override
  Future<Result<BackupAttachmentBundle>> decodeBundle(
    Uint8List archiveBytes,
  ) async => throw UnimplementedError();
}

final class _FakeExportPort implements BackupExportPort {
  _FakeExportPort({this.result, this.completer});

  final Result<void>? result;
  final Completer<Result<void>>? completer;
  int shareCalls = 0;
  String? lastFileName;

  @override
  Future<Result<void>> shareArchive(
    Uint8List archiveBytes, {
    required String fileName,
    BackupShareAnchor? anchor,
  }) async {
    shareCalls++;
    lastFileName = fileName;
    final pending = completer;
    if (pending != null) return pending.future;
    return result ?? const Success<void>(null);
  }
}
