import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final snapshot = await _captureReminderReliabilitySnapshot();
  final encoded = const JsonEncoder.withIndent('  ').convert(snapshot);
  debugPrint('BESYU_REMINDER_RELIABILITY_SNAPSHOT\n$encoded');

  runApp(_ReminderReliabilityProbeApp(snapshot: encoded));
}

Future<Map<String, Object?>> _captureReminderReliabilitySnapshot() async {
  await NotificationService.init();

  final plugin = FlutterLocalNotificationsPlugin();
  final pending = await plugin.pendingNotificationRequests();
  final pendingIds = pending.map((request) => request.id).toList()..sort();

  final timezone = await FlutterTimezone.getLocalTimezone();
  bool? notificationsEnabled;
  bool? exactAlarmsEnabled;

  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android != null) {
    notificationsEnabled = await android.areNotificationsEnabled();
    exactAlarmsEnabled = await android.canScheduleExactNotifications();
  }

  return <String, Object?>{
    'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'platform': Platform.operatingSystem,
    'timezone': timezone.identifier,
    'pendingNotificationCount': pending.length,
    'pendingNotificationIds': pendingIds,
    'notificationsEnabled': notificationsEnabled,
    'exactAlarmsEnabled': exactAlarmsEnabled,
  };
}

class _ReminderReliabilityProbeApp extends StatelessWidget {
  const _ReminderReliabilityProbeApp({required this.snapshot});

  final String snapshot;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Besyu reminder reliability probe')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Read-only diagnostic snapshot. It does not rebuild reminders '
                  'or request permissions.',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(child: SelectableText(snapshot)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
