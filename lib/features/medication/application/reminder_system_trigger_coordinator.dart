final class ReminderSystemTriggerCoordinator {
  const ReminderSystemTriggerCoordinator({
    required this.refreshTimezoneIfChanged,
    required this.requestNotificationPermission,
    required this.requestExactAlarmPermission,
    required this.reconcile,
  });

  final Future<bool> Function() refreshTimezoneIfChanged;
  final Future<bool> Function() requestNotificationPermission;
  final Future<bool> Function() requestExactAlarmPermission;
  final Future<void> Function() reconcile;

  Future<void> onResume() async {
    await refreshTimezoneIfChanged();
    await reconcile();
  }

  Future<bool> requestNotifications() async {
    final granted = await requestNotificationPermission();
    await reconcile();
    return granted;
  }

  Future<bool> requestExactAlarm() async {
    final granted = await requestExactAlarmPermission();
    await reconcile();
    return granted;
  }
}
