import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;

  setUpAll(() {
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test('declares boot completed permission', () {
    expect(
      manifest,
      contains('android.permission.RECEIVE_BOOT_COMPLETED'),
    );
  });

  test('registers scheduled notification receiver', () {
    expect(
      manifest,
      contains(
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
      ),
    );
  });

  test('registers boot recovery receiver', () {
    expect(
      manifest,
      contains(
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
      ),
    );
  });

  test('restores notifications after reboot and package replacement', () {
    expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    expect(manifest, contains('android.intent.action.MY_PACKAGE_REPLACED'));
  });

  test('supports vendor quick boot broadcasts already used by the plugin', () {
    expect(manifest, contains('android.intent.action.QUICKBOOT_POWERON'));
    expect(manifest, contains('com.htc.intent.action.QUICKBOOT_POWERON'));
  });
}
