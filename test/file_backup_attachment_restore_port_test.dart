import 'dart:convert';
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
    root = await Directory.systemTemp.createTemp('backup_restore_port_test_');
    documents = Directory(p.join(root.path, 'documents'));
    staging = Directory(p.join(root.path, 'staging'));
    await documents.create(recursive: true);
    await staging.create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('stage reserves final med_photos path and commit promotes bytes',
      () async {
    final port = FileBackupAttachmentRestorePort(
      documentsPath: documents.path,
      stagingRootPath: staging.path,
    );

    final stagedResult = await port.stage(<BackupAttachment>[
      BackupAttachment(
        archivePath: 'attachments/medication/med-1.PNG',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    ]);

    final staged = stagedResult.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final path = staged.pathsByArchivePath.values.single;
    expect(path.finalPath, contains('${p.separator}med_photos${p.separator}'));
    expect(p.extension(path.finalPath), '.png');
    expect(await File(path.stagedPath).readAsBytes(), <int>[1, 2, 3]);
    expect(await File(path.finalPath).exists(), isFalse);

    final commit = await port.commit(staged.stageId);

    expect(commit.isSuccess, isTrue);
    expect(await File(path.stagedPath).exists(), isFalse);
    expect(await File(path.finalPath).readAsBytes(), <int>[1, 2, 3]);
  });

  test('rollback removes committed files and stage metadata', () async {
    final port = FileBackupAttachmentRestorePort(
      documentsPath: documents.path,
      stagingRootPath: staging.path,
    );
    final staged = (await port.stage(<BackupAttachment>[
      BackupAttachment(
        archivePath: 'attachments/medication/med-1.jpg',
        bytes: Uint8List.fromList(<int>[4, 5]),
      ),
    ]))
        .fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final path = staged.pathsByArchivePath.values.single;
    expect((await port.commit(staged.stageId)).isSuccess, isTrue);

    final rollback = await port.rollback(staged.stageId);

    expect(rollback.isSuccess, isTrue);
    expect(await File(path.finalPath).exists(), isFalse);
    expect(
      await Directory(p.join(staging.path, staged.stageId)).exists(),
      isFalse,
    );
  });

  test('discard removes an uncommitted stage without touching live photos',
      () async {
    final port = FileBackupAttachmentRestorePort(
      documentsPath: documents.path,
      stagingRootPath: staging.path,
    );
    final live = File(p.join(documents.path, 'med_photos', 'existing.jpg'));
    await live.parent.create(recursive: true);
    await live.writeAsBytes(<int>[9]);
    final staged = (await port.stage(<BackupAttachment>[
      BackupAttachment(
        archivePath: 'attachments/medication/med-1.jpg',
        bytes: Uint8List.fromList(<int>[1]),
      ),
    ]))
        .fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );

    final result = await port.discard(staged.stageId);

    expect(result.isSuccess, isTrue);
    expect(
      await Directory(p.join(staging.path, staged.stageId)).exists(),
      isFalse,
    );
    expect(await live.readAsBytes(), <int>[9]);
  });

  test('commit rejects metadata paths escaping managed roots', () async {
    final port = FileBackupAttachmentRestorePort(
      documentsPath: documents.path,
      stagingRootPath: staging.path,
    );
    final staged = (await port.stage(<BackupAttachment>[
      BackupAttachment(
        archivePath: 'attachments/medication/med-1.jpg',
        bytes: Uint8List.fromList(<int>[1]),
      ),
    ]))
        .fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );
    final metadata = File(p.join(staging.path, staged.stageId, 'stage.json'));
    final outside = p.join(root.path, 'outside.jpg');
    final decoded =
        jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
    final entries = decoded['entries'] as List<dynamic>;
    (entries.single as Map<String, dynamic>)['finalPath'] = outside;
    await metadata.writeAsString(jsonEncode(decoded));

    final result = await port.commit(staged.stageId);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected invalid stage metadata failure.'),
      onFailure: (failure) =>
          expect(failure.code, 'backup_restore_stage_invalid'),
    );
    expect(await File(outside).exists(), isFalse);
  });

  test('commit rejects symlink traversal in managed photo paths', () async {
    if (Platform.isWindows) return;

    final port = FileBackupAttachmentRestorePort(
      documentsPath: documents.path,
      stagingRootPath: staging.path,
    );
    final staged = (await port.stage(<BackupAttachment>[
      BackupAttachment(
        archivePath: 'attachments/medication/med-1.jpg',
        bytes: Uint8List.fromList(<int>[7]),
      ),
    ]))
        .fold(
      onSuccess: (value) => value,
      onFailure: (failure) => fail(failure.toString()),
    );

    final outsideDirectory = Directory(p.join(root.path, 'outside'));
    await outsideDirectory.create(recursive: true);
    final photoDirectory = Directory(p.join(documents.path, 'med_photos'));
    final link = Link(p.join(photoDirectory.path, 'link'));
    await link.create(outsideDirectory.path);

    final metadata = File(p.join(staging.path, staged.stageId, 'stage.json'));
    final decoded =
        jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
    final entries = decoded['entries'] as List<dynamic>;
    (entries.single as Map<String, dynamic>)['finalPath'] =
        p.join(link.path, 'victim.jpg');
    await metadata.writeAsString(jsonEncode(decoded));

    final result = await port.commit(staged.stageId);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected symlink traversal rejection.'),
      onFailure: (failure) =>
          expect(failure.code, 'backup_restore_stage_invalid'),
    );
    expect(await File(p.join(outsideDirectory.path, 'victim.jpg')).exists(),
        isFalse);
  });

  test('stage returns cleanup failure instead of throwing', () async {
    final invalidRoot = File(p.join(root.path, 'not-a-directory'));
    await invalidRoot.writeAsString('blocked');
    final port = FileBackupAttachmentRestorePort(
      documentsPath: documents.path,
      stagingRootPath: invalidRoot.path,
      deleteDirectory: (_) async => throw const FileSystemException(
        'cleanup failed',
      ),
    );

    final result = await port.stage(<BackupAttachment>[
      BackupAttachment(
        archivePath: 'attachments/medication/med-1.jpg',
        bytes: Uint8List.fromList(<int>[1]),
      ),
    ]);

    expect(result.isFailure, isTrue);
    result.fold(
      onSuccess: (_) => fail('Expected cleanup failure.'),
      onFailure: (failure) => expect(
        failure.code,
        'backup_restore_attachment_stage_cleanup_failed',
      ),
    );
  });

  test('cleanupStaleStages removes only expired stage directories', () async {
    final now = DateTime.utc(2026, 8, 25, 7);
    final port = FileBackupAttachmentRestorePort(
      documentsPath: documents.path,
      stagingRootPath: staging.path,
      now: () => now,
    );
    final stale = Directory(p.join(staging.path, 'stale'));
    final fresh = Directory(p.join(staging.path, 'fresh'));
    await stale.create(recursive: true);
    await fresh.create(recursive: true);
    await File(p.join(stale.path, 'stage.json')).writeAsString(
      '{"stageId":"stale","createdAt":"2026-08-23T00:00:00.000Z","entries":[]}',
    );
    await File(p.join(fresh.path, 'stage.json')).writeAsString(
      '{"stageId":"fresh","createdAt":"2026-08-25T06:30:00.000Z","entries":[]}',
    );

    final result = await port.cleanupStaleStages(
      olderThan: const Duration(hours: 24),
    );

    result.fold(
      onSuccess: (count) => expect(count, 1),
      onFailure: (failure) => fail(failure.toString()),
    );
    expect(await stale.exists(), isFalse);
    expect(await fresh.exists(), isTrue);
  });
}
