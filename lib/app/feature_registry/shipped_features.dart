import '../../features/appointment/appointment_feature.dart';
import '../../features/emergency/emergency_feature.dart';
import '../../features/medication/medication_feature.dart';
import 'app_feature.dart';

List<AppFeature> buildShippedFeatures() => <AppFeature>[
  MedicationFeature(),
  AppointmentFeature(),
  EmergencyFeature(),
];
