import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('physical reliability probe remains read-only and metadata-only', () {
    final source = File(
      'lib/reminder_reliability_probe_main.dart',
    ).readAsStringSync();

    expect(source, contains('pendingNotificationRequests()'));
    expect(source, contains('areNotificationsEnabled()'));
    expect(source, contains('canScheduleExactNotifications()'));
    expect(source, contains('FlutterTimezone.getLocalTimezone()'));

    expect(source, isNot(contains('requestPermissions(')));
    expect(source, isNot(contains('requestNotificationsPermission(')));
    expect(source, isNot(contains('requestExactAlarmsPermission(')));
    expect(source, isNot(contains('reconcile')));

    expect(source, isNot(contains('request.title')));
    expect(source, isNot(contains('request.body')));
    expect(source, isNot(contains('request.payload')));
  });

  test('Android pending evidence is not presented as AlarmManager truth', () {
    final source = File(
      'lib/reminder_reliability_probe_main.dart',
    ).readAsStringSync();

    expect(source, contains('pluginPersistedScheduledNotificationRegistry'));
    expect(source, contains('does not prove AlarmManager restoration'));
    expect(source, contains("'pendingEvidenceKind': pendingEvidenceKind"));
  });
}
