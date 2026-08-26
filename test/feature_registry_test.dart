import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/app/feature_registry/app_feature.dart';
import 'package:med_reminder_offline/app/feature_registry/feature_registry.dart';

void main() {
  test('separates registered features from enabled features', () async {
    final store = _MemoryEnablementStore();
    final registry = FeatureRegistry(
      features: <AppFeature>[
        _Feature(
          FeatureManifest(
            id: 'medication',
            version: '1',
            displayNameKey: 'feature_medication',
            capabilities: <AppCapability>{AppCapability.notifications},
          ),
        ),
        _Feature(
          FeatureManifest(
            id: 'appointments',
            version: '1',
            displayNameKey: 'feature_appointments',
            enabledByDefault: false,
            capabilities: <AppCapability>{AppCapability.calendar},
          ),
        ),
      ],
      enablementStore: store,
    );

    expect(registry.registeredFeatures.length, 2);
    expect(
      registry.enabledFeatures.map((feature) => feature.manifest.id),
      <String>['medication'],
    );
    expect(registry.enabledCapabilities, <AppCapability>{
      AppCapability.notifications,
    });

    await registry.setEnabled('appointments', true);

    expect(
      registry.enabledFeatures.map((feature) => feature.manifest.id),
      <String>['medication', 'appointments'],
    );
    expect(registry.enabledCapabilities, <AppCapability>{
      AppCapability.notifications,
      AppCapability.calendar,
    });
  });

  test('projects shell actions from enabled features only', () async {
    final store = _MemoryEnablementStore();
    final registry = FeatureRegistry(
      features: <AppFeature>[
        _Feature(
          FeatureManifest(
            id: 'emergency',
            version: '1',
            displayNameKey: 'feature_emergency',
            shellActions: <AppShellAction>{
              AppShellAction.emergencySos,
              AppShellAction.emergencyMedicalCard,
            },
          ),
        ),
      ],
      enablementStore: store,
    );

    expect(registry.enabledShellActions, <AppShellAction>{
      AppShellAction.emergencySos,
      AppShellAction.emergencyMedicalCard,
    });

    await registry.setEnabled('emergency', false);

    expect(registry.enabledShellActions, isEmpty);
  });

  test('persisted enablement overrides manifest defaults', () async {
    final store = _MemoryEnablementStore();
    final registry = FeatureRegistry(
      features: <AppFeature>[
        _Feature(
          FeatureManifest(
            id: 'medication',
            version: '1',
            displayNameKey: 'feature_medication',
          ),
        ),
      ],
      enablementStore: store,
    );

    expect(registry.isEnabled('medication'), isTrue);

    await registry.setEnabled('medication', false);

    expect(registry.isEnabled('medication'), isFalse);
  });

  test('rejects duplicate stable feature ids', () {
    expect(
      () => FeatureRegistry(
        features: <AppFeature>[
          _Feature(
            FeatureManifest(
              id: 'medication',
              version: '1',
              displayNameKey: 'feature_medication',
            ),
          ),
          _Feature(
            FeatureManifest(
              id: 'medication',
              version: '2',
              displayNameKey: 'feature_medication_v2',
            ),
          ),
        ],
        enablementStore: _MemoryEnablementStore(),
      ),
      throwsArgumentError,
    );
  });

  test('rejects non-canonical feature ids', () {
    expect(
      () => FeatureRegistry(
        features: <AppFeature>[
          _Feature(
            FeatureManifest(
              id: 'medication ',
              version: '1',
              displayNameKey: 'feature_medication',
            ),
          ),
        ],
        enablementStore: _MemoryEnablementStore(),
      ),
      throwsArgumentError,
    );
  });

  test('manifest freezes caller-owned capability sets', () {
    final capabilities = <AppCapability>{AppCapability.notifications};
    final manifest = FeatureManifest(
      id: 'medication',
      version: '1',
      displayNameKey: 'feature_medication',
      capabilities: capabilities,
    );

    capabilities.add(AppCapability.camera);

    expect(manifest.capabilities, <AppCapability>{AppCapability.notifications});
    expect(
      () => manifest.capabilities.add(AppCapability.calendar),
      throwsUnsupportedError,
    );
  });

  test('unknown features are disabled and cannot be mutated', () async {
    final registry = FeatureRegistry(
      features: const <AppFeature>[],
      enablementStore: _MemoryEnablementStore(),
    );

    expect(registry.isEnabled('missing'), isFalse);
    await expectLater(
      registry.setEnabled('missing', true),
      throwsArgumentError,
    );
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
