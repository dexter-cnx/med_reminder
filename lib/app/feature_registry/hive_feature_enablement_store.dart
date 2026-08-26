import 'package:hive/hive.dart';

import 'app_feature.dart';

final class HiveFeatureEnablementStore implements FeatureEnablementStore {
  HiveFeatureEnablementStore(this._settingsBox);

  static const String keyPrefix = 'feature.';
  static const String keySuffix = '.enabled';

  final Box<dynamic> _settingsBox;

  @override
  bool isEnabled(String featureId, {required bool defaultValue}) {
    final value = _settingsBox.get(_keyFor(featureId));
    return value is bool ? value : defaultValue;
  }

  @override
  Future<void> setEnabled(String featureId, bool enabled) =>
      _settingsBox.put(_keyFor(featureId), enabled);

  static String keyFor(String featureId) => _keyFor(featureId);

  static String _keyFor(String featureId) => '$keyPrefix$featureId$keySuffix';
}
