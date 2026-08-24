import 'package:flutter/services.dart';

import '../../application/emergency_contact_launcher.dart';

class PlatformEmergencyContactLauncher implements EmergencyContactLauncher {
  const PlatformEmergencyContactLauncher();

  static const _channel = MethodChannel('med_reminder/emergency_contact');

  @override
  Future<bool> call(String phoneNumber) => _invoke('call', phoneNumber);

  @override
  Future<bool> sms(String phoneNumber) => _invoke('sms', phoneNumber);

  Future<bool> _invoke(String method, String phoneNumber) async {
    final normalized = phoneNumber.trim();
    if (normalized.isEmpty) return false;
    return await _channel.invokeMethod<bool>(method, normalized) ?? false;
  }
}
