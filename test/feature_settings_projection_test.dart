import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/app/feature_registry/app_feature.dart';
import 'package:med_reminder_offline/app/feature_registry/feature_registry.dart';

void main() {
  test('projects settings sections from enabled features only', () async {
    final store = _MemoryEnablementStore();
    final registry = FeatureRegistry(
      features: <AppFeature>[
        _Feature(
          FeatureManifest(
            id: 'medication',
            version: '1',
            displayNameKey: 'feature_medication',
            settingsSections: <AppSettingsSection>{
              AppSettingsSection.medicationPermissions,
            },
          ),
        ),
        _Feature(
          FeatureManifest(
            id: 'emergency',
            version: '1',
            displayNameKey: 'feature_emergency',
            settingsSections: <AppSettingsSection>{
              AppSettingsSection.emergencyProfile,
            },
          ),
        ),
      ],
      enablementStore: store,
    );

    expect(registry.enabledSettingsSections, <AppSettingsSection>{
      AppSettingsSection.medicationPermissions,
      AppSettingsSection.emergencyProfile,
    });

    await registry.setEnabled('emergency', false);

    expect(registry.enabledSettingsSections, <AppSettingsSection>{
      AppSettingsSection.medicationPermissions,
    });
  });
}

final class _Feature implements AppFeature {
  _Feature(this.manifest);

  @override
  final FeatureManifest manifest;
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
