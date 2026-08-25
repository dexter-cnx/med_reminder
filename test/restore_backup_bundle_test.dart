import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/backup/application/backup_attachment_restore_port.dart';
import 'package:med_reminder_offline/features/backup/application/backup_bundle_archive_codec.dart';
import 'package:med_reminder_offline/features/backup/application/backup_data_port.dart';
import 'package:med_reminder_offline/features/backup/application/commit_prepared_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/application/prepare_backup_restore.dart';
import 'package:med_reminder_offline/features/backup/application/restore_backup_bundle.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_attachment.dart';
import 'package:med_reminder_offline/features/backup/domain/entities/backup_snapshot.dart';

void main() {
  test('coordinator stops before staging when decode fails', () async {
    final attachments = _FakeAttachmentRestorePort();
    final dataPort = _FakeDataPort();
    var refreshed = false;
    final restore = RestoreBackupBundle(
      prepare: PrepareBackupRestore(
        codec: const _FailingCodec(),
        attachmentRestorePort: attachments,
      ),
      commit: CommitPreparedBackupRestore(
        dataPort: dataPort,
        attachmentRestorePort: attachments,
      ),
      onSuccess: (_) async {
        refreshed = true;
        return const Success<void>(null);
      },
    );

    final result = await restore(Uint8List(0));

    expect(result.isFailure, isTrue);
    expect(attachments.stageCalls, 0);
    expect(attachments.commitCalls, 0);
    expect(dataPort.restoreCalls, 0);
    expect(refreshed, isFalse);
  });

  test(
    'captures old reminder ids before commit and passes them to repair',
    () async {
      final events = <String>[];
      final attachments = _FakeAttachmentRestorePort(events: events);
      final dataPort = _FakeDataPort(events: events);
      final restore = RestoreBackupBundle(
        prepare: PrepareBackupRestore(
          codec: _SuccessfulCodec(_bundle()),
          attachmentRestorePort: attachments,
        ),
        commit: CommitPreparedBackupRestore(
          dataPort: dataPort,
          attachmentRestorePort: attachments,
        ),
        captureReminderState: () {
          events.add('capture');
          return const Success<List<int>>(<int>[41, 42]);
        },
        onSuccess: (previousIds) async {
          events.add('repair:${previousIds.join(',')}');
          return const Success<void>(null);
        },
      );

      final result = await restore(Uint8List(0));

      expect(result.isSuccess, isTrue);
      expect(events, <String>[
        'stage',
        'capture',
        'commit:stage-1',
        'restore',
        'repair:41,42',
      ]);
    },
  );

  test('reminder capture failure discards prepared stage before commit', () async {
    final events = <String>[];
    final attachments = _FakeAttachmentRestorePort(events: events);
    final dataPort = _FakeDataPort(events: events);
    final restore = RestoreBackupBundle(
      prepare: PrepareBackupRestore(
        codec: _SuccessfulCodec(_bundle()),
        attachmentRestorePort: attachments,
      ),
      commit: CommitPreparedBackupRestore(
        dataPort: dataPort,
        attachmentRestorePort: attachments,
      ),
      captureReminderState: () {
        events.add('capture');
        return const Failed<List<int>>(
          Failure(
            code: 'reminder_state_capture_failed',
            message: 'Reminder state could not be captured.',
          ),
        );
      },
    );

    final result = await restore(Uint8List(0));

    expect(result, isA<Failed<void>>());
    expect(
      (result as Failed<void>).failure.code,
      'reminder_state_capture_failed',
    );
    expect(events, <String>['stage', 'capture', 'discard:stage-1']);
    expect(attachments.commitCalls, 0);
    expect(dataPort.restoreCalls, 0);
  });

  test(
    'reminder capture cleanup failure surfaces explicit stage failure',
    () async {
      final events = <String>[];
      final attachments = _FakeAttachmentRestorePort(
        events: events,
        discardResult: const Failed<void>(
          Failure(code: 'discard_failed', message: 'Discard failed.'),
        ),
      );
      final dataPort = _FakeDataPort(events: events);
      final restore = RestoreBackupBundle(
        prepare: PrepareBackupRestore(
          codec: _SuccessfulCodec(_bundle()),
          attachmentRestorePort: attachments,
        ),
        commit: CommitPreparedBackupRestore(
          dataPort: dataPort,
          attachmentRestorePort: attachments,
        ),
        captureReminderState: () => const Failed<List<int>>(
          Failure(
            code: 'reminder_state_capture_failed',
            message: 'Reminder state could not be captured.',
          ),
        ),
      );

      final result = await restore(Uint8List(0));

      expect(result, isA<Failed<void>>());
      expect(
        (result as Failed<void>).failure.code,
        'backup_restore_stage_cleanup_failed',
      );
      expect(events, <String>['stage', 'discard:stage-1']);
      expect(attachments.commitCalls, 0);
      expect(dataPort.restoreCalls, 0);
    },
  );

  test(
    'post-restore repair failure does not roll durable restore back',
    () async {
      final events = <String>[];
      final attachments = _FakeAttachmentRestorePort(events: events);
      final dataPort = _FakeDataPort(events: events);
      final restore = RestoreBackupBundle(
        prepare: PrepareBackupRestore(
          codec: _SuccessfulCodec(_bundle()),
          attachmentRestorePort: attachments,
        ),
        commit: CommitPreparedBackupRestore(
          dataPort: dataPort,
          attachmentRestorePort: attachments,
        ),
        onSuccess: (_) async {
          events.add('repair');
          return const Failed<void>(
            Failure(
              code: 'backup_restore_reminder_rebuild_failed',
              message: 'Reminder rebuild failed.',
            ),
          );
        },
      );

      final result = await restore(Uint8List(0));

      result.fold(
        onSuccess: (_) => fail('Expected repair failure.'),
        onFailure: (failure) =>
            expect(failure.code, 'backup_restore_reminder_rebuild_failed'),
      );
      expect(events, <String>['stage', 'commit:stage-1', 'restore', 'repair']);
      expect(events.where((event) => event.startsWith('rollback:')), isEmpty);
    },
  );

  test('coordinator skips repair when data restore fails', () async {
    final events = <String>[];
    final attachments = _FakeAttachmentRestorePort(events: events);
    final dataPort = _FakeDataPort(
      events: events,
      restoreResult: const Failed<void>(
        Failure(code: 'restore_failed', message: 'Restore failed.'),
      ),
    );
    final restore = RestoreBackupBundle(
      prepare: PrepareBackupRestore(
        codec: _SuccessfulCodec(_bundle()),
        attachmentRestorePort: attachments,
      ),
      commit: CommitPreparedBackupRestore(
        dataPort: dataPort,
        attachmentRestorePort: attachments,
      ),
      onSuccess: (_) async {
        events.add('repair');
        return const Success<void>(null);
      },
    );

    final result = await restore(Uint8List(0));

    expect(result.isFailure, isTrue);
    expect(events, <String>[
      'stage',
      'commit:stage-1',
      'restore',
      'rollback:stage-1',
    ]);
  });
}

