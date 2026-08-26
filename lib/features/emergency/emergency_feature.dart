import '../../app/feature_registry/app_feature.dart';

final class EmergencyFeature implements AppFeature {
  EmergencyFeature();

  @override
  final FeatureManifest manifest = FeatureManifest(
    id: 'emergency',
    version: '1',
    displayNameKey: 'emergency_profile_title',
    capabilities: const <AppCapability>{AppCapability.phoneSms},
    shellActions: const <AppShellAction>{
      AppShellAction.emergencySos,
      AppShellAction.emergencyMedicalCard,
    },
  );
}
