import 'package:url_launcher/url_launcher.dart';

import '../../application/emergency_contact_launcher.dart';

class UrlLauncherEmergencyContactLauncher implements EmergencyContactLauncher {
  const UrlLauncherEmergencyContactLauncher();

  @override
  Future<bool> call(String phoneNumber) => _launch('tel', phoneNumber);

  @override
  Future<bool> sms(String phoneNumber) => _launch('sms', phoneNumber);

  Future<bool> _launch(String scheme, String phoneNumber) {
    final normalized = phoneNumber.trim();
    if (normalized.isEmpty) return Future<bool>.value(false);
    return launchUrl(Uri(scheme: scheme, path: normalized));
  }
}