BackupAttachmentBundle _bundle() => BackupAttachmentBundle(
  snapshot: BackupSnapshot(
    schemaVersion: BackupSnapshot.currentSchemaVersion,
    exportedAt: DateTime.utc(2026, 8, 25),
    records: const [],
  ),
  attachments: const <BackupAttachment>[],
);

final class _SuccessfulCodec implements BackupBundleArchiveCodec {
  const _SuccessfulCodec(this.bundle);

  final BackupAttachmentBundle bundle;

  @override
  Future<Result<BackupAttachmentBundle>> decodeBundle(
    Uint8List archiveBytes,
  ) async => Success<BackupAttachmentBundle>(bundle);

  @override
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle) {
    throw UnimplementedError();
  }
}

final class _FailingCodec implements BackupBundleArchiveCodec {
  const _FailingCodec();

  @override
  Future<Result<BackupAttachmentBundle>> decodeBundle(
    Uint8List archiveBytes,
  ) async => const Failed<BackupAttachmentBundle>(
    Failure(code: 'decode_failed', message: 'Decode failed.'),
  );

  @override
  Future<Result<Uint8List>> encodeBundle(BackupAttachmentBundle bundle) {
    throw UnimplementedError();
  }
}

final class _FakeAttachmentRestorePort implements BackupAttachmentRestorePort {
  _FakeAttachmentRestorePort({
    List<String>? events,
    this.discardResult = const Success<void>(null),
  }) : events = events ?? <String>[];

  int stageCalls = 0;
  int commitCalls = 0;
  final List<String> events;
  final Result<void> discardResult;

  @override
  Future<Result<StagedBackupAttachments>> stage(
    List<BackupAttachment> attachments,
  ) async {
    stageCalls++;
    events.add('stage');
    return Success<StagedBackupAttachments>(
      StagedBackupAttachments(
        stageId: 'stage-1',
        pathsByArchivePath: const <String, StagedBackupAttachmentPath>{},
      ),
    );
  }

  @override
  Future<Result<void>> commit(String stageId) async {
    commitCalls++;
    events.add('commit:$stageId');
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> rollback(String stageId) async {
    events.add('rollback:$stageId');
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> discard(String stageId) async {
    events.add('discard:$stageId');
    return discardResult;
  }
}

final class _FakeDataPort implements BackupDataPort {
  _FakeDataPort({
    List<String>? events,
    this.restoreResult = const Success<void>(null),
  }) : events = events ?? <String>[];

  final List<String> events;
  final Result<void> restoreResult;
  int restoreCalls = 0;

  @override
  Future<Result<BackupSnapshot>> capture() async => Success<BackupSnapshot>(
    BackupSnapshot(
      schemaVersion: BackupSnapshot.currentSchemaVersion,
      exportedAt: DateTime.utc(2026, 8, 25),
      records: const [],
    ),
  );

  @override
  Future<Result<void>> restoreAtomically(BackupSnapshot snapshot) async {
    restoreCalls++;
    events.add('restore');
    return restoreResult;
  }
}
