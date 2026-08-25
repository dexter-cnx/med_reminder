import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup reminder rebuild reuses shared reconciliation transaction', () {
    final source = File(
      'lib/features/backup/application/rebuild_restored_reminders.dart',
    ).readAsStringSync();

    expect(source, contains('ReminderReconciliationTransaction'));
    expect(source, isNot(contains('medication.isExpired(')));
    expect(source, isNot(contains('reminderScheduler.schedule(')));
  });
}
