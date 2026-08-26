import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/app/feature_registry/app_feature.dart';
import 'package:med_reminder_offline/app/feature_registry/shipped_features.dart';

void main() {
  test('registers shipped feature manifests with stable ids and defaults', () {
    final features = buildShippedFeatures();
    final byId = <String, AppFeature>{
      for (final feature in features) feature.manifest.id: feature,
    };

    expect(byId.keys, <String>{'medication', 'appointments', 'emergency'});
    expect(
      byId.values.every((feature) => feature.manifest.enabledByDefault),
      isTrue,
    );
    expect(byId['medication']!.manifest.displayNameKey, 'all_meds');
    expect(byId['appointments']!.manifest.displayNameKey, 'appointments');
    expect(
      byId['emergency']!.manifest.displayNameKey,
      'emergency_profile_title',
    );
  });

  test(
    'declares only capabilities currently owned by each shipped feature',
    () {
      final byId = <String, AppFeature>{
        for (final feature in buildShippedFeatures())
          feature.manifest.id: feature,
      };

      expect(byId['medication']!.manifest.capabilities, <AppCapability>{
        AppCapability.notifications,
        AppCapability.camera,
      });
      expect(byId['appointments']!.manifest.capabilities, <AppCapability>{
        AppCapability.calendar,
      });
      expect(byId['emergency']!.manifest.capabilities, <AppCapability>{
        AppCapability.phoneSms,
      });
    },
  );
}
