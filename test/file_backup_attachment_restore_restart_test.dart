import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_attachment.dart';
import 'package:med_reminder_offline/features/backup/infrastructure/file_backup_attachment_restore_port.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory documents;
  late Directory staging;

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'backup_restore_restart_test_',
    );
    documents = Directory(p.join(root.path, 'documents'));
    staging = Directory(p.join(root.path, 'staging'));
    await documents.create(recursive: true);
    await staging.create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  FileBackupAttachmentRestorePort port({DateTime Function()? now}) =>
      FileBackupAttachmentRestorePort(
        documentsPath: documents.path,
        stagingRootPath: staging.path,
        now: now,
      );

  test('persisted stage can commit from a new port instance', () async {
    final firstProcess = port();
    final staged =
        (await firstProcess.stage(<BackupAttachment>[
          BackupAttachment(
            archivePath: 'attachments/medication/med-1.jpg',
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ])).fold(
          onSuccess: (value) => value,
          onFailure: (failure) => fail(failure.toString()),
        );
    final path = staged.pathsByArchivePath.values.single;

    final restartedProcess = port();
    final result = await restartedProcess.commit(staged.stageId);

    expect(result.isSuccess, isTrue);
    expect(await File(path.stagedPath).exists(), isFalse);
    expect(await File(path.finalPath).readAsBytes(), <int>[1, 2, 3]);
    expect(
      await File(p.join(staging.path, staged.stageId, 'stage.json')).exists(),
      isTrue,
    );
  });

  test('persisted committed stage can roll back after restart', () async {
    final firstProcess = port();
    final staged =
        (await firstProcess.stage(<BackupAttachment>[
          BackupAttachment(
            archivePath: 'attachments/medication/med-1.png',
            bytes: Uint8List.fromList(<int>[4, 5, 6]),
          ),
        ])).fold(
          onSuccess: (value) => value,
          onFailure: (failure) => fail(failure.toString()),
        );
    final path = staged.pathsByArchivePath.values.single;
    expect((await firstProcess.commit(staged.stageId)).isSuccess, isTrue);
    expect(await File(path.finalPath).exists(), isTrue);

    final restartedProcess = port();
    final result = await restartedProcess.rollback(staged.stageId);

    expect(result.isSuccess, isTrue);
    expect(await File(path.finalPath).exists(), isFalse);
    expect(
      await Directory(p.join(staging.path, staged.stageId)).exists(),
      isFalse,
    );
  });

  test('startup cleanup removes stale persisted stages only', () async {
    final firstProcess = port(now: () => DateTime.utc(2026, 8, 23, 7));
    final stale =
        (await firstProcess.stage(<BackupAttachment>[
          BackupAttachment(
            archivePath: 'attachments/medication/stale.jpg',
            bytes: Uint8List.fromList(<int>[7]),
          ),
        ])).fold(
          onSuccess: (value) => value,
          onFailure: (failure) => fail(failure.toString()),
        );

    final secondProcess = port(now: () => DateTime.utc(2026, 8, 25, 6, 30));
    final fresh =
        (await secondProcess.stage(<BackupAttachment>[
          BackupAttachment(
            archivePath: 'attachments/medication/fresh.jpg',
            bytes: Uint8List.fromList(<int>[8]),
          ),
        ])).fold(
          onSuccess: (value) => value,
          onFailure: (failure) => fail(failure.toString()),
        );

    final restartedProcess = port(now: () => DateTime.utc(2026, 8, 25, 7));
    final result = await restartedProcess.cleanupStaleStages(
      olderThan: const Duration(hours: 24),
    );

    result.fold(
      onSuccess: (count) => expect(count, 1),
      onFailure: (failure) => fail(failure.toString()),
    );
    expect(
      await Directory(p.join(staging.path, stale.stageId)).exists(),
      isFalse,
    );
    expect(
      await Directory(p.join(staging.path, fresh.stageId)).exists(),
      isTrue,
    );
  });
}
