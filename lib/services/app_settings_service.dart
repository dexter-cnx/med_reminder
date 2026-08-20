import 'package:flutter/services.dart';

class AppSettingsService {
  const AppSettingsService._();

  static const MethodChannel _channel = MethodChannel(
    'med_reminder/app_settings',
  );

  static Future<bool> open() async {
    try {
      return await _channel.invokeMethod<bool>('open') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
