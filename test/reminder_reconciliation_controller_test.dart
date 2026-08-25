import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/medication/presentation/providers/reminder_reconciliation_providers.dart';

void main() {
  test(
    'concurrent lifecycle triggers coalesce into one queued rerun',
    () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      var calls = 0;
      var successes = 0;

      final controller = ReminderReconciliationController(
        reconcile: () async {
          calls++;
          if (calls == 1) {
            firstStarted.complete();
            await releaseFirst.future;
          }
          return const Success<void>(null);
        },
        onSuccess: () => successes++,
      );

      final first = controller.trigger();
      await firstStarted.future;
      final second = controller.trigger();
      final third = controller.trigger();

      releaseFirst.complete();
      await Future.wait(<Future<void>>[first, second, third]);

      expect(calls, 2);
      expect(successes, 2);
    },
  );

  test(
    'transient reconciliation failure is retried before completion',
    () async {
      var calls = 0;
      var successes = 0;
      final controller = ReminderReconciliationController(
        reconcile: () async {
          calls++;
          if (calls == 1) {
            return const Failed<void>(
              Failure(code: 'transient_failure', message: 'failed once'),
            );
          }
          return const Success<void>(null);
        },
        onSuccess: () => successes++,
      );

      await controller.trigger();

      expect(calls, 2);
      expect(successes, 1);
    },
  );

  test(
    'persistent reconciliation failure does not publish refreshed state',
    () async {
      var calls = 0;
      var successes = 0;
      final controller = ReminderReconciliationController(
        reconcile: () async {
          calls++;
          return const Failed<void>(
            Failure(code: 'test_failure', message: 'failed'),
          );
        },
        onSuccess: () => successes++,
      );

      await controller.trigger();

      expect(calls, 2);
      expect(successes, 0);
    },
  );

  test('queued trigger still runs after a retry succeeds', () async {
    final firstAttemptStarted = Completer<void>();
    final releaseFirstAttempt = Completer<void>();
    var calls = 0;
    var successes = 0;

    final controller = ReminderReconciliationController(
      reconcile: () async {
        calls++;
        if (calls == 1) {
          firstAttemptStarted.complete();
          await releaseFirstAttempt.future;
          return const Failed<void>(
            Failure(code: 'transient_failure', message: 'failed once'),
          );
        }
        return const Success<void>(null);
      },
      onSuccess: () => successes++,
    );

    final lifecycle = controller.trigger();
    await firstAttemptStarted.future;
    final mutationRepair = controller.trigger();
    releaseFirstAttempt.complete();

    await Future.wait(<Future<void>>[lifecycle, mutationRepair]);

    // first run: failed attempt + successful retry; queued mutation: one success
    expect(calls, 3);
    expect(successes, 2);
  });
}
