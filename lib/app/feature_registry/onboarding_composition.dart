import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_feature.dart';
import 'feature_registry_providers.dart';

final onboardingCompositionProvider = Provider<OnboardingComposition>((ref) {
  final steps = ref.watch(featureRegistryProvider).enabledOnboardingSteps;
  return OnboardingComposition(
    showMedicationPermissions: steps.contains(
      AppOnboardingStep.medicationPermissions,
    ),
  );
});

final class OnboardingComposition {
  const OnboardingComposition({required this.showMedicationPermissions});

  final bool showMedicationPermissions;
}
