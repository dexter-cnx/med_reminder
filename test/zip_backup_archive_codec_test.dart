import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/backup/application/json_backup_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/application/zip_backup_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_record.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  const codec = ZipBackupArchiveCodec();

  test('ZIP codec round-trips the backup.json manifest', () async {
    final snapshot = _snapshot();

    final encoded = await codec.encode(snapshot);
    final bytes = encoded.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final decoded = await codec.decode(bytes);

    decoded.fold(
      onSuccess: (value) {
        expect(value.schemaVersion, snapshot.schemaVersion);
        expect(value.exportedAt, snapshot.exportedAt);
        expect(value.records, hasLength(1));
        expect(value.records.single.namespace, 'medication');
        expect(value.records.single.id, 'med-1');
      },
      onFailure: (failure) => fail(failure.toString()),
    );
  });

  test('encoded ZIP contains one authoritative backup.json file', () async {
    final encoded = await codec.encode(_snapshot());
    final bytes = encoded.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    expect(archive, hasLength(1));
    expect(archive.single.name, JsonBackupArchiveCodec.manifestFileName);
    expect(archive.single.isFile, isTrue);
    expect(archive.single.readBytes(), isNotEmpty);
  });

  test('encoding the same snapshot is deterministic', () async {
    final snapshot = _snapshot();

    final first = await codec.encode(snapshot);
    final second = await codec.encode(snapshot);
    final firstBytes = first.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final secondBytes = second.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );

    expect(secondBytes, firstBytes);
  });

  test('decode rejects corrupt ZIP bytes', () async {
    final result = await codec.decode(Uint8List.fromList(<int>[1, 2, 3, 4]));

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected corrupt ZIP failure.'),
      onFailure: (failure) => expect(failure.code, 'backup_zip_invalid'),
    );
  });

  test('decode rejects ZIPs without backup.json', () async {
    final archive = Archive()
      ..add(ArchiveFile.string('other.txt', 'not a backup'));
    final bytes = ZipEncoder().encodeBytes(archive);

    final result = await codec.decode(bytes);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected missing manifest failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_zip_manifest_missing');
      },
    );
  });

  test('decode rejects duplicate archive paths', () async {
    final manifest = await const JsonBackupArchiveCodec().encode(_snapshot());
    final manifestBytes = manifest.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          JsonBackupArchiveCodec.manifestFileName,
          manifestBytes,
        ),
      )
      ..add(
        ArchiveFile.bytes(
          JsonBackupArchiveCodec.manifestFileName,
          manifestBytes,
        ),
      );
    final bytes = ZipEncoder().encodeBytes(archive);

    final result = await codec.decode(bytes);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected duplicate path failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_zip_duplicate_path');
      },
    );
  });
}

BackupSnapshot _snapshot() => BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      exportedAt: DateTime.utc(2026, 8, 24, 12, 30),
      records: <BackupRecord>[
        BackupRecord(
          namespace: 'medication',
          id: 'med-1',
          payload: <String, Object?>{
            'version': 1,
            'name': 'Example',
          },
        ),
      ],
    );
