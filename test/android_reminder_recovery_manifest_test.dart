import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _androidNamespace = 'http://schemas.android.com/apk/res/android';
const _scheduledReceiver =
    'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver';
const _bootReceiver =
    'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver';

void main() {
  late XmlDocument manifest;

  setUpAll(() {
    manifest = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    );
  });

  String? androidAttribute(XmlElement element, String name) =>
      element.getAttribute(name, namespace: _androidNamespace);

  XmlElement receiverNamed(String name) => manifest
      .findAllElements('receiver')
      .singleWhere((receiver) => androidAttribute(receiver, 'name') == name);

  Set<String> receiverActions(XmlElement receiver) => receiver
      .findAllElements('action')
      .map((action) => androidAttribute(action, 'name'))
      .whereType<String>()
      .toSet();

  test('declares boot completed permission', () {
    final permissions = manifest
        .findAllElements('uses-permission')
        .map((permission) => androidAttribute(permission, 'name'))
        .whereType<String>()
        .toSet();

    expect(permissions, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
  });

  test('registers enabled scheduled notification receiver', () {
    final receiver = receiverNamed(_scheduledReceiver);

    expect(androidAttribute(receiver, 'enabled'), isNot('false'));
  });

  test('registers enabled boot recovery receiver', () {
    final receiver = receiverNamed(_bootReceiver);

    expect(androidAttribute(receiver, 'enabled'), isNot('false'));
  });

  test('boot receiver owns reboot and package replacement actions', () {
    final actions = receiverActions(receiverNamed(_bootReceiver));

    expect(actions, contains('android.intent.action.BOOT_COMPLETED'));
    expect(actions, contains('android.intent.action.MY_PACKAGE_REPLACED'));
  });

  test('boot receiver owns supported vendor quick boot actions', () {
    final actions = receiverActions(receiverNamed(_bootReceiver));

    expect(actions, contains('android.intent.action.QUICKBOOT_POWERON'));
    expect(actions, contains('com.htc.intent.action.QUICKBOOT_POWERON'));
  });
}
