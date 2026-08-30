import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/app/feature_registry/app_feature.dart';
import 'package:med_reminder_offline/app/feature_registry/feature_registry.dart';
import 'package:med_reminder_offline/app/feature_registry/shipped_features.dart';

void main() {
  test('projects onboarding steps from enabled features only', () async {
    final store = _MemoryEnablementStore();
    final registry = FeatureRegistry(
      features: buildShippedFeatures(),
      enablementStore: store,
    );

    expect(registry.enabledOnboardingSteps, <AppOnboardingStep>{
      AppOnboardingStep.medicationPermissions,
    });

    await registry.setEnabled('medication', false);

    expect(registry.enabledOnboardingSteps, isEmpty);
  });
}

final class _MemoryEnablementStore implements FeatureEnablementStore {
  final Map<String, bool> _values = <String, bool>{};

  @override
  bool isEnabled(String featureId, {required bool defaultValue}) =>
      _values[featureId] ?? defaultValue;

  @override
  Future<void> setEnabled(String featureId, bool enabled) async {
    _values[featureId] = enabled;
  }
}
