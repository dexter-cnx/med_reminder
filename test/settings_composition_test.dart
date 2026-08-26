import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/app/feature_registry/app_feature.dart';
import 'package:med_reminder_offline/app/feature_registry/feature_registry_providers.dart';
import 'package:med_reminder_offline/app/feature_registry/settings_composition.dart';

void main() {
  test('shows shipped feature settings by default', () {
    final container = ProviderContainer(
      overrides: [
        featureEnablementStoreProvider.overrideWithValue(
          _MemoryFeatureEnablementStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final composition = container.read(settingsCompositionProvider);

    expect(composition.showMedicationPermissions, isTrue);
    expect(composition.showEmergencyProfile, isTrue);
  });

  test('reacts when feature settings contributions are disabled', () async {
    final container = ProviderContainer(
      overrides: [
        featureEnablementStoreProvider.overrideWithValue(
          _MemoryFeatureEnablementStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(featureRegistryProvider.notifier)
        .setEnabled('medication', false);
    var composition = container.read(settingsCompositionProvider);
    expect(composition.showMedicationPermissions, isFalse);
    expect(composition.showEmergencyProfile, isTrue);

    await container
        .read(featureRegistryProvider.notifier)
        .setEnabled('emergency', false);
    composition = container.read(settingsCompositionProvider);
    expect(composition.showMedicationPermissions, isFalse);
    expect(composition.showEmergencyProfile, isFalse);
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
