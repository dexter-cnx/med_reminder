import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_feature.dart';
import 'feature_registry_providers.dart';

final settingsCompositionProvider = Provider<SettingsComposition>((ref) {
  final sections = ref.watch(featureRegistryProvider).enabledSettingsSections;
  return SettingsComposition(
    showMedicationPermissions: sections.contains(
      AppSettingsSection.medicationPermissions,
    ),
    showEmergencyProfile: sections.contains(AppSettingsSection.emergencyProfile),
  );
});

final class SettingsComposition {
  const SettingsComposition({
    required this.showMedicationPermissions,
    required this.showEmergencyProfile,
  });

  final bool showMedicationPermissions;
  final bool showEmergencyProfile;
}
