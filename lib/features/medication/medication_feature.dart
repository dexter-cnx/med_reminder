import '../../app/feature_registry/app_feature.dart';

final class MedicationFeature implements AppFeature {
  MedicationFeature();

  @override
  final FeatureManifest manifest = FeatureManifest(
    id: 'medication',
    version: '1',
    displayNameKey: 'all_meds',
    capabilities: const <AppCapability>{
      AppCapability.notifications,
      AppCapability.camera,
    },
    navigationSlots: const <AppNavigationSlot>{
      AppNavigationSlot.today,
      AppNavigationSlot.medications,
    },
    settingsSections: const <AppSettingsSection>{
      AppSettingsSection.medicationPermissions,
    },
    onboardingSteps: const <AppOnboardingStep>{
      AppOnboardingStep.medicationPermissions,
    },
  );
}
