import 'package:flutter/services.dart';

import '../models/medication.dart';

class WatchSyncService {
  static const MethodChannel _channel = MethodChannel('med_reminder/watch_sync');

  static Future<void> syncMeds(List<Medication> meds) async {
    await _channel.invokeMethod<void>(
      'syncMeds',
      meds.map((med) => med.toMap()).toList(),
    );
  }
}
