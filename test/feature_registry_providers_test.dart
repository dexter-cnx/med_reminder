import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/app/feature_registry/app_feature.dart';
import 'package:med_reminder_offline/app/feature_registry/feature_registry_providers.dart';

void main() {
  test(
    'builds the shipped registry from the injected enablement store',
    () async {
      final store = _MemoryFeatureEnablementStore();
      final container = ProviderContainer(
        overrides: [featureEnablementStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final registry = container.read(featureRegistryProvider);

      expect(
        registry.registeredFeatures.map((feature) => feature.manifest.id),
        <String>['medication', 'appointments', 'emergency'],
      );
      expect(registry.isEnabled('medication'), isTrue);
      expect(
        registry.enabledCapabilities,
        contains(AppCapability.notifications),
      );
    },
  );

  test('publishes enablement changes through Riverpod state', () async {
    final store = _MemoryFeatureEnablementStore();
    final container = ProviderContainer(
      overrides: [featureEnablementStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final emitted = <FeatureRegistry>[];
    final subscription = container.listen<FeatureRegistry>(
      featureRegistryProvider,
      (previous, next) => emitted.add(next),
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container
        .read(featureRegistryProvider.notifier)
        .setEnabled('medication', false);

    final registry = container.read(featureRegistryProvider);
    expect(registry.isEnabled('medication'), isFalse);
    expect(registry.enabledCapabilities, isNot(contains(AppCapability.camera)));
    expect(
      registry.enabledCapabilities,
      isNot(contains(AppCapability.notifications)),
    );
    expect(registry.enabledCapabilities, contains(AppCapability.calendar));
    expect(registry.enabledCapabilities, contains(AppCapability.phoneSms));
    expect(emitted, hasLength(2));
    expect(emitted.last, same(registry));
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
