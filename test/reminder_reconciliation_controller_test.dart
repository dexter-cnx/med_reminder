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

  test('failed reconciliation does not publish refreshed state', () async {
    var successes = 0;
    final controller = ReminderReconciliationController(
      reconcile: () async =>
          const Failed<void>(Failure(code: 'test_failure', message: 'failed')),
      onSuccess: () => successes++,
    );

    await controller.trigger();

    expect(successes, 0);
  });
}
