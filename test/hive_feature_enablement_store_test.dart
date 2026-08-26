import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:med_reminder_offline/app/feature_registry/hive_feature_enablement_store.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'besyu-feature-enablement-',
    );
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('settings');
  });

  tearDown(() async {
    await box.close();
    await Hive.deleteFromDisk();
    await tempDirectory.delete(recursive: true);
  });

  test('uses manifest default when no persisted override exists', () {
    final store = HiveFeatureEnablementStore(box);

    expect(store.isEnabled('medication', defaultValue: true), isTrue);
    expect(store.isEnabled('appointments', defaultValue: false), isFalse);
  });

  test('persists explicit enablement using stable feature key', () async {
    final store = HiveFeatureEnablementStore(box);

    await store.setEnabled('appointments', true);

    expect(
      box.get(HiveFeatureEnablementStore.keyFor('appointments')),
      isTrue,
    );
    expect(store.isEnabled('appointments', defaultValue: false), isTrue);
  });

  test('ignores malformed persisted values and falls back safely', () async {
    await box.put(HiveFeatureEnablementStore.keyFor('medication'), 'yes');
    final store = HiveFeatureEnablementStore(box);

    expect(store.isEnabled('medication', defaultValue: true), isTrue);
    expect(store.isEnabled('medication', defaultValue: false), isFalse);
  });
}
