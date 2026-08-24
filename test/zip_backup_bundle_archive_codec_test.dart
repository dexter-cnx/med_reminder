import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/json_backup_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/application/zip_backup_bundle_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_attachment.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_record.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  const codec = ZipBackupBundleArchiveCodec();

  test('ZIP bundle round-trips manifest and referenced photo bytes', () async {
    final bundle = BackupAttachmentBundle(
      snapshot: _snapshot('attachments/medication/med-1.png'),
      attachments: <BackupAttachment>[
        BackupAttachment(
          archivePath: 'attachments/medication/med-1.png',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      ],
    );

    final encoded = await codec.encodeBundle(bundle);
    final bytes = encoded.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final decoded = await codec.decodeBundle(bytes);

    decoded.fold(
      onSuccess: (value) {
        expect(
          value.snapshot.records.single.payload['imagePath'],
          'attachments/medication/med-1.png',
        );
        expect(value.attachments, hasLength(1));
        expect(value.attachments.single.bytes, <int>[1, 2, 3]);
      },
      onFailure: (failure) => fail(failure.toString()),
    );
  });

  test('encode rejects unsafe attachment paths', () async {
    final bundle = BackupAttachmentBundle(
      snapshot: _snapshot('../photo.png'),
      attachments: <BackupAttachment>[
        BackupAttachment(
          archivePath: '../photo.png',
          bytes: Uint8List.fromList(<int>[1]),
        ),
      ],
    );

    final result = await codec.encodeBundle(bundle);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected unsafe attachment path failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_attachment_path_invalid');
      },
    );
  });

  test('decode rejects unsafe medication image paths in manifest', () async {
    final manifest = await const JsonBackupArchiveCodec().encode(
      _snapshot('../../outside.png'),
    );
    final manifestBytes = manifest.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final archive = Archive()
      ..add(ArchiveFile.bytes('backup.json', manifestBytes));
    final bytes = ZipEncoder().encodeBytes(archive);

    final result = await codec.decodeBundle(bytes);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected unsafe manifest path failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_attachment_path_invalid');
      },
    );
  });

  test('decode rejects missing referenced attachments', () async {
    final manifest = await const JsonBackupArchiveCodec().encode(
      _snapshot('attachments/medication/med-1.png'),
    );
    final manifestBytes = manifest.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final archive = Archive()
      ..add(ArchiveFile.bytes('backup.json', manifestBytes));
    final bytes = ZipEncoder().encodeBytes(archive);

    final result = await codec.decodeBundle(bytes);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected missing attachment failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_attachment_missing');
      },
    );
  });

  test('decode rejects unexpected attachment entries', () async {
    final manifest = await const JsonBackupArchiveCodec().encode(
      _snapshot(null),
    );
    final manifestBytes = manifest.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final archive = Archive()
      ..add(ArchiveFile.bytes('backup.json', manifestBytes))
      ..add(
        ArchiveFile.bytes(
          'attachments/medication/unreferenced.png',
          Uint8List.fromList(<int>[9]),
        ),
      );
    final bytes = ZipEncoder().encodeBytes(archive);

    final result = await codec.decodeBundle(bytes);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected unexpected attachment failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_attachment_unexpected');
      },
    );
  });
}

BackupSnapshot _snapshot(String? imagePath) => BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      exportedAt: DateTime.utc(2026, 8, 24),
      records: <BackupRecord>[
        BackupRecord(
          namespace: 'medication',
          id: 'med-1',
          payload: <String, Object?>{
            'version': 1,
            'id': 'med-1',
            'imagePath': imagePath,
          },
        ),
      ],
    );
