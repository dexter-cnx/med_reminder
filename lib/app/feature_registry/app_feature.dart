enum AppCapability {
  camera,
  notifications,
  calendar,
  contacts,
  phoneSms,
  location,
  localAi,
  healthData,
}

enum AppNavigationSlot { today, medications, appointments }

enum AppShellAction { emergencySos, emergencyMedicalCard }

enum AppSettingsSection { medicationPermissions, emergencyProfile }

final class FeatureManifest {
  FeatureManifest({
    required this.id,
    required this.version,
    required this.displayNameKey,
    this.enabledByDefault = true,
    Iterable<AppCapability> capabilities = const <AppCapability>{},
    Iterable<AppNavigationSlot> navigationSlots = const <AppNavigationSlot>{},
    Iterable<AppShellAction> shellActions = const <AppShellAction>{},
    Iterable<AppSettingsSection> settingsSections =
        const <AppSettingsSection>{},
  }) : capabilities = Set<AppCapability>.unmodifiable(capabilities),
       navigationSlots = Set<AppNavigationSlot>.unmodifiable(navigationSlots),
       shellActions = Set<AppShellAction>.unmodifiable(shellActions),
       settingsSections = Set<AppSettingsSection>.unmodifiable(
         settingsSections,
       );

  final String id;
  final String version;
  final String displayNameKey;
  final bool enabledByDefault;
  final Set<AppCapability> capabilities;
  final Set<AppNavigationSlot> navigationSlots;
  final Set<AppShellAction> shellActions;
  final Set<AppSettingsSection> settingsSections;
}

abstract interface class AppFeature {
  FeatureManifest get manifest;
}

abstract interface class FeatureEnablementStore {
  bool isEnabled(String featureId, {required bool defaultValue});

  Future<void> setEnabled(String featureId, bool enabled);
}
