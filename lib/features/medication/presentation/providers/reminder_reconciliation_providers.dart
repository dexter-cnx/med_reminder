import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../application/reconcile_medication_reminders.dart';
import '../viewmodels/medication_view_model.dart';

final reconcileMedicationRemindersProvider =
    Provider<ReconcileMedicationReminders>(
      (ref) => ReconcileMedicationReminders(
        medicationRepository: ref.watch(medicationRepositoryProvider),
        doseLogRepository: ref.watch(doseLogRepositoryProvider),
        reminderScheduler: ref.watch(medicationReminderSchedulerProvider),
        stockResolver: ref.watch(medicationStockResolverProvider),
      ),
    );

final reminderReconciliationControllerProvider =
    Provider<ReminderReconciliationController>(
      (ref) => ReminderReconciliationController(
        reconcile: ref.watch(reconcileMedicationRemindersProvider),
        onSuccess: () {
          ref.invalidate(medsProvider);
          ref.invalidate(logsProvider);
        },
      ),
    );

final class ReminderReconciliationController {
  ReminderReconciliationController({
    required Future<Result<void>> Function() reconcile,
    required void Function() onSuccess,
    this.maxAttemptsPerRun = 2,
  }) : assert(maxAttemptsPerRun > 0),
       _reconcile = reconcile,
       _onSuccess = onSuccess;

  final Future<Result<void>> Function() _reconcile;
  final void Function() _onSuccess;
  final int maxAttemptsPerRun;

  Future<void>? _running;
  bool _runAgain = false;

  Future<void> trigger() {
    final running = _running;
    if (running != null) {
      _runAgain = true;
      return running;
    }

    final future = _drain();
    _running = future;
    return future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    });
  }

  Future<void> _drain() async {
    do {
      _runAgain = false;
      final result = await _reconcileWithRetry();
      if (result.isSuccess) _onSuccess();
    } while (_runAgain);
  }

  Future<Result<void>> _reconcileWithRetry() async {
    Result<void> result = const Failed<void>(
      Failure(
        code: 'medication_reminder_reconcile_not_started',
        message: 'Medication reminder reconciliation did not start.',
      ),
    );
    for (var attempt = 0; attempt < maxAttemptsPerRun; attempt++) {
      result = await _reconcile();
      if (result.isSuccess) return result;
    }
    return result;
  }
}
