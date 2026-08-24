import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/application/backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/create_backup.dart';
import 'package:med_reminder_offline/features/backup/application/restore_backup.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_record.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

class _FakeDataPort implements BackupDataPort {
  _FakeDataPort(this.captureResult);

  Result<BackupSnapshot> captureResult;
  BackupSnapshot? restoredSnapshot;

  @override
  Future<Result<BackupSnapshot>> capture() async => captureResult;

  @override
  Future<Result<void>> restoreAtomically(BackupSnapshot snapshot) async {
    restoredSnapshot = snapshot;
    return const Success<void>(null);
  }
}

class _FakeCodec implements BackupArchiveCodec {
  _FakeCodec({required this.decodeResult});

  Result<BackupSnapshot> decodeResult;
  BackupSnapshot? encodedSnapshot;

  @override
  Future<Result<BackupSnapshot>> decode(Uint8List archiveBytes) async {
    return decodeResult;
  }

  @override
  Future<Result<Uint8List>> encode(BackupSnapshot snapshot) async {
    encodedSnapshot = snapshot;
    return Success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }
}

BackupSnapshot _snapshot({int schemaVersion = 1}) {
  return BackupSnapshot(
    schemaVersion: schemaVersion,
    exportedAt: DateTime.utc(2026, 8, 24),
    records: <BackupRecord>[
      BackupRecord(
        namespace: 'medication',
        id: 'med-1',
        payload: <String, Object?>{'name': 'Example'},
      ),
    ],
  );
}

void main() {
  test('create backup encodes the captured application snapshot', () async {
    final snapshot = _snapshot();
    final dataPort = _FakeDataPort(Success<BackupSnapshot>(snapshot));
    final codec = _FakeCodec(decodeResult: Success<BackupSnapshot>(snapshot));

    final result = await CreateBackup(dataPort: dataPort, codec: codec)();

    expect(result.isSuccess, isTrue);
    expect(codec.encodedSnapshot, same(snapshot));
  });

  test('restore rejects unsupported schema before application mutation', () async {
    final snapshot = _snapshot(schemaVersion: 2);
    final dataPort = _FakeDataPort(Success<BackupSnapshot>(snapshot));
    final codec = _FakeCodec(decodeResult: Success<BackupSnapshot>(snapshot));

    final result = await RestoreBackup(dataPort: dataPort, codec: codec)(
      Uint8List.fromList(<int>[9]),
    );

    expect(result.isFailure, isTrue);
    expect(dataPort.restoredSnapshot, isNull);
  });

  test('restore does not mutate data when archive decoding fails', () async {
    final snapshot = _snapshot();
    final dataPort = _FakeDataPort(Success<BackupSnapshot>(snapshot));
    final codec = _FakeCodec(
      decodeResult: const Failed<BackupSnapshot>(
        Failure(code: 'backup_corrupt', message: 'Corrupt archive'),
      ),
    );

    final result = await RestoreBackup(dataPort: dataPort, codec: codec)(
      Uint8List.fromList(<int>[9]),
    );

    expect(result.isFailure, isTrue);
    expect(dataPort.restoredSnapshot, isNull);
  });

  test('restore forwards a current validated snapshot atomically', () async {
    final snapshot = _snapshot();
    final dataPort = _FakeDataPort(Success<BackupSnapshot>(snapshot));
    final codec = _FakeCodec(decodeResult: Success<BackupSnapshot>(snapshot));

    final result = await RestoreBackup(dataPort: dataPort, codec: codec)(
      Uint8List.fromList(<int>[9]),
    );

    expect(result.isSuccess, isTrue);
    expect(dataPort.restoredSnapshot, same(snapshot));
  });
}
