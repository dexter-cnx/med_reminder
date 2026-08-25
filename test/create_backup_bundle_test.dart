import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_attachment_source.dart';
import 'package:med_reminder_offline/features/backup/application/backup_bundle_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/application/backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/create_backup_bundle.dart';
import 'package:med_reminder_offline/features/backup/application/medication_photo_attachment_collector.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_attachment.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  test('capture failure stops before bundle encoding', () async {
    final codec = _FakeBundleCodec();
    final useCase = CreateBackupBundle(
      dataPort: _FakeDataPort(
        captureResult: const Failed<BackupSnapshot>(
          Failure(code: 'capture_failed', message: 'capture failed'),
        ),
      ),
      attachmentCollector: const MedicationPhotoAttachmentCollector(
        source: _UnusedAttachmentSource(),
      ),
      codec: codec,
    );

    final result = await useCase();

    expect(result.isFailure, isTrue);
    expect(codec.encodeCalls, 0);
  });

  test('successful capture is encoded as a bundle', () async {
    final codec = _FakeBundleCodec();
    final snapshot = BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      exportedAt: DateTime.utc(2026, 8, 25),
      records: const [],
    );
    final useCase = CreateBackupBundle(
      dataPort: _FakeDataPort(captureResult: Success(snapshot)),
      attachmentCollector: const MedicationPhotoAttachmentCollector(
        source: _UnusedAttachmentSource(),
      ),
      codec: codec,
    );

    final result = await useCase();

    expect(result.isSuccess, isTrue);
    expect(codec.encodeCalls, 1);
    expect(codec.lastBundle?.snapshot.exportedAt, snapshot.exportedAt);
    expect(codec.lastBundle?.attachments, isEmpty);
  });
}

final class _FakeDataPort implements BackupDataPort {
  _FakeDataPort({required this.captureResult});

  final Result<BackupSnapshot> captureResult;

  @override
  Future<Result<BackupSnapshot>> capture() async => captureResult;

  @override
  Future<Result<void>> restoreAtomically(BackupSnapshot snapshot) async =>
      const Success<void>(null);
}

final class _UnusedAttachmentSource implements BackupAttachmentSource {
  const _UnusedAttachmentSource();

  @override
  Future<Result<Uint8List>> read(String sourcePath) async =>
      throw StateError('No attachment should be read in this test.');
}

final class _FakeBundleCodec implements BackupBundleArchiveCodec {
  int encodeCalls = 0;
  BackupAttachmentBundle? lastBundle;

  @override
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle) async {
    encodeCalls++;
    lastBundle = bundle;
    return Success<Uint8List>(Uint8List.fromList(<int>[80, 75, 3, 4]));
  }

  @override
  Future<Result<BackupAttachmentBundle>> decodeBundle(
    Uint8List archiveBytes,
  ) async =>
      throw UnimplementedError();
}
