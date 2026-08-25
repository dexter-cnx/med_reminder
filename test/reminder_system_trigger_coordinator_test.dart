import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/application/reminder_system_trigger_coordinator.dart';

void main() {
  test('resume refreshes timezone before reconciliation', () async {
    final events = <String>[];
    final coordinator = ReminderSystemTriggerCoordinator(
      refreshTimezoneIfChanged: () async {
        events.add('timezone');
        return true;
      },
      requestNotificationPermission: () async => true,
      requestExactAlarmPermission: () async => true,
      reconcile: () async => events.add('reconcile'),
    );

    await coordinator.onResume();

    expect(events, <String>['timezone', 'reconcile']);
  });

  test('notification permission result is preserved and reconciled', () async {
    var reconciliations = 0;
    final coordinator = ReminderSystemTriggerCoordinator(
      refreshTimezoneIfChanged: () async => false,
      requestNotificationPermission: () async => false,
      requestExactAlarmPermission: () async => true,
      reconcile: () async => reconciliations++,
    );

    final granted = await coordinator.requestNotifications();

    expect(granted, isFalse);
    expect(reconciliations, 1);
  });

  test('exact-alarm permission result is preserved and reconciled', () async {
    var reconciliations = 0;
    final coordinator = ReminderSystemTriggerCoordinator(
      refreshTimezoneIfChanged: () async => false,
      requestNotificationPermission: () async => true,
      requestExactAlarmPermission: () async => false,
      reconcile: () async => reconciliations++,
    );

    final granted = await coordinator.requestExactAlarm();

    expect(granted, isFalse);
    expect(reconciliations, 1);
  });

  test('failed native permission request does not reconcile', () async {
    var reconciliations = 0;
    final coordinator = ReminderSystemTriggerCoordinator(
      refreshTimezoneIfChanged: () async => false,
      requestNotificationPermission: () async => throw StateError('failed'),
      requestExactAlarmPermission: () async => true,
      reconcile: () async => reconciliations++,
    );

    await expectLater(coordinator.requestNotifications(), throwsStateError);
    expect(reconciliations, 0);
  });
}
