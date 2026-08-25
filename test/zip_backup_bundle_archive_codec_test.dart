import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('encode rejects missing referenced attachments', () async {
    final result = await codec.encodeBundle(
      BackupAttachmentBundle(
        snapshot: _snapshot('attachments/medication/med-1.png'),
        attachments: const <BackupAttachment>[],
      ),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected missing attachment failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_attachment_missing');
      },
    );
  });

  test('encode rejects unreferenced attachments', () async {
    final result = await codec.encodeBundle(
      BackupAttachmentBundle(
        snapshot: _snapshot(null),
        attachments: <BackupAttachment>[
          BackupAttachment(
            archivePath: 'attachments/medication/unreferenced.png',
            bytes: Uint8List.fromList(<int>[9]),
          ),
        ],
      ),
    );

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected unexpected attachment failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_attachment_unexpected');
      },
    );
  });

  test('empty medication image path round-trips as photo-less', () async {
    final encoded = await codec.encodeBundle(
      BackupAttachmentBundle(
        snapshot: _snapshot(''),
        attachments: const <BackupAttachment>[],
      ),
    );
    final bytes = encoded.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final decoded = await codec.decodeBundle(bytes);

    decoded.fold(
      onSuccess: (bundle) {
        expect(bundle.snapshot.records.single.payload['imagePath'], '');
        expect(bundle.attachments, isEmpty);
      },
      onFailure: (failure) => fail(failure.toString()),
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

  test(
    'decode rejects oversized uncompressed entries before materializing',
    () async {
      final encoded = await codec.encodeBundle(
        BackupAttachmentBundle(
          snapshot: _snapshot(''),
          attachments: const <BackupAttachment>[],
        ),
      );
      final bytes = Uint8List.fromList(
        encoded.fold(
          onSuccess: (value) => value,
          onFailure: (failure) => fail(failure.toString()),
        ),
      );
      final centralDirectoryOffset = _findCentralDirectoryHeader(bytes);
      expect(centralDirectoryOffset, greaterThanOrEqualTo(0));
      ByteData.sublistView(bytes).setUint32(
        centralDirectoryOffset + 24,
        ZipBackupBundleArchiveCodec.maxUncompressedEntryBytes + 1,
        Endian.little,
      );

      final result = await codec.decodeBundle(bytes);

      expect(result.isFailure, isTrue);
      result.fold(
        onSuccess: (_) => fail('Expected ZIP expansion limit failure.'),
        onFailure: (failure) {
          expect(failure.code, 'backup_zip_expansion_limit_exceeded');
        },
      );
    },
  );
}

int _findCentralDirectoryHeader(Uint8List bytes) {
  for (var index = 0; index <= bytes.length - 4; index++) {
    if (bytes[index] == 0x50 &&
        bytes[index + 1] == 0x4b &&
        bytes[index + 2] == 0x01 &&
        bytes[index + 3] == 0x02) {
      return index;
    }
  }
  return -1;
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
