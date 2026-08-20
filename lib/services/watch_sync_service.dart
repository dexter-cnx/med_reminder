import 'package:flutter/services.dart';

import '../models/medication.dart';

class WatchSyncService {
  static const MethodChannel _channel = MethodChannel(
    'med_reminder/watch_sync',
  );

  static Future<void> syncMeds(List<Medication> meds) async {
    await _channel.invokeMethod<void>(
      'syncMeds',
      meds
          .map(
            (med) => <String, dynamic>{
              'id': med.id,
              'name': med.name,
              'times': med.times,
              'dosagePerTime': med.dosagePerTime,
              'mode': med.mode.name,
              'initialAmount': med.initialAmount,
              'lowThreshold': med.lowThreshold,
            },
          )
          .toList(growable: false),
    );
  }
}
