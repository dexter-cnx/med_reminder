final class ReminderSystemTriggerCoordinator {
  const ReminderSystemTriggerCoordinator({
    required this.refreshTimezoneIfChanged,
    required this.refreshPermissionStateIfChanged,
    required this.requestNotificationPermission,
    required this.requestExactAlarmPermission,
    required this.reconcile,
  });

  final Future<bool> Function() refreshTimezoneIfChanged;
  final Future<bool> Function() refreshPermissionStateIfChanged;
  final Future<bool> Function() requestNotificationPermission;
  final Future<bool> Function() requestExactAlarmPermission;
  final Future<void> Function() reconcile;

  Future<void> onResume() async {
    await refreshTimezoneIfChanged();
    await refreshPermissionStateIfChanged();
    await reconcile();
  }

  Future<bool> requestNotifications() async {
    final granted = await requestNotificationPermission();
    await refreshPermissionStateIfChanged();
    await reconcile();
    return granted;
  }

  Future<bool> requestExactAlarm() async {
    final granted = await requestExactAlarmPermission();
    await refreshPermissionStateIfChanged();
    await reconcile();
    return granted;
  }
}
