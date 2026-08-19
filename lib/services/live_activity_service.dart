import 'package:flutter/services.dart';

class LiveActivityService {
  static const MethodChannel _channel = MethodChannel('med_reminder/live_activity');

  static Future<void> start(String name, int dosage, String nextTime) async {
    await _channel.invokeMethod<void>('start', <String, dynamic>{
      'name': name,
      'dosage': dosage,
      'nextTime': nextTime,
    });
  }

  static Future<void> update(String name, int remaining) async {
    await _channel.invokeMethod<void>('update', <String, dynamic>{
      'name': name,
      'remaining': remaining,
    });
  }

  static Future<void> end() => _channel.invokeMethod<void>('end');
}
