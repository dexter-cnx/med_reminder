abstract interface class EmergencyContactLauncher {
  Future<bool> call(String phoneNumber);

  Future<bool> sms(String phoneNumber);
}
