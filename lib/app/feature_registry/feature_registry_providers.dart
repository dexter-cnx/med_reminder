import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_feature.dart';
import 'feature_registry.dart';
import 'shipped_features.dart';

final featureEnablementStoreProvider = Provider<FeatureEnablementStore>(
  (ref) => throw UnimplementedError(
    'FeatureEnablementStore must be provided by app DI.',
  ),
);

final featureRegistryProvider =
    StateNotifierProvider<FeatureRegistryController, FeatureRegistry>(
      (ref) => FeatureRegistryController(
        features: buildShippedFeatures(),
        enablementStore: ref.watch(featureEnablementStoreProvider),
      ),
    );

final class FeatureRegistryController extends StateNotifier<FeatureRegistry> {
  FeatureRegistryController({
    required Iterable<AppFeature> features,
    required FeatureEnablementStore enablementStore,
  }) : _features = List<AppFeature>.unmodifiable(features),
       _enablementStore = enablementStore,
       super(
         FeatureRegistry(features: features, enablementStore: enablementStore),
       );

  final List<AppFeature> _features;
  final FeatureEnablementStore _enablementStore;

  Future<void> setEnabled(String featureId, bool enabled) async {
    await state.setEnabled(featureId, enabled);
    state = FeatureRegistry(
      features: _features,
      enablementStore: _enablementStore,
    );
  }
}
