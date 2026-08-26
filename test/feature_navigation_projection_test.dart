import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/app/feature_registry/app_feature.dart';
import 'package:med_reminder_offline/app/feature_registry/feature_registry.dart';
import 'package:med_reminder_offline/app/feature_registry/shipped_features.dart';

void main() {
  test('projects navigation slots only from enabled features', () async {
    final store = _MemoryFeatureEnablementStore();
    final registry = FeatureRegistry(
      features: buildShippedFeatures(),
      enablementStore: store,
    );

    expect(registry.enabledNavigationSlots, <AppNavigationSlot>{
      AppNavigationSlot.today,
      AppNavigationSlot.medications,
      AppNavigationSlot.appointments,
    });

    await registry.setEnabled('medication', false);

    expect(registry.enabledNavigationSlots, <AppNavigationSlot>{
      AppNavigationSlot.appointments,
    });
  });
}

final class _MemoryFeatureEnablementStore implements FeatureEnablementStore {
  final Map<String, bool> _values = <String, bool>{};

  @override
  bool isEnabled(String featureId, {required bool defaultValue}) =>
      _values[featureId] ?? defaultValue;

  @override
  Future<void> setEnabled(String featureId, bool enabled) async {
    _values[featureId] = enabled;
  }
}
