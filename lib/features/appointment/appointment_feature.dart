import '../../app/feature_registry/app_feature.dart';

final class AppointmentFeature implements AppFeature {
  AppointmentFeature();

  @override
  final FeatureManifest manifest = FeatureManifest(
    id: 'appointments',
    version: '1',
    displayNameKey: 'appointments',
    capabilities: const <AppCapability>{AppCapability.calendar},
  );
}
