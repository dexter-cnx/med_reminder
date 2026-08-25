final class ReminderSystemTriggerCoordinator {
  const ReminderSystemTriggerCoordinator({
    required this.refreshTimezoneIfChanged,
    this.refreshPermissionStateIfChanged,
    required this.requestNotificationPermission,
    required this.requestExactAlarmPermission,
    required this.reconcile,
  });

  final Future<bool> Function() refreshTimezoneIfChanged;
  final Future<bool> Function()? refreshPermissionStateIfChanged;
  final Future<bool> Function() requestNotificationPermission;
  final Future<bool> Function() requestExactAlarmPermission;
  final Future<void> Function() reconcile;

  Future<void> onResume() async {
    await _bestEffortRefresh(refreshTimezoneIfChanged);
    final permissionRefresh = refreshPermissionStateIfChanged;
    if (permissionRefresh != null) {
      await _bestEffortRefresh(permissionRefresh);
    }
    await reconcile();
  }

  Future<bool> requestNotifications() async {
    final granted = await requestNotificationPermission();
    await refreshPermissionStateIfChanged?.call();
    await reconcile();
    return granted;
  }

  Future<bool> requestExactAlarm() async {
    final granted = await requestExactAlarmPermission();
    await refreshPermissionStateIfChanged?.call();
    await reconcile();
    return granted;
  }
}

Future<void> _bestEffortRefresh(Future<bool> Function() refresh) async {
  try {
    await refresh();
  } on Object {
    // Foreground reconciliation remains the recovery path even when a platform
    // state probe fails. The next resume can retry the failed probe.
  }
}
