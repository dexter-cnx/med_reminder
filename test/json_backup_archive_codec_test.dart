import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/backup/application/json_backup_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_record.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  const codec = JsonBackupArchiveCodec();

  test('backup manifest codec round-trips snapshot data', () async {
    final snapshot = BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      exportedAt: DateTime.utc(2026, 8, 24, 12, 30),
      records: <BackupRecord>[
        BackupRecord(
          namespace: 'medication',
          id: 'med-1',
          payload: <String, Object?>{
            'version': 1,
            'name': 'Example',
            'times': <Object?>['08:00', '20:00'],
            'meta': <String, Object?>{'asNeeded': false},
          },
        ),
      ],
    );

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
        expect(value.records.single.payload['name'], 'Example');
        expect(
            value.records.single.payload['times'], <Object?>['08:00', '20:00']);
      },
      onFailure: (failure) => fail(failure.toString()),
    );
  });

  test('encoded bytes contain the versioned backup.json manifest', () async {
    final snapshot = BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      exportedAt: DateTime.utc(2026, 8, 24),
      records: <BackupRecord>[],
    );

    final encoded = await codec.encode(snapshot);
    final bytes = encoded.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;

    expect(JsonBackupArchiveCodec.manifestFileName, 'backup.json');
    expect(manifest['manifestVersion'], JsonBackupArchiveCodec.manifestVersion);
    expect(manifest['schemaVersion'], BackupSnapshot.currentSchemaVersion);
    expect(manifest['exportedAt'], '2026-08-24T00:00:00.000Z');
    expect(manifest['records'], isEmpty);
  });

  test('decode rejects unsupported manifest versions', () async {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'manifestVersion': JsonBackupArchiveCodec.manifestVersion + 1,
          'schemaVersion': BackupSnapshot.currentSchemaVersion,
          'exportedAt': '2026-08-24T00:00:00.000Z',
          'records': <Object?>[],
        }),
      ),
    );

    final result = await codec.decode(bytes);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected unsupported manifest failure.'),
      onFailure: (failure) {
        expect(failure.code, 'backup_manifest_version_unsupported');
      },
    );
  });

  test('decode rejects malformed or structurally invalid manifests', () async {
    final malformed = await codec.decode(
      Uint8List.fromList(utf8.encode('{not-json')),
    );
    final invalidRecord = await codec.decode(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'manifestVersion': JsonBackupArchiveCodec.manifestVersion,
            'schemaVersion': BackupSnapshot.currentSchemaVersion,
            'exportedAt': '2026-08-24T00:00:00.000Z',
            'records': <Object?>[
              <String, Object?>{
                'namespace': 'medication',
                'id': 'med-1',
                'payload': 'not-a-map',
              },
            ],
          }),
        ),
      ),
    );

    expect(malformed.isFailure, isTrue);
    expect(invalidRecord.isFailure, isTrue);
  });
}
