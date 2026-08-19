import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/medication_repository.dart';

final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => throw StateError(
    'MedicationRepository must be provided at the composition root.',
  ),
);

final doseLogRepositoryProvider = Provider<DoseLogRepository>(
  (ref) => throw StateError(
    'DoseLogRepository must be provided at the composition root.',
  ),
);
