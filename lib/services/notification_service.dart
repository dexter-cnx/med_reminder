import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Future<void>? _initializing;
  static bool _timezoneReady = false;
  static String? _timezoneName;
  static AndroidScheduleMode _androidScheduleMode =
      AndroidScheduleMode.inexactAllowWhileIdle;

  static const Duration _nativeTimeout = Duration(seconds: 5);

  static const NotificationDetails _doseDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'med_reminder',
      'Medication reminders',
      channelDescription: 'Scheduled medication dose reminders',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() {
    if (_initialized) return Future<void>.value();
    final inFlight = _initializing;
    if (inFlight != null) return inFlight;

    final future = _initialize();
    _initializing = future;
    return future.whenComplete(() {
      if (!_initialized) {
        _initializing = null;
      }
    });
  }

  static Future<void> _initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin
        .initialize(
          const InitializationSettings(android: android, iOS: ios),
        )
        .timeout(_nativeTimeout);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin
          .requestNotificationsPermission()
          .timeout(_nativeTimeout);
    }

    // Exact-alarm permission must be user-driven on modern Android. Requesting
    // it during startup can open system settings while Flutter is still
    // attaching to the process. Keep the baseline on inexact scheduling until
    // a dedicated exact-alarm permission flow is triggered by the user.
    _androidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

    await _initTimezone().timeout(_nativeTimeout);
    _initialized = true;
  }

  static Future<String> _readTimezoneName() async {
    try {
      final timezone =
          await FlutterTimezone.getLocalTimezone().timeout(_nativeTimeout);
      return timezone.identifier;
    } catch (_) {
      return 'UTC';
    }
  }

  static Future<void> _initTimezone() async {
    if (_timezoneReady) return;
    tzdata.initializeTimeZones();
    _timezoneName = await _readTimezoneName();
    try {
      tz.setLocalLocation(tz.getLocation(_timezoneName!));
    } catch (_) {
      _timezoneName = 'UTC';
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _timezoneReady = true;
  }

  static Future<bool> refreshTimezoneIfChanged() async {
    await init();
    final next = await _readTimezoneName();
    if (next == _timezoneName) return false;
    try {
      tz.setLocalLocation(tz.getLocation(next));
      _timezoneName = next;
    } catch (_) {
      return false;
    }
    return true;
  }

  static Future<List<int>> scheduleForMed(Medication medication) async {
    await init();
    await cancelIds(medication.notificationIds);

    if (medication.mode == MedicationMode.untilEmpty &&
        medication.initialAmount == 0) {
      return const <int>[];
    }

    final ids = <int>[];
    for (var timeIndex = 0; timeIndex < medication.times.length; timeIndex++) {
      final parts = medication.times[timeIndex].split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null || hour > 23 || minute > 59) continue;

      if (medication.mode == MedicationMode.days) {
        final count = medication.daysCount ?? 0;
        final startDate = tz.TZDateTime(
          tz.local,
          medication.createdAt.year,
          medication.createdAt.month,
          medication.createdAt.day,
        );
        final now = tz.TZDateTime.now(tz.local);

        for (var dayOffset = 0; dayOffset < count; dayOffset++) {
          final date = startDate.add(Duration(days: dayOffset));
          final scheduled = tz.TZDateTime(
            tz.local,
            date.year,
            date.month,
            date.day,
            hour,
            minute,
          );
          if (!scheduled.isAfter(now)) continue;
          final id = _stableNotificationId(
            '${medication.id}:$timeIndex:$dayOffset',
          );
          ids.add(id);
          await _plugin.zonedSchedule(
            id,
            'Time to take medication 💊',
            '${medication.name} ${medication.dosagePerTime}',
            scheduled,
            _doseDetails,
            androidScheduleMode: _androidScheduleMode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      } else {
        final now = tz.TZDateTime.now(tz.local);
        var scheduled = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );
        if (!scheduled.isAfter(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        final id = _stableNotificationId('${medication.id}:$timeIndex:daily');
        ids.add(id);
        await _plugin.zonedSchedule(
          id,
          'Time to take medication 💊',
          '${medication.name} ${medication.dosagePerTime}',
          scheduled,
          _doseDetails,
          androidScheduleMode: _androidScheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
    return ids;
  }

  static Future<void> scheduleSnooze({
    required String medId,
    required String medName,
    required int dosage,
    required DateTime scheduledDose,
  }) async {
    await init();
    final id = snoozeId(medId, scheduledDose);
    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      'Medication reminder 💊',
      '$medName $dosage',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10)),
      _doseDetails,
      androidScheduleMode: _androidScheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static int snoozeId(String medId, DateTime scheduledDose) =>
      _stableNotificationId('$medId:${scheduledDose.toIso8601String()}:snooze');

  static Future<void> cancelSnooze(String medId, DateTime scheduledDose) async {
    await init();
    await _plugin.cancel(snoozeId(medId, scheduledDose));
  }

  static Future<void> cancelIds(Iterable<int> ids) async {
    await init();
    for (final id in ids.toSet()) {
      await _plugin.cancel(id);
    }
  }

  static Future<void> showLowStock(String name, int remaining) async {
    await init();
    await _plugin.show(
      _stableNotificationId('low-stock:$name'),
      'Low medication stock',
      '$name: $remaining remaining',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'low_stock',
          'Low medication stock',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static int _stableNotificationId(String input) {
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
