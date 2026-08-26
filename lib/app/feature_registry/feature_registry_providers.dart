import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_feature.dart';
import 'feature_registry.dart';
import 'shipped_features.dart';

final featureEnablementStoreProvider = Provider<FeatureEnablementStore>(
  (ref) => throw UnimplementedError(
    'FeatureEnablementStore must be provided by app DI.',
  ),
);

final featureRegistryProvider = Provider<FeatureRegistry>(
  (ref) => FeatureRegistry(
    features: buildShippedFeatures(),
    enablementStore: ref.watch(featureEnablementStoreProvider),
  ),
);
