import 'app_feature.dart';

final class FeatureRegistry {
  FeatureRegistry({
    required Iterable<AppFeature> features,
    required FeatureEnablementStore enablementStore,
  }) : _features = List<AppFeature>.unmodifiable(features),
       _enablementStore = enablementStore {
    final ids = <String>{};
    for (final feature in _features) {
      final rawId = feature.manifest.id;
      final canonicalId = rawId.trim();
      if (canonicalId.isEmpty) {
        throw ArgumentError.value(
          rawId,
          'features',
          'Feature id must not be empty.',
        );
      }
      if (rawId != canonicalId) {
        throw ArgumentError.value(
          rawId,
          'features',
          'Feature id must already be canonical without surrounding whitespace.',
        );
      }
      if (!ids.add(canonicalId)) {
        throw ArgumentError.value(
          rawId,
          'features',
          'Feature ids must be unique.',
        );
      }
    }
  }

  final List<AppFeature> _features;
  final FeatureEnablementStore _enablementStore;

  List<AppFeature> get registeredFeatures => _features;

  AppFeature? featureById(String id) {
    for (final feature in _features) {
      if (feature.manifest.id == id) return feature;
    }
    return null;
  }

  bool isEnabled(String featureId) {
    final feature = featureById(featureId);
    if (feature == null) return false;
    return _enablementStore.isEnabled(
      featureId,
      defaultValue: feature.manifest.enabledByDefault,
    );
  }

  List<AppFeature> get enabledFeatures => List<AppFeature>.unmodifiable(
    _features.where((feature) => isEnabled(feature.manifest.id)),
  );

  Set<AppCapability> get enabledCapabilities => Set<AppCapability>.unmodifiable(
    enabledFeatures.expand((feature) => feature.manifest.capabilities),
  );

  Future<void> setEnabled(String featureId, bool enabled) async {
    if (featureById(featureId) == null) {
      throw ArgumentError.value(featureId, 'featureId', 'Unknown feature.');
    }
    await _enablementStore.setEnabled(featureId, enabled);
  }
}
