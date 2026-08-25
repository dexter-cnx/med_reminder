import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/application/reminder_system_trigger_coordinator.dart';

void main() {
  test(
    'resume refreshes timezone and permissions before reconciliation',
    () async {
      final events = <String>[];
      final coordinator = ReminderSystemTriggerCoordinator(
        refreshTimezoneIfChanged: () async {
          events.add('timezone');
          return true;
        },
        refreshPermissionStateIfChanged: () async {
          events.add('permissions');
          return true;
        },
        requestNotificationPermission: () async => true,
        requestExactAlarmPermission: () async => true,
        reconcile: () async => events.add('reconcile'),
      );

      await coordinator.onResume();

      expect(events, <String>['timezone', 'permissions', 'reconcile']);
    },
  );

  test('resume still reconciles after timezone refresh fails', () async {
    final events = <String>[];
    final coordinator = ReminderSystemTriggerCoordinator(
      refreshTimezoneIfChanged: () async {
        events.add('timezone');
        throw StateError('timezone failed');
      },
      refreshPermissionStateIfChanged: () async {
        events.add('permissions');
        return false;
      },
      requestNotificationPermission: () async => true,
      requestExactAlarmPermission: () async => true,
      reconcile: () async => events.add('reconcile'),
    );

    await coordinator.onResume();

    expect(events, <String>['timezone', 'permissions', 'reconcile']);
  });

  test('resume still reconciles after permission refresh fails', () async {
    final events = <String>[];
    final coordinator = ReminderSystemTriggerCoordinator(
      refreshTimezoneIfChanged: () async {
        events.add('timezone');
        return false;
      },
      refreshPermissionStateIfChanged: () async {
        events.add('permissions');
        throw StateError('permissions failed');
      },
      requestNotificationPermission: () async => true,
      requestExactAlarmPermission: () async => true,
      reconcile: () async => events.add('reconcile'),
    );

    await coordinator.onResume();

    expect(events, <String>['timezone', 'permissions', 'reconcile']);
  });

  test('notification permission result is preserved and reconciled', () async {
    var permissionRefreshes = 0;
    var reconciliations = 0;
    final coordinator = ReminderSystemTriggerCoordinator(
      refreshTimezoneIfChanged: () async => false,
      refreshPermissionStateIfChanged: () async {
        permissionRefreshes++;
        return true;
      },
      requestNotificationPermission: () async => false,
      requestExactAlarmPermission: () async => true,
      reconcile: () async => reconciliations++,
    );

    final granted = await coordinator.requestNotifications();

    expect(granted, isFalse);
    expect(permissionRefreshes, 1);
    expect(reconciliations, 1);
  });

  test('exact-alarm permission result is preserved and reconciled', () async {
    var permissionRefreshes = 0;
    var reconciliations = 0;
    final coordinator = ReminderSystemTriggerCoordinator(
      refreshTimezoneIfChanged: () async => false,
      refreshPermissionStateIfChanged: () async {
        permissionRefreshes++;
        return true;
      },
      requestNotificationPermission: () async => true,
      requestExactAlarmPermission: () async => false,
      reconcile: () async => reconciliations++,
    );

    final granted = await coordinator.requestExactAlarm();

    expect(granted, isFalse);
    expect(permissionRefreshes, 1);
    expect(reconciliations, 1);
  });

  test('failed native permission request does not reconcile', () async {
    var permissionRefreshes = 0;
    var reconciliations = 0;
    final coordinator = ReminderSystemTriggerCoordinator(
      refreshTimezoneIfChanged: () async => false,
      refreshPermissionStateIfChanged: () async {
        permissionRefreshes++;
        return true;
      },
      requestNotificationPermission: () async => throw StateError('failed'),
      requestExactAlarmPermission: () async => true,
      reconcile: () async => reconciliations++,
    );

    await expectLater(coordinator.requestNotifications(), throwsStateError);
    expect(permissionRefreshes, 0);
    expect(reconciliations, 0);
  });
}
