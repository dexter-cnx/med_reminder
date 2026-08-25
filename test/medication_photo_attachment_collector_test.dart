import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_attachment_source.dart';
import 'package:med_reminder_offline/features/backup/application/medication_backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/medication_photo_attachment_collector.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_record.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  test(
    'collector rewrites medication image paths to deterministic archive paths',
    () async {
      final source = _FakeAttachmentSource(<String, Uint8List>{
        '/documents/med_photos/photo.PNG': Uint8List.fromList(<int>[1, 2, 3]),
      });
      final collector = MedicationPhotoAttachmentCollector(source: source);
      final snapshot = _snapshot(
        BackupRecord(
          namespace: MedicationBackupDataPort.medicationNamespace,
          id: 'med 1/alpha',
          payload: <String, Object?>{
            'version': 1,
            'id': 'med 1/alpha',
            'imagePath': '/documents/med_photos/photo.PNG',
          },
        ),
      );

      final result = await collector.collect(snapshot);

      result.fold(
        onSuccess: (bundle) {
          expect(bundle.attachments, hasLength(1));
          expect(
            bundle.attachments.single.archivePath,
            'attachments/medication/med%201%2Falpha.png',
          );
          expect(bundle.attachments.single.bytes, <int>[1, 2, 3]);
          expect(
            bundle.snapshot.records.single.payload['imagePath'],
            'attachments/medication/med%201%2Falpha.png',
          );
        },
        onFailure: (failure) => fail(failure.toString()),
      );
    },
  );

  test('attachment bytes cannot be mutated through a returned view', () async {
    final source = _FakeAttachmentSource(<String, Uint8List>{
      '/documents/med_photos/photo.jpg': Uint8List.fromList(<int>[1, 2, 3]),
    });
    final collector = MedicationPhotoAttachmentCollector(source: source);
    final result = await collector.collect(
      _snapshot(
        BackupRecord(
          namespace: MedicationBackupDataPort.medicationNamespace,
          id: 'med-1',
          payload: <String, Object?>{
            'version': 1,
            'id': 'med-1',
            'imagePath': '/documents/med_photos/photo.jpg',
          },
        ),
      ),
    );

    result.fold(
      onSuccess: (bundle) {
        final exposed = bundle.attachments.single.bytes;
        exposed[0] = 99;
        expect(bundle.attachments.single.bytes, <int>[1, 2, 3]);
      },
      onFailure: (failure) => fail(failure.toString()),
    );
  });

  test('collector leaves records without photos unchanged', () async {
    const collector = MedicationPhotoAttachmentCollector(
      source: _FakeAttachmentSource(<String, Uint8List>{}),
    );
    final record = BackupRecord(
      namespace: MedicationBackupDataPort.medicationNamespace,
      id: 'med-1',
      payload: <String, Object?>{
        'version': 1,
        'id': 'med-1',
        'imagePath': null,
      },
    );

    final result = await collector.collect(_snapshot(record));

    result.fold(
      onSuccess: (bundle) {
        expect(bundle.attachments, isEmpty);
        expect(bundle.snapshot.records.single.payload['imagePath'], isNull);
      },
      onFailure: (failure) => fail(failure.toString()),
    );
  });

  test('collector aborts when a referenced photo cannot be read', () async {
    const collector = MedicationPhotoAttachmentCollector(
      source: _FailingAttachmentSource(),
    );
    final snapshot = _snapshot(
      BackupRecord(
        namespace: MedicationBackupDataPort.medicationNamespace,
        id: 'med-1',
        payload: <String, Object?>{
          'version': 1,
          'id': 'med-1',
          'imagePath': '/missing/photo.jpg',
        },
      ),
    );

    final result = await collector.collect(snapshot);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected attachment read failure.'),
      onFailure: (failure) => expect(failure.code, 'attachment_read_failed'),
    );
  });
}

BackupSnapshot _snapshot(BackupRecord record) => BackupSnapshot(
  schemaVersion: BackupSnapshot.currentSchemaVersion,
  exportedAt: DateTime.utc(2026, 8, 24),
  records: <BackupRecord>[record],
);

final class _FakeAttachmentSource implements BackupAttachmentSource {
  const _FakeAttachmentSource(this.values);

  final Map<String, Uint8List> values;

  @override
  Future<Result<Uint8List>> read(String sourcePath) async {
    final bytes = values[sourcePath];
    if (bytes == null) {
      return const Failed<Uint8List>(
        Failure(code: 'missing', message: 'Missing attachment.'),
      );
    }
    return Success<Uint8List>(bytes);
  }
}

final class _FailingAttachmentSource implements BackupAttachmentSource {
  const _FailingAttachmentSource();

  @override
  Future<Result<Uint8List>> read(String sourcePath) async {
    return const Failed<Uint8List>(
      Failure(
        code: 'attachment_read_failed',
        message: 'Simulated attachment read failure.',
      ),
    );
  }
}
