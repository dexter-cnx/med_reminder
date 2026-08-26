enum AppCapability {
  camera,
  notifications,
  calendar,
  contacts,
  location,
  localAi,
  healthData,
}

final class FeatureManifest {
  const FeatureManifest({
    required this.id,
    required this.version,
    required this.displayNameKey,
    this.enabledByDefault = true,
    this.capabilities = const <AppCapability>{},
  });

  final String id;
  final String version;
  final String displayNameKey;
  final bool enabledByDefault;
  final Set<AppCapability> capabilities;
}

abstract interface class AppFeature {
  FeatureManifest get manifest;
}

abstract interface class FeatureEnablementStore {
  bool isEnabled(String featureId, {required bool defaultValue});

  Future<void> setEnabled(String featureId, bool enabled);
}
